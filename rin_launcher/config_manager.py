"""Configuration store for Rin Launcher.

Owns ``config.yaml`` and exposes it to QML through camelCase ``@Slot`` methods
(QML resolves the Python attribute name, so the QML-facing API *is* camelCase —
there is no separate snake_case layer).

改动只发对应的信号（``launcherChanged`` / ``recordsChanged`` /
``settingsChanged``），不再一律发 ``configChanged``：小窗、档案页、设置页各自
只关心一块数据，少一次全量刷新就少一次重复解析与重排。
"""

from __future__ import annotations

import logging
import shutil
import sys
import time
import uuid
from collections.abc import Callable
from pathlib import Path
from typing import Any

import yaml
from PySide6.QtCore import QFileInfo, QObject, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices
# QFileIconProvider 在 Qt6 里搬到了 QtWidgets（QtGui 那个基类要自己实现 icon()）。
from PySide6.QtWidgets import QFileDialog, QFileIconProvider
from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

from rin_launcher.elevation import restart_elevated, set_run_on_startup

logger = logging.getLogger(__name__)

APP_VERSION = "1.1.0"
APP_REPO = "https://github.com/yixuan0826/RinLauncher"

DEFAULT_CONFIG_DIR = Path.home() / "AppData" / "Roaming" / "RinLauncher"
FALLBACK_CATEGORY = "默认"
ASSETS_DIR = Path(__file__).resolve().parent.parent / "assets"
BUNDLED_ICON_DIR = ASSETS_DIR / "icons" / "lawnicons"
APP_ICON_FILE = ASSETS_DIR / "icon.png"

# ── 常驻小窗的三行 ──────────────────────────────────────────────────
# 槽位不再是固定几格：每一行都是一个可增删排序的列表，内容写进 launcher.slots。
ROW_APPS = 0        # 常用应用（大格子）
ROW_TOOLS = 1       # 快捷功能（小格子）
ROW_DISKS = 2       # 存储与磁盘
LAUNCHER_ROWS = 3

SLOT_ACTION = "action"   # 引用「档案」里的条目
SLOT_TOOL = "tool"       # 内置功能
SLOT_PATH = "path"       # 打开任意文件 / 文件夹 / 磁盘
SLOT_USB = "usb"         # 自动检测的可移动磁盘

SLOT_KINDS: tuple = (SLOT_ACTION, SLOT_TOOL, SLOT_PATH, SLOT_USB)

# 内置功能。(key, 标题, Fluent 图标名)
TOOL_CATALOG: tuple = (
    ("launcherPage", "启动台设置", "ic_fluent_apps_20_regular"),
    ("records", "档案管理", "ic_fluent_book_20_regular"),
    ("settings", "设置", "ic_fluent_settings_20_regular"),
    ("configFolder", "配置目录", "ic_fluent_folder_open_20_regular"),
    ("configFile", "配置文件", "ic_fluent_document_text_20_regular"),
    ("reload", "重载配置", "ic_fluent_arrow_sync_20_regular"),
    ("elevate", "提权重启", "ic_fluent_shield_20_regular"),
    ("hide", "隐藏小窗", "ic_fluent_eye_off_20_regular"),
    ("quit", "退出程序", "ic_fluent_power_20_regular"),
)
# 默认第二行：挑 6 个日常用得上的。
DEFAULT_TOOL_KEYS: tuple = ("launcherPage", "records", "settings",
                            "configFolder", "reload", "hide")
TOOL_ICONS: dict[str, str] = {key: icon for key, _title, icon in TOOL_CATALOG}
TOOL_TITLES: dict[str, str] = {key: title for key, title, _icon in TOOL_CATALOG}

# 槽位 kind 的展示信息，给编辑器的下拉用。
SLOT_KIND_LABELS: dict[str, str] = {
    SLOT_ACTION: "档案条目",
    SLOT_TOOL: "内置功能",
    SLOT_PATH: "文件 / 文件夹 / 磁盘",
    SLOT_USB: "可移动磁盘（自动检测）",
}
SLOT_KIND_ICONS: dict[str, str] = {
    SLOT_ACTION: "ic_fluent_apps_20_regular",
    SLOT_TOOL: "ic_fluent_wrench_20_regular",
    SLOT_PATH: "ic_fluent_folder_open_20_regular",
    SLOT_USB: "ic_fluent_hard_drive_20_regular",
}

# 用户自建图标的落盘目录（导入的 svg/png/ico、从程序里抽出来的图标都放这儿）。
ICON_STORE_NAME = "icons"
# 磁盘容量这种系统调用有成本，缓存一小段时间，同一轮刷新里不重复问系统。
STORAGE_TTL = 20.0


def _human_size(size: int) -> str:
    """把字节数写成 32.78GB 这种一眼能读的形式。"""
    value = float(size)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if value < 1024 or unit == "TB":
            return f"{value:.0f}{unit}" if unit == "B" else f"{value:.2f}{unit}"
        value /= 1024
    return f"{value:.2f}TB"


def _drive_kind(code: int) -> str:
    return {2: "removable", 3: "fixed", 4: "network", 5: "cdrom", 6: "ramdisk"}.get(code, "")


def _find_removable_drive() -> str:
    """返回第一个可移动磁盘的根路径（如 ``E:\\``）；找不到或非 Windows 返回空串。"""
    if sys.platform != "win32":
        return ""
    try:
        import ctypes

        kernel32 = ctypes.windll.kernel32
        mask = kernel32.GetLogicalDrives()
    except Exception:
        logger.exception("Failed to enumerate drives")
        return ""

    for index in range(26):
        if not mask & (1 << index):
            continue
        root = f"{chr(ord('A') + index)}:\\"
        if kernel32.GetDriveTypeW(ctypes.c_wchar_p(root)) == 2:  # DRIVE_REMOVABLE
            return root
    return ""


def _list_drives() -> list[dict[str, Any]]:
    """枚举本机磁盘，给「磁盘」槽位的选择器用。

    非 Windows 上只给一个根分区 —— 开发环境（Linux/macOS）里界面照样能跑通，
    不至于整块功能消失。
    """
    if sys.platform != "win32":
        try:
            usage = shutil.disk_usage("/")
        except OSError:
            return []
        return [{
            "path": "/",
            "label": "根目录",
            "kind": "fixed",
            "kindLabel": "本地磁盘",
            "free": _human_size(usage.free),
            "total": _human_size(usage.total),
            "percent": round(usage.used / usage.total * 100) if usage.total else 0,
        }]

    try:
        import ctypes

        kernel32 = ctypes.windll.kernel32
        mask = kernel32.GetLogicalDrives()
    except Exception:
        logger.exception("Failed to enumerate drives")
        return []

    kind_labels = {
        "removable": "可移动磁盘", "fixed": "本地磁盘", "network": "网络位置",
        "cdrom": "光驱", "ramdisk": "内存盘",
    }
    drives: list[dict[str, Any]] = []
    for index in range(26):
        if not mask & (1 << index):
            continue
        root = f"{chr(ord('A') + index)}:\\"
        kind = _drive_kind(kernel32.GetDriveTypeW(ctypes.c_wchar_p(root)))
        if not kind:
            continue

        label = ""
        try:
            buffer = ctypes.create_unicode_buffer(261)
            if kernel32.GetVolumeInformationW(
                    ctypes.c_wchar_p(root), buffer, 261, None, None, None, None, 0):
                label = buffer.value
        except Exception:
            logger.debug("Cannot read volume label of %s", root)

        free_text = total_text = ""
        percent = 0
        # 光驱／网络盘没插介质时读容量会卡住，直接跳过。
        if kind in ("fixed", "removable", "ramdisk"):
            try:
                free = ctypes.c_ulonglong(0)
                total = ctypes.c_ulonglong(0)
                if kernel32.GetDiskFreeSpaceExW(
                        ctypes.c_wchar_p(root), ctypes.byref(free),
                        ctypes.byref(total), None) and total.value:
                    free_text = _human_size(free.value)
                    total_text = _human_size(total.value)
                    percent = round((total.value - free.value) / total.value * 100)
            except Exception:
                logger.debug("Cannot read free space of %s", root)

        drives.append({
            "path": root,
            "label": label or root,
            "kind": kind,
            "kindLabel": kind_labels.get(kind, kind),
            "free": free_text,
            "total": total_text,
            "percent": percent,
        })
    return drives


DEFAULT_SETTINGS: dict[str, Any] = {
    "theme": "system",
    "language": "zh_CN",
    "showTray": True,
    "startMinimized": False,
    "autoStart": False,
    "alwaysOnTop": True,
    "globalHotkey": "Ctrl+Space",
    # 常驻小窗的位置，写成 "x,y"；空串表示还没拖过，按右下角摆放。
    "compactPos": "",
    # 完整窗口材质。RinUI 的取值：tabbed(增强云母) | mica(云母) | acrylic(亚克力) | none
    "material": "tabbed",
    # 小窗是桌面挂件，单独走亚克力（不吃完整窗口那套材质设置）。
    "compactAcrylic": True,
    "searchEngine": "https://www.bing.com/search?q={query}",
    "gridColumns": 8,
    "itemSize": 96,
    "animationEnabled": True,
    "accentColor": "#0078d4",
    "fontFamily": "Microsoft YaHei UI",
    "fontSize": 12,
    "adminAutoElevate": True,
    "confirmAdminActions": True,
    "logLevel": "INFO",
}

# (name, type, target, category, icon).  ``order`` is derived per category.
# Icons are either a RinUI Fluent name or "lawnicons:<bundled svg stem>".
DEFAULT_ACTIONS: tuple = (
    ("记事本", "file", "notepad.exe", "常用",
     "lawnicons:generic_notes"),
    ("计算器", "file", "calc.exe", "常用",
     "lawnicons:generic_calculator_plus_minus_multi_equal"),
    ("画图", "file", "mspaint.exe", "常用",
     "lawnicons:generic_background_eraser"),
    ("文件资源管理器", "file", "explorer.exe", "系统工具",
     "lawnicons:generic_files"),
    ("任务管理器", "file", "taskmgr.exe", "系统工具",
     "lawnicons:generic_grid_3x3"),
    ("控制面板", "file", "control.exe", "系统工具",
     "lawnicons:generic_settings"),
    ("命令提示符", "cmd", "cmd.exe", "开发工具",
     "lawnicons:generic_shell"),
    ("PowerShell", "cmd", "powershell.exe", "开发工具",
     "lawnicons:generic_braces"),
    ("打开配置目录", "file", "{configdir}", "开发工具",
     "ic_fluent_folder_open_20_regular"),
    ("RinUI 官网", "url", "https://ui.rinlit.cn", "媒体娱乐",
     "lawnicons:generic_browser"),
)

# (name, icon, order)
DEFAULT_CATEGORIES: tuple = (
    ("常用", "lawnicons:generic_heart", 0),
    ("系统工具", "lawnicons:generic_settings", 1),
    ("开发工具", "lawnicons:generic_braces", 2),
    ("媒体娱乐", "lawnicons:generic_player", 3),
    (FALLBACK_CATEGORY, "lawnicons:generic_files", 99),
)


def _new_id() -> str:
    return uuid.uuid4().hex[:8]


def _new_slot(kind: str, row: int, **extra: Any) -> dict[str, Any]:
    """建一个槽位字典；多出来的键补上默认值，保证结构一致。"""
    slot = {
        "kind": kind,
        "row": row,
        "label": "",     # 覆盖显示名，空 = 用目标自己的名字
        "icon": "",      # 覆盖图标，空 = 用目标自己的图标
    }
    slot.update(extra)
    return slot


def _default_slots(actions: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """默认槽位：前 4 个条目 + 6 个内置功能 + 一个 U 盘和一个本机磁盘。"""
    slots = [_new_slot(SLOT_ACTION, ROW_APPS, ref=action["id"]) for action in actions[:4]]
    slots += [_new_slot(SLOT_TOOL, ROW_TOOLS, key=key) for key in DEFAULT_TOOL_KEYS]
    slots.append(_new_slot(SLOT_USB, ROW_DISKS, label="U 盘"))

    # 挑一个非系统盘当默认的「磁盘」项；找不到就用主目录。
    target = ""
    for drive in _list_drives():
        if drive["path"].upper() not in ("C:\\", "/"):
            target = drive["path"]
            break
    slots.append(_new_slot(SLOT_PATH, ROW_DISKS, path=target or str(Path.home())))
    return slots


def _default_config() -> dict[str, Any]:
    """Build a fresh default config; ids are regenerated on every call."""
    actions: list[dict[str, Any]] = []
    order: dict[str, int] = {}
    for name, kind, target, category, icon in DEFAULT_ACTIONS:
        index = order.get(category, 0)
        order[category] = index + 1
        actions.append({
            "id": _new_id(), "name": name, "type": kind, "target": target,
            "category": category, "icon": icon, "enabled": True, "order": index,
        })

    categories = [
        {"id": _new_id(), "name": name, "icon": icon, "order": rank, "expanded": True}
        for name, icon, rank in DEFAULT_CATEGORIES
    ]
    return {
        "version": 2,
        "actions": actions,
        "categories": categories,
        "launcher": {
            "slots": _default_slots(actions),
            "storagePath": "",
        },
        "settings": dict(DEFAULT_SETTINGS),
    }


class _ConfigWatcher(FileSystemEventHandler):
    """Debounced listener for edits made to the config file by other programs."""

    def __init__(self, on_change: Callable[[], None]):
        self._on_change = on_change
        self._last_fired = 0.0

    def on_modified(self, event) -> None:
        if event.is_directory or not event.src_path.endswith((".yaml", ".yml")):
            return
        now = time.monotonic()
        if now - self._last_fired > 0.5:
            self._last_fired = now
            self._on_change()


class ConfigManager(QObject):
    """Loads/saves ``config.yaml`` and serves it to QML."""

    showToast = Signal(str, str)
    # 整份配置换了（外部修改 / 导入 / 重置）时发这一个。
    configChanged = Signal()
    # 分块信号：各页面只订阅自己关心的那一块，避免无谓重算。
    launcherChanged = Signal()
    recordsChanged = Signal()
    settingsChanged = Signal()
    # The window / tray / hotkey owner listens to these and applies the change.
    hotkeyChanged = Signal(str)
    alwaysOnTopChanged = Signal(bool)
    trayEnabledChanged = Signal(bool)
    materialChanged = Signal(str)
    # 页面 / 窗口级的请求：QML 侧的页面够不到窗口对象，统一从这里转给 main.py。
    pageRequested = Signal(str)
    previewCompactRequested = Signal()

    def __init__(self, config_dir: Path | None = None, parent: QObject | None = None):
        super().__init__(parent)
        self.config_dir = Path(config_dir) if config_dir else DEFAULT_CONFIG_DIR
        self.config_file = self.config_dir / "config.yaml"
        self.backup_dir = self.config_dir / "backups"
        self.icon_dir = self.config_dir / ICON_STORE_NAME
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        self.icon_dir.mkdir(parents=True, exist_ok=True)

        self.action_executor = None
        self._observer: Observer | None = None
        self._quiet_until = 0.0  # ignores the watcher echo of our own writes
        self._icon_provider = QFileIconProvider()
        # 磁盘容量缓存：(取值时间, 数据)。
        self._storage_cache: tuple[float, dict[str, Any]] | None = None
        self._config = self._load()

    @property
    def config(self) -> dict[str, Any]:
        return self._config

    # ------------------------------------------------------------------
    # Persistence
    # ------------------------------------------------------------------
    def _load(self) -> dict[str, Any]:
        if not self.config_file.exists():
            config = _default_config()
            self.save(config, changed="all")
            return config
        try:
            with open(self.config_file, encoding="utf-8") as handle:
                return self._normalize(yaml.safe_load(handle) or {})
        except Exception:
            logger.exception("Failed to read %s, falling back to defaults", self.config_file)
            return _default_config()

    def _normalize(self, data: dict[str, Any]) -> dict[str, Any]:
        data.setdefault("version", 2)
        data.setdefault("actions", [])
        data.setdefault("categories", [])
        # settings keys added by newer builds get their default value
        data["settings"] = {**DEFAULT_SETTINGS, **(data.get("settings") or {})}
        data["launcher"] = self._normalize_launcher(data)
        return data

    def _normalize_launcher(self, data: dict[str, Any]) -> dict[str, Any]:
        """把 launcher 段补成合法槽位列表，并兼容旧版（固定 apps/tools）格式。"""
        raw = data.get("launcher") or {}
        slots = self._migrate_slots(raw, data.get("actions", []))
        return {
            "slots": [slot for slot in slots if slot["kind"] in SLOT_KINDS],
            "storagePath": str(raw.get("storagePath") or ""),
        }

    def _migrate_slots(self, raw: dict[str, Any], actions: list[dict[str, Any]]) -> list[dict]:
        """产出槽位列表。

        ``launcher.slots`` 是新格式；只有 ``apps`` / ``tools`` 的老配置按老结构
        逐格翻译成槽位，空位直接丢掉（新模型里「空位」没有意义）。
        """
        if isinstance(raw.get("slots"), list) and raw["slots"]:
            slots: list[dict[str, Any]] = []
            for index, item in enumerate(raw["slots"]):
                slot = self._normalize_slot(item, index)
                if slot is not None:
                    slots.append(slot)
            return slots

        if not raw:
            return _default_slots(actions)

        # ── 旧格式迁移 ──
        migrated: list[dict[str, Any]] = []
        existing = {action["id"] for action in actions}
        for action_id in raw.get("apps") or []:
            if str(action_id) in existing:
                migrated.append(_new_slot(SLOT_ACTION, ROW_APPS, ref=str(action_id)))
        for key in raw.get("tools") or []:
            if key in TOOL_ICONS:
                migrated.append(_new_slot(SLOT_TOOL, ROW_TOOLS, key=str(key)))
        # 老配置里那个「U 盘」按钮变成独立的 usb 槽位。
        migrated.append(_new_slot(SLOT_USB, ROW_DISKS, label="U 盘"))
        if not migrated:
            return _default_slots(actions)
        return migrated

    def _normalize_slot(self, item: Any, index: int) -> dict[str, Any] | None:
        """把外部写坏的槽位修回可用状态；实在修不了就丢掉（返回 None）。"""
        if not isinstance(item, dict):
            return None
        kind = str(item.get("kind") or "").strip()
        if kind not in SLOT_KINDS:
            return None

        row = item.get("row", index)
        try:
            row = int(row)
        except (TypeError, ValueError):
            row = ROW_APPS
        row = min(max(row, 0), LAUNCHER_ROWS - 1)

        slot = _new_slot(kind, row)
        slot["label"] = str(item.get("label") or "")
        slot["icon"] = str(item.get("icon") or "")
        if kind == SLOT_ACTION:
            slot["ref"] = str(item.get("ref") or "")
        elif kind == SLOT_TOOL:
            key = str(item.get("key") or "")
            if key not in TOOL_ICONS:   # 老配置里可能留着已经下线的 key
                return None
            slot["key"] = key
        elif kind == SLOT_PATH:
            slot["path"] = str(item.get("path") or "")
        return slot

    def save(self, config: dict[str, Any] | None = None, *, changed: str = "all") -> bool:
        """落盘。

        ``changed`` 指哪一块变了：``launcher`` / ``records`` / ``settings`` /
        ``all``，据此只发对应的信号。
        """
        if config is not None:
            self._config = config
        self._storage_cache = None
        try:
            if self.config_file.exists():
                self._rotate_backups()
            self._quiet_until = time.monotonic() + 1.0
            with open(self.config_file, "w", encoding="utf-8") as handle:
                yaml.dump(self._config, handle, allow_unicode=True, sort_keys=False, indent=2)
        except Exception:
            logger.exception("Failed to write %s", self.config_file)
            return False

        if changed == "all":
            self.configChanged.emit()
            self.launcherChanged.emit()
            self.recordsChanged.emit()
            self.settingsChanged.emit()
        elif changed == "launcher":
            self.launcherChanged.emit()
        elif changed == "records":
            self.recordsChanged.emit()
        elif changed == "settings":
            self.settingsChanged.emit()
        return True

    def _rotate_backups(self, keep: int = 10) -> None:
        shutil.copy2(self.config_file, self.backup_dir / f"config.yaml.bak.{int(time.time())}")
        for stale in sorted(self.backup_dir.glob("config.yaml.bak.*"))[:-keep]:
            stale.unlink(missing_ok=True)

    def _write_to(self, path: Path) -> bool:
        try:
            with open(path, "w", encoding="utf-8") as handle:
                yaml.dump(self._config, handle, allow_unicode=True, sort_keys=False, indent=2)
            return True
        except OSError:
            logger.exception("Failed to export config to %s", path)
            return False

    def _read_from(self, path: Path) -> bool:
        try:
            with open(path, encoding="utf-8") as handle:
                data = yaml.safe_load(handle) or {}
        except (OSError, yaml.YAMLError):
            logger.exception("Failed to import config from %s", path)
            return False
        self._config = self._normalize(data)
        return self.save(changed="all")

    # ------------------------------------------------------------------
    # Read API (called from QML)
    # ------------------------------------------------------------------
    @Slot(result="QVariantList")
    def getActions(self) -> list[dict]:
        return self._config["actions"]

    @Slot(result="QVariantList")
    def getCategories(self) -> list[dict]:
        return self._config["categories"]

    @Slot(result="QStringList")
    def getCategoriesModel(self) -> list[str]:
        return [category["name"] for category in self._config["categories"]]

    @Slot(result="QVariantMap")
    def getSettings(self) -> dict[str, Any]:
        """A detached copy, so the settings dialog can edit it before saving."""
        return dict(self._config["settings"])

    @Slot(str, result=int)
    def getCategoryIndex(self, name: str) -> int:
        for index, category in enumerate(self._config["categories"]):
            if category["name"] == name:
                return index
        return 0

    # ── 启动台槽位 ────────────────────────────────────────────────────
    def _resolve_slot(self, slot: dict[str, Any]) -> dict[str, Any] | None:
        """把槽位解析成界面直接能画的一条数据；引用失效的返回 None。"""
        kind = slot["kind"]
        resolved = dict(slot)
        override_icon = slot.get("icon") or ""
        override_label = slot.get("label") or ""

        if kind == SLOT_ACTION:
            entry = next(
                (a for a in self._config["actions"] if a["id"] == slot.get("ref")), None)
            if entry is None or entry.get("enabled", True) is False:
                return None
            resolved.update(
                # 槽位自己的 label 优先，空着才用条目本名
                name=override_label or entry.get("name", ""),
                icon=override_icon or entry.get("icon", ""),
                ref=entry["id"],
                type=entry.get("type", ""),
                target=entry.get("target", ""),
                runAs=entry.get("run_as", "user"),
                admin=entry.get("run_as") == "admin",
            )
        elif kind == SLOT_TOOL:
            key = slot.get("key", "")
            resolved.update(
                name=override_label or TOOL_TITLES.get(key, key),
                icon=override_icon or TOOL_ICONS.get(key, ""),
            )
        elif kind == SLOT_PATH:
            raw = str(slot.get("path") or "")
            expanded = str(Path(raw).expanduser()) if raw else ""
            exists = bool(expanded) and Path(expanded).exists()
            resolved.update(
                name=override_label or (Path(expanded).name if expanded else "未设置路径"),
                icon=override_icon or "ic_fluent_folder_open_20_regular",
                path=expanded,
                exists=exists,
            )
        elif kind == SLOT_USB:
            drive = _find_removable_drive()
            resolved.update(
                name=override_label or "U 盘",
                icon=override_icon or "ic_fluent_usb_plug_20_regular",
                path=drive,
                exists=bool(drive),
                available=bool(drive),
            )
        resolved["kindLabel"] = SLOT_KIND_LABELS.get(kind, kind)
        return resolved

    @Slot(result="QVariantList")
    def getLauncherSlots(self) -> list[dict]:
        """小窗要画的所有槽位（按配置顺序，带 row），引用失效的会被跳过。"""
        resolved = []
        for slot in self._config["launcher"]["slots"]:
            item = self._resolve_slot(slot)
            if item is not None:
                resolved.append(item)
        return resolved

    @Slot(result="QVariantList")
    def getSlotCatalog(self) -> list[dict]:
        """可选的槽位类型与内置功能，给编辑器的下拉用。"""
        return [
            {"kind": kind, "title": SLOT_KIND_LABELS[kind], "icon": SLOT_KIND_ICONS[kind]}
            for kind in SLOT_KINDS
        ]

    @Slot(result="QVariantList")
    def getToolCatalog(self) -> list[dict]:
        return [{"key": key, "title": title, "icon": icon}
                for key, title, icon in TOOL_CATALOG]

    @Slot(result="QVariantList")
    def getDrives(self) -> list[dict]:
        """本机磁盘列表，给「磁盘」槽位的选择器用。"""
        return _list_drives()

    @Slot(result="QVariantList")
    def getRawLauncherSlots(self) -> list[dict]:
        """编辑器用的原始槽位（不做解析），编辑时要按 row 分组的原始下标。"""
        return [dict(slot) for slot in self._config["launcher"]["slots"]]

    @Slot(result=str)
    def getLauncherStoragePath(self) -> str:
        """第三行那张存储卡片配置的目录（原始值，空串表示用主目录）。"""
        return str(self._config["launcher"].get("storagePath") or "")

    @Slot(int, result="QVariantList")
    def getSlotsInRow(self, row: int) -> list[dict]:
        """某一行的槽位解析结果，按显示顺序。"""
        return [item for item in self.getLauncherSlots() if item.get("row") == row]

    @Slot(result="QVariantMap")
    def getStorageInfo(self) -> dict[str, Any]:
        """第三行的存储卡片：路径与容量。结果带短缓存，避免反复问系统。"""
        now = time.monotonic()
        if self._storage_cache and now - self._storage_cache[0] < STORAGE_TTL:
            return self._storage_cache[1]

        path = self._storagePath()
        info: dict[str, Any] = {
            "path": str(path),
            "label": path.name or str(path),
            "free": "",
            "total": "",
            "percent": 0,
            "available": False,
        }
        try:
            usage = shutil.disk_usage(path)
        except OSError:
            logger.warning("Cannot read disk usage of %s", path)
        else:
            info["available"] = True
            info["free"] = _human_size(usage.free)
            info["total"] = _human_size(usage.total)
            info["percent"] = round(usage.used / usage.total * 100) if usage.total else 0

        self._storage_cache = (now, info)
        return info

    @Slot(result="QVariantMap")
    def refreshStorageInfo(self) -> dict[str, Any]:
        """丢掉缓存重新读一次（磁盘挂载/卸载后手动刷新用）。"""
        self._storage_cache = None
        return self.getStorageInfo()

    def _storagePath(self) -> Path:
        raw = str(self._config["launcher"].get("storagePath") or "").strip()
        candidate = Path(raw).expanduser() if raw else Path.home()
        # 配置里写了个已经不存在的路径时退回主目录，别让小窗显示一片空白。
        return candidate if candidate.exists() else Path.home()

    @Slot(result=str)
    def pickFolder(self) -> str:
        path = QFileDialog.getExistingDirectory(None, "选择文件夹", str(Path.home()))
        return path or ""

    @Slot(result=str)
    def pickProgram(self) -> str:
        """挑一个程序 / 动态库，用于「从程序提取图标」。"""
        path, _ = QFileDialog.getOpenFileName(
            None, "选择程序或 DLL", str(Path.home()),
            "程序与库 (*.exe *.dll *.ico *.lnk);;所有文件 (*)")
        return path or ""

    @Slot(str)
    def openPath(self, path: str) -> None:
        target = Path(path).expanduser()
        if not target.exists():
            self.showToast.emit(f"路径不存在：{target}", "warning")
            return
        self._reveal(target)

    @Slot(str, result=bool)
    def openSlot(self, path: str) -> bool:
        """打开一个 path 类槽位的目标，找不到就报一句。"""
        if not path:
            self.showToast.emit("这一格还没有设置目标", "warning")
            return False
        target = Path(path).expanduser()
        if not target.exists():
            self.showToast.emit(f"路径不存在：{target}", "warning")
            return False
        self._reveal(target)
        return True

    @Slot(result=bool)
    def openRemovableDrive(self) -> bool:
        drive = _find_removable_drive()
        if not drive:
            self.showToast.emit("没有检测到可移动磁盘", "warning")
            return False
        self._reveal(Path(drive))
        return True

    # ── 图标 ──────────────────────────────────────────────────────────
    @Slot(result="QStringList")
    def getBundledIcons(self) -> list[str]:
        """Names of the icon marks shipped under assets/icons/lawnicons."""
        if not BUNDLED_ICON_DIR.is_dir():
            return []
        return sorted(path.stem for path in BUNDLED_ICON_DIR.glob("*.svg"))

    @Slot(result="QVariantList")
    def getCustomIcons(self) -> list[dict]:
        """用户自己的图标库：导入的位图/矢量 + 从程序里抽出来的。"""
        if not self.icon_dir.is_dir():
            return []
        items = []
        for path in sorted(self.icon_dir.iterdir(),
                           key=lambda item: item.stat().st_mtime, reverse=True):
            if path.suffix.lower() not in (".svg", ".png", ".ico", ".jpg", ".jpeg", ".bmp"):
                continue
            items.append({
                "name": path.stem,
                "key": self._icon_key(path),
                "size": _human_size(path.stat().st_size),
            })
        return items

    def _icon_key(self, path: Path) -> str:
        """图标在配置里的写法：``file:<绝对路径>``。"""
        return f"file:{path}"

    @Slot(result=str)
    def importIcon(self) -> str:
        """把用户挑的图标复制进图标库，返回它的 icon key。"""
        path, _ = QFileDialog.getOpenFileName(
            None, "添加图标", str(Path.home()),
            "图标 (*.svg *.png *.ico *.jpg *.jpeg *.bmp);;所有文件 (*)")
        if not path:
            return ""
        source = Path(path)
        if not source.is_file():
            return ""
        target = self.icon_dir / f"{_new_id()}{source.suffix.lower()}"
        try:
            shutil.copy2(source, target)
        except OSError:
            logger.exception("Failed to copy icon %s", source)
            self.showToast.emit("图标复制失败", "error")
            return ""
        self.showToast.emit(f"已添加图标：{source.name}", "success")
        return self._icon_key(target)

    @Slot(str, result=str)
    def extractIcon(self, path: str) -> str:
        """从程序 / 快捷方式 / DLL 里抽出图标，落成 png 存进图标库。

        借用 Qt 的 QFileIconProvider：Windows 上它直接问系统外壳，能拿到 exe 内
        嵌的图标；非 Windows 上会退化成一个通用图标，功能不至于报错消失。
        """
        if not path:
            path = self.pickProgram()
        if not path:
            return ""
        icon = self._icon_provider.icon(QFileInfo(path))
        if icon.isNull():
            self.showToast.emit("这个文件里没有取到图标", "warning")
            return ""

        # 取最大的一档，通常在 32~256 之间。
        pixmap = icon.pixmap(256, 256)
        if pixmap.isNull():
            self.showToast.emit("这个文件里没有取到图标", "warning")
            return ""

        target = self.icon_dir / f"{_new_id()}.png"
        if not pixmap.save(str(target), "PNG"):
            self.showToast.emit("图标保存失败", "error")
            return ""
        self.showToast.emit(f"已提取图标：{Path(path).name}", "success")
        return self._icon_key(target)

    @Slot(str, result=bool)
    def deleteCustomIcon(self, key: str) -> bool:
        """删掉图标库里的一张图；配置里还在引用它的地方会退回默认图标。"""
        name = key[5:] if key.startswith("file:") else key
        target = Path(name)
        # 只允许删图标库里的东西，免得被误导着删掉别处的文件。
        if target.parent.resolve() != self.icon_dir.resolve() or not target.is_file():
            return False
        try:
            target.unlink()
        except OSError:
            logger.exception("Failed to delete icon %s", target)
            return False
        self.showToast.emit("图标已删除", "success")
        return True

    # ------------------------------------------------------------------
    # Write API (called from QML)
    # ------------------------------------------------------------------
    @Slot("QVariantMap", result=bool)
    def addAction(self, action: dict) -> bool:
        action = dict(action)
        if not action.get("id"):
            action["id"] = _new_id()
        self._config["actions"].append(action)
        return self.save(changed="records")

    @Slot("QVariantMap", result=bool)
    def updateAction(self, action: dict) -> bool:
        action = dict(action)
        for index, existing in enumerate(self._config["actions"]):
            if existing["id"] == action.get("id"):
                self._config["actions"][index] = action
                return self.save(changed="records")
        logger.warning("No action with id %s to update", action.get("id"))
        return False

    @Slot(str, result=bool)
    def deleteAction(self, action_id: str) -> bool:
        self._config["actions"] = [a for a in self._config["actions"] if a["id"] != action_id]
        # 引用了这个条目的槽位会随之失效（解析时跳过），顺手清掉引用。
        for slot in self._config["launcher"]["slots"]:
            if slot["kind"] == SLOT_ACTION and slot.get("ref") == action_id:
                slot["ref"] = ""
        saved = self.save(changed="records")
        self.launcherChanged.emit()   # 小窗上引用了它的那一格也要跟着消失
        return saved

    @Slot("QVariantMap", result=bool)
    def duplicateAction(self, action: dict) -> bool:
        clone = dict(action)
        clone.update(
            id=_new_id(),
            name=f"{action.get('name', '')} (副本)",
            hotkey="",
            order=action.get("order", 0) + 1,
        )
        return self.addAction(clone)

    @Slot("QVariantMap", result=bool)
    def addCategory(self, category: dict) -> bool:
        category = dict(category)
        if not category.get("id"):
            category["id"] = _new_id()
        self._config["categories"].append(category)
        return self.save(changed="records")

    @Slot("QVariantMap", result=bool)
    def updateCategory(self, category: dict) -> bool:
        category = dict(category)
        for index, existing in enumerate(self._config["categories"]):
            if existing["id"] != category.get("id"):
                continue
            # Entries reference a category by name, so a rename has to cascade.
            old_name, new_name = existing["name"], category.get("name", existing["name"])
            if old_name != new_name:
                for action in self._config["actions"]:
                    if action.get("category") == old_name:
                        action["category"] = new_name
            self._config["categories"][index] = category
            return self.save(changed="records")
        logger.warning("No category with id %s to update", category.get("id"))
        return False

    @Slot(str, result=bool)
    def deleteCategory(self, category_id: str) -> bool:
        victim = next((c for c in self._config["categories"] if c["id"] == category_id), None)
        if victim is None:
            return False

        self._config["categories"] = [c for c in self._config["categories"] if c["id"] != category_id]
        # Entries store the category *name*; falling back to the id here would
        # strand them outside every category and hide them from the launcher.
        for action in self._config["actions"]:
            if action.get("category") == victim["name"]:
                action["category"] = FALLBACK_CATEGORY
        return self.save(changed="records")

    @Slot(str, int, result=bool)
    def moveAction(self, action_id: str, delta: int) -> bool:
        """Move an entry up/down inside its own category."""
        actions = self._config["actions"]
        for action in actions:
            if action["id"] != action_id:
                continue
            peers = sorted(
                (other for other in actions
                 if other.get("category") == action.get("category")),
                key=lambda item: item.get("order", 0),
            )
            position = peers.index(action)
            target = position + delta
            if not 0 <= target < len(peers):
                return False
            peers.insert(target, peers.pop(position))
            for order, peer in enumerate(peers):
                peer["order"] = order
            return self.save(changed="records")
        return False

    @Slot(str, int, result=bool)
    def moveCategory(self, category_id: str, delta: int) -> bool:
        """Move a category up/down in the sidebar order."""
        categories = self._config["categories"]
        for index, category in enumerate(categories):
            if category["id"] != category_id:
                continue
            target = index + delta
            if not 0 <= target < len(categories):
                return False
            categories.insert(target, categories.pop(index))
            for order, item in enumerate(categories):
                item["order"] = order
            return self.save(changed="records")
        return False

    # ── 槽位编辑 ──────────────────────────────────────────────────────
    def _slots(self) -> list[dict[str, Any]]:
        return self._config["launcher"]["slots"]

    @Slot(int, "QVariantMap", result=bool)
    def addLauncherSlot(self, row: int, slot: dict) -> bool:
        """在某一行末尾追加一个槽位。"""
        kind = str(dict(slot).get("kind") or SLOT_ACTION)
        if kind not in SLOT_KINDS:
            return False
        created = _new_slot(kind, min(max(int(row), 0), LAUNCHER_ROWS - 1))
        for key in ("label", "icon", "ref", "key", "path"):
            if key in slot:
                created[key] = str(slot[key] or "")
        # action / tool 这两个 kind 缺了引用就没法渲染，补一个像样的默认值。
        if kind == SLOT_ACTION and not created.get("ref"):
            created["ref"] = next(
                (a["id"] for a in self._config["actions"] if a.get("enabled", True)), "")
        if kind == SLOT_TOOL and created.get("key") not in TOOL_ICONS:
            created["key"] = TOOL_CATALOG[0][0]
        self._slots().append(created)
        return self.save(changed="launcher")

    @Slot(int, int, "QVariantMap", result=bool)
    def updateLauncherSlot(self, row: int, index: int, slot: dict) -> bool:
        """改第 ``row`` 行第 ``index`` 个槽位（index 是该行内的序号）。"""
        target = self._row_slot(row, index)
        if target is None:
            return False
        slot = dict(slot)
        for key in ("label", "icon", "ref", "key", "path"):
            if key in slot:
                target[key] = str(slot[key] or "")
        return self.save(changed="launcher")

    @Slot(int, int, result=bool)
    def deleteLauncherSlot(self, row: int, index: int) -> bool:
        target = self._row_slot(row, index)
        if target is None:
            return False
        self._slots().remove(target)
        return self.save(changed="launcher")

    @Slot(int, int, int, result=bool)
    def moveLauncherSlot(self, row: int, index: int, delta: int) -> bool:
        """在第 ``row`` 行内前后挪一格。"""
        target = self._row_slot(row, index)
        if target is None:
            return False
        slots = self._slots()
        position = slots.index(target)
        peers = [i for i, s in enumerate(slots) if s["row"] == row]
        order = peers.index(position)
        target_order = order + delta
        if not 0 <= target_order < len(peers):
            return False
        # 和同行的另一格交换位置，行内顺序就是列表顺序。
        other = peers[target_order]
        slots[position], slots[other] = slots[other], slots[position]
        return self.save(changed="launcher")

    def _row_slot(self, row: int, index: int) -> dict[str, Any] | None:
        """按「行的第几个」定位槽位，返回列表里的同一个对象（可直接改）。"""
        peers = [slot for slot in self._slots() if slot["row"] == row]
        if not 0 <= index < len(peers):
            return None
        return peers[index]

    @Slot(str, result=bool)
    def setLauncherStoragePath(self, path: str) -> bool:
        self._config["launcher"]["storagePath"] = str(path or "")
        return self.save(changed="launcher")

    @Slot("QVariantMap", result=bool)
    def updateSettings(self, settings: dict) -> bool:
        settings = dict(settings)
        previous = self._config["settings"]

        # The run-at-login registry entry only needs touching when it changes.
        if "autoStart" in settings and settings["autoStart"] != previous.get("autoStart"):
            set_run_on_startup(bool(settings["autoStart"]))

        previous.update(settings)
        saved = self.save(changed="settings")

        if saved:
            if "globalHotkey" in settings:
                self.hotkeyChanged.emit(str(previous["globalHotkey"]))
            if "alwaysOnTop" in settings:
                self.alwaysOnTopChanged.emit(bool(previous["alwaysOnTop"]))
            if "showTray" in settings:
                self.trayEnabledChanged.emit(bool(previous["showTray"]))
            if "material" in settings:
                self.materialChanged.emit(str(previous["material"]))
        return saved

    @Slot(str, bool, result=bool)
    def toggleAction(self, action_id: str, enabled: bool) -> bool:
        for action in self._config["actions"]:
            if action["id"] == action_id:
                if action.get("enabled", True) == enabled:
                    return True  # 没有变化，不必重写配置（也避免 UI 反复触发写盘）
                action["enabled"] = enabled
                return self.save(changed="records")
        return False

    @Slot("QVariantList", bool, result=bool)
    def setActionsEnabled(self, action_ids: list, enabled: bool) -> bool:
        """批量启停：档案页的多选操作走这里，只写一次盘。"""
        wanted = {str(item) for item in action_ids}
        changed = False
        for action in self._config["actions"]:
            if action["id"] in wanted and action.get("enabled", True) != enabled:
                action["enabled"] = enabled
                changed = True
        return self.save(changed="records") if changed else True

    @Slot("QVariantList", result=bool)
    def deleteActions(self, action_ids: list) -> bool:
        """批量删除，同样是写一次盘。"""
        wanted = {str(item) for item in action_ids}
        if not wanted:
            return True
        self._config["actions"] = [
            a for a in self._config["actions"] if a["id"] not in wanted]
        for slot in self._config["launcher"]["slots"]:
            if slot["kind"] == SLOT_ACTION and slot.get("ref") in wanted:
                slot["ref"] = ""
        saved = self.save(changed="records")
        self.launcherChanged.emit()
        return saved

    @Slot(result=bool)
    def reloadConfig(self) -> bool:
        """Re-read config.yaml from disk and tell the UI about it."""
        self._config = self._load()
        self._storage_cache = None
        self.configChanged.emit()
        self.launcherChanged.emit()
        self.recordsChanged.emit()
        self.settingsChanged.emit()
        return True

    @Slot(str, str)
    def notify(self, message: str, severity: str = "info") -> None:
        """Let QML raise a toast through the same path the backend uses."""
        self.showToast.emit(message, severity)

    @Slot(str)
    def requestPage(self, page: str) -> None:
        """QML 页面请求切到某一页（由 main.py 落到完整窗口上）。"""
        self.pageRequested.emit(str(page))

    @Slot()
    def previewCompact(self) -> None:
        """请求把常驻小窗显示出来（小窗归 main.py 管）。"""
        self.previewCompactRequested.emit()

    @Slot(result=bool)
    def resetToDefaults(self) -> bool:
        return self.save(_default_config(), changed="all")

    @Slot(result=bool)
    def restartAsAdmin(self) -> bool:
        return restart_elevated()

    @Slot(result=bool)
    def importConfig(self) -> bool:
        path, _ = QFileDialog.getOpenFileName(
            None, "导入配置", str(self.config_dir), "YAML (*.yaml *.yml)")
        return bool(path) and self._read_from(Path(path))

    @Slot(result=bool)
    def exportConfig(self) -> bool:
        path, _ = QFileDialog.getSaveFileName(
            None, "导出配置", str(self.config_file), "YAML (*.yaml *.yml)")
        return bool(path) and self._write_to(Path(path))

    @Slot(result=str)
    def pickFile(self) -> str:
        """Native file picker used by the entry editor's "browse" button."""
        path, _ = QFileDialog.getOpenFileName(None, "选择文件或程序", str(Path.home()))
        return path or ""

    @Slot("QVariantMap")
    def executeAction(self, action: dict) -> None:
        name = action.get("name", "")
        if self.action_executor is None:
            self.showToast.emit("动作执行器未初始化", "error")
        elif self.action_executor.execute(dict(action)):
            self.showToast.emit(f"已执行: {name}", "success")
        else:
            self.showToast.emit(f"执行失败: {name}", "error")

    @Slot("QVariantMap", result=bool)
    def runLauncherSlot(self, slot: dict) -> bool:
        """执行小窗上的一个槽位。

        ``tool`` 类槽位牵扯窗口操作，由 QML 自己处理；这里只管能把活儿干完的
        ``action`` / ``path`` / ``usb``。
        """
        kind = str(slot.get("kind") or "")
        if kind == SLOT_ACTION:
            ref = str(slot.get("ref") or "")
            entry = next((a for a in self._config["actions"] if a["id"] == ref), None)
            if entry is None:
                self.showToast.emit("这个槽位引用的条目已经不存在了", "warning")
                return False
            self.executeAction(entry)
            return True
        if kind == SLOT_USB:
            return self.openRemovableDrive()
        if kind == SLOT_PATH:
            return self.openSlot(str(slot.get("path") or ""))
        return False

    # ------------------------------------------------------------------
    # Shell integration
    # ------------------------------------------------------------------
    @Slot()
    def openConfigFolder(self) -> None:
        self._reveal(self.config_dir)

    @Slot()
    def openConfigFile(self) -> None:
        self._reveal(self.config_file)

    @Slot()
    def openIconFolder(self) -> None:
        self._reveal(self.icon_dir)

    @Slot(result="QVariantMap")
    def getRuntimeInfo(self) -> dict[str, Any]:
        """关于页要显示的运行环境信息。"""
        import platform

        from PySide6 import __version__ as pyside_version
        from PySide6.QtCore import qVersion

        return {
            "version": APP_VERSION,
            "python": platform.python_version(),
            "qt": qVersion(),
            "pyside": pyside_version,
            "system": f"{platform.system()} {platform.release()}",
            "configDir": str(self.config_dir),
            "configFile": str(self.config_file),
            "iconDir": str(self.icon_dir),
            "logFile": str(self.config_dir / "launcher.log"),
            "backend": "RinUI（内联，MIT）",
        }

    @staticmethod
    def _reveal(path: Path) -> None:
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(path)))

    # ------------------------------------------------------------------
    # External change watching
    # ------------------------------------------------------------------
    def startWatching(self) -> None:
        if self._observer is not None:
            return
        self._observer = Observer()
        self._observer.schedule(
            _ConfigWatcher(self._onExternalChange), str(self.config_dir), recursive=False)
        self._observer.start()
        logger.info("Watching %s for external changes", self.config_file)

    def stopWatching(self) -> None:
        if self._observer is None:
            return
        self._observer.stop()
        self._observer.join()
        self._observer = None

    def _onExternalChange(self) -> None:
        if time.monotonic() < self._quiet_until:  # we just wrote it ourselves
            return
        logger.info("Config changed on disk, reloading")
        self.reloadConfig()
