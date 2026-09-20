"""Configuration store for Rin Launcher.

Owns ``config.yaml`` and exposes it to QML through camelCase ``@Slot`` methods
(QML resolves the Python attribute name, so the QML-facing API *is* camelCase —
there is no separate snake_case layer).
"""

from __future__ import annotations

import logging
import shutil
import time
import uuid
from collections.abc import Callable
from pathlib import Path
from typing import Any

import yaml
from PySide6.QtCore import QObject, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices
from PySide6.QtWidgets import QFileDialog
from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

from rin_launcher.elevation import restart_elevated, set_run_on_startup

logger = logging.getLogger(__name__)

DEFAULT_CONFIG_DIR = Path.home() / "AppData" / "Roaming" / "RinLauncher"
FALLBACK_CATEGORY = "默认"
ICON_DIR = Path(__file__).resolve().parent.parent / "assets" / "icons" / "lawnicons"

DEFAULT_SETTINGS: dict[str, Any] = {
    "theme": "system",
    "language": "zh_CN",
    "showTray": True,
    "startMinimized": False,
    "autoStart": False,
    "alwaysOnTop": True,
    "globalHotkey": "Ctrl+Space",
    "searchEngine": "https://www.bing.com/search?q={query}",
    "gridColumns": 8,
    "itemSize": 96,
    "animationEnabled": True,
    "blurBackground": True,
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
        "version": 1,
        "actions": actions,
        "categories": categories,
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
    configChanged = Signal()
    # The window / tray / hotkey owner listens to these and applies the change.
    hotkeyChanged = Signal(str)
    alwaysOnTopChanged = Signal(bool)
    trayEnabledChanged = Signal(bool)

    def __init__(self, config_dir: Path | None = None, parent: QObject | None = None):
        super().__init__(parent)
        self.config_dir = Path(config_dir) if config_dir else DEFAULT_CONFIG_DIR
        self.config_file = self.config_dir / "config.yaml"
        self.backup_dir = self.config_dir / "backups"
        self.backup_dir.mkdir(parents=True, exist_ok=True)

        self.action_executor = None
        self._observer: Observer | None = None
        self._quiet_until = 0.0  # ignores the watcher echo of our own writes
        self._categorized: list[dict] | None = None
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
            self.save(config)
            return config
        try:
            with open(self.config_file, encoding="utf-8") as handle:
                return self._normalize(yaml.safe_load(handle) or {})
        except Exception:
            logger.exception("Failed to read %s, falling back to defaults", self.config_file)
            return _default_config()

    def _normalize(self, data: dict[str, Any]) -> dict[str, Any]:
        data.setdefault("version", 1)
        data.setdefault("actions", [])
        data.setdefault("categories", [])
        # settings keys added by newer builds get their default value
        data["settings"] = {**DEFAULT_SETTINGS, **(data.get("settings") or {})}
        return data

    def save(self, config: dict[str, Any] | None = None) -> bool:
        if config is not None:
            self._config = config
        try:
            if self.config_file.exists():
                self._rotate_backups()
            self._quiet_until = time.monotonic() + 1.0
            with open(self.config_file, "w", encoding="utf-8") as handle:
                yaml.dump(self._config, handle, allow_unicode=True, sort_keys=False, indent=2)
        except Exception:
            logger.exception("Failed to write %s", self.config_file)
            return False

        self._categorized = None
        self.configChanged.emit()
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
        return self.save()

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

    @Slot(result="QVariantList")
    def getCategorizedActions(self) -> list[dict]:
        if self._categorized is None:
            enabled = [a for a in self._config["actions"] if a.get("enabled", True)]
            self._categorized = self._group_by_category(enabled)
        return self._categorized

    @Slot(str, result="QVariantList")
    def searchActions(self, query: str) -> list[dict]:
        """Search results use the same grouped shape as getCategorizedActions()."""
        needle = query.strip().lower()
        if not needle:
            return self.getCategorizedActions()
        matches = [
            action for action in self._config["actions"]
            if action.get("enabled", True)
            and (needle in action.get("name", "").lower()
                 or needle in action.get("tooltip", "").lower())
        ]
        # No empty fallback bucket among search results.
        return self._group_by_category(matches, keep_empty_fallback=False)

    def _group_by_category(self, actions: list[dict], keep_empty_fallback: bool = True) -> list[dict]:
        buckets: dict[str, list[dict]] = {}
        for action in actions:
            buckets.setdefault(action.get("category", FALLBACK_CATEGORY), []).append(action)

        sections = []
        known = set()
        for category in sorted(self._config["categories"], key=lambda c: c.get("order", 0)):
            name = category["name"]
            known.add(name)
            if name in buckets or (keep_empty_fallback and name == FALLBACK_CATEGORY):
                sections.append({
                    "categoryName": name,
                    "categoryIcon": category.get("icon", "ic_fluent_folder_20_regular"),
                    "actions": sorted(buckets.get(name, []), key=lambda a: a.get("order", 0)),
                })

        # An entry whose category was deleted or renamed by hand must still be
        # reachable, otherwise it silently vanishes from the launcher.
        orphans = [action for name, items in buckets.items() if name not in known for action in items]
        if orphans:
            orphans.sort(key=lambda action: action.get("order", 0))
            fallback = next((s for s in sections if s["categoryName"] == FALLBACK_CATEGORY), None)
            if fallback is None:
                sections.append({
                    "categoryName": FALLBACK_CATEGORY,
                    "categoryIcon": "ic_fluent_folder_20_regular",
                    "actions": orphans,
                })
            else:
                fallback["actions"] = sorted(fallback["actions"] + orphans,
                                             key=lambda action: action.get("order", 0))
        return sections

    # ------------------------------------------------------------------
    # Write API (called from QML)
    # ------------------------------------------------------------------
    @Slot("QVariantMap", result=bool)
    def addAction(self, action: dict) -> bool:
        action = dict(action)
        if not action.get("id"):
            action["id"] = _new_id()
        self._config["actions"].append(action)
        return self.save()

    @Slot("QVariantMap", result=bool)
    def updateAction(self, action: dict) -> bool:
        action = dict(action)
        for index, existing in enumerate(self._config["actions"]):
            if existing["id"] == action.get("id"):
                self._config["actions"][index] = action
                return self.save()
        logger.warning("No action with id %s to update", action.get("id"))
        return False

    @Slot(str, result=bool)
    def deleteAction(self, action_id: str) -> bool:
        self._config["actions"] = [a for a in self._config["actions"] if a["id"] != action_id]
        return self.save()

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
        return self.save()

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
            return self.save()
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
        return self.save()

    @Slot("QVariantMap", result=bool)
    def updateSettings(self, settings: dict) -> bool:
        settings = dict(settings)
        previous = self._config["settings"]

        # The run-at-login registry entry only needs touching when it changes.
        if "autoStart" in settings and settings["autoStart"] != previous.get("autoStart"):
            set_run_on_startup(bool(settings["autoStart"]))

        previous.update(settings)
        saved = self.save()

        if saved:
            if "globalHotkey" in settings:
                self.hotkeyChanged.emit(str(previous["globalHotkey"]))
            if "alwaysOnTop" in settings:
                self.alwaysOnTopChanged.emit(bool(previous["alwaysOnTop"]))
            if "showTray" in settings:
                self.trayEnabledChanged.emit(bool(previous["showTray"]))
        return saved

    @Slot(str, bool, result=bool)
    def toggleAction(self, action_id: str, enabled: bool) -> bool:
        for action in self._config["actions"]:
            if action["id"] == action_id:
                if action.get("enabled", True) == enabled:
                    return True  # 没有变化，不必重写配置（也避免 UI 反复触发写盘）
                action["enabled"] = enabled
                return self.save()
        return False

    @Slot(str, int, result=bool)
    def moveAction(self, action_id: str, delta: int) -> bool:
        """Move an entry up/down inside its own category."""
        actions = self._config["actions"]
        for index, action in enumerate(actions):
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
            return self.save()
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
            return self.save()
        return False

    @Slot(result=bool)
    def reloadConfig(self) -> bool:
        """Re-read config.yaml from disk and tell the UI about it."""
        self._config = self._load()
        self._categorized = None
        self.configChanged.emit()
        return True

    @Slot(result="QStringList")
    def getBundledIcons(self) -> list[str]:
        """Names of the icon marks shipped under assets/icons/lawnicons."""
        if not ICON_DIR.is_dir():
            return []
        return sorted(path.stem for path in ICON_DIR.glob("*.svg"))

    @Slot(str, str)
    def notify(self, message: str, severity: str = "info") -> None:
        """Let QML raise a toast through the same path the backend uses."""
        self.showToast.emit(message, severity)

    @Slot(result=bool)
    def resetToDefaults(self) -> bool:
        return self.save(_default_config())

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

    # ------------------------------------------------------------------
    # Shell integration
    # ------------------------------------------------------------------
    @Slot()
    def openConfigFolder(self) -> None:
        self._reveal(self.config_dir)

    @Slot()
    def openConfigFile(self) -> None:
        self._reveal(self.config_file)

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
        self._config = self._load()
        self._categorized = None
        self.configChanged.emit()
