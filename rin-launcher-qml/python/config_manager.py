"""
Configuration manager for Rin Launcher (QML version).
Handles YAML config loading, saving, and action/category management.
"""

from __future__ import annotations

import logging
import os
import shutil
import uuid
from pathlib import Path
from typing import Any, Callable, List, Optional

import yaml
from PySide6.QtCore import QObject, Signal, Slot
from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer


logger = logging.getLogger(__name__)


class ConfigChangeHandler(FileSystemEventHandler):
    def __init__(self, callback: Callable[[], None]):
        self.callback = callback
        self._last_event_time = 0

    def on_modified(self, event):
        if event.is_directory:
            return
        if event.src_path.endswith((".yaml", ".yml")):
            import time
            now = time.time()
            if now - self._last_event_time > 0.5:
                self._last_event_time = now
                self.callback()


class ConfigManager(QObject):
    showToast = Signal(str, str)

    def __init__(self, config_dir: Optional[Path] = None, parent: Optional[QObject] = None):
        super().__init__(parent)
        if config_dir is None:
            config_dir = Path.home() / "AppData" / "Roaming" / "RinLauncher"
        self.config_dir = Path(config_dir)
        self.config_dir.mkdir(parents=True, exist_ok=True)

        self.config_file = self.config_dir / "config.yaml"
        self.backup_dir = self.config_dir / "backups"
        self.backup_dir.mkdir(exist_ok=True)

        self._observer: Optional[Observer] = None
        self._change_callbacks: List[Callable[[], None]] = []
        self.action_executor = None
        self._config = self.load()

    @property
    def config(self) -> dict:
        return self._config

    def load(self) -> dict:
        if self.config_file.exists():
            try:
                with open(self.config_file, "r", encoding="utf-8") as f:
                    data = yaml.safe_load(f) or {}
                logger.info(f"Loaded config from {self.config_file}")
                return self._normalize_config(data)
            except Exception as e:
                logger.error(f"Failed to load config: {e}")
                return self._create_default()
        return self._create_default()

    def _create_default(self) -> dict:
        config = {
            "version": 1,
            "actions": [
                {"id": uuid.uuid4().hex[:8], "name": "记事本", "type": "file", "target": "notepad.exe",
                 "category": "常用", "icon": "ic_fluent_pen_20_regular", "enabled": True, "order": 0},
                {"id": uuid.uuid4().hex[:8], "name": "计算器", "type": "file", "target": "calc.exe",
                 "category": "常用", "icon": "ic_fluent_calculator_20_regular", "enabled": True, "order": 1},
                {"id": uuid.uuid4().hex[:8], "name": "文件资源管理器", "type": "file", "target": "explorer.exe",
                 "category": "系统工具", "icon": "ic_fluent_folder_20_regular", "enabled": True, "order": 0},
                {"id": uuid.uuid4().hex[:8], "name": "命令提示符", "type": "cmd", "target": "cmd.exe",
                 "category": "开发工具", "icon": "ic_fluent_terminal_20_regular", "enabled": True, "order": 0},
                {"id": uuid.uuid4().hex[:8], "name": "打开配置目录", "type": "file", "target": "{configdir}",
                 "category": "开发工具", "icon": "ic_fluent_settings_20_regular", "enabled": True, "order": 1},
                {"id": uuid.uuid4().hex[:8], "name": "RinUI 官网", "type": "url", "target": "https://ui.rinlit.cn",
                 "category": "媒体娱乐", "icon": "ic_fluent_globe_20_regular", "enabled": True, "order": 0},
            ],
            "categories": [
                {"id": uuid.uuid4().hex[:8], "name": "常用", "icon": "ic_fluent_star_20_regular", "order": 0, "expanded": True},
                {"id": uuid.uuid4().hex[:8], "name": "系统工具", "icon": "ic_fluent_toolbox_20_regular", "order": 1, "expanded": True},
                {"id": uuid.uuid4().hex[:8], "name": "开发工具", "icon": "ic_fluent_code_20_regular", "order": 2, "expanded": True},
                {"id": uuid.uuid4().hex[:8], "name": "媒体娱乐", "icon": "ic_fluent_video_20_regular", "order": 3, "expanded": True},
                {"id": uuid.uuid4().hex[:8], "name": "默认", "icon": "ic_fluent_folder_20_regular", "order": 99, "expanded": True},
            ],
            "settings": {
                "theme": "system",
                "language": "zh_CN",
                "showTray": True,
                "startMinimized": False,
                "autoStart": False,
                "globalHotkey": "Ctrl+Space",
                "searchEngine": "https://www.bing.com/search?q={query}",
                "gridColumns": 6,
                "itemSize": 96,
                "animationEnabled": True,
                "blurBackground": True,
                "accentColor": "#0078d4",
                "fontFamily": "Microsoft YaHei UI",
                "fontSize": 12,
                "adminAutoElevate": True,
                "confirmAdminActions": True,
                "logLevel": "INFO"
            }
        }
        self.save(config)
        return config

    def _normalize_config(self, data: dict) -> dict:
        # Ensure all required fields exist
        if "version" not in data:
            data["version"] = 1
        if "actions" not in data:
            data["actions"] = []
        if "categories" not in data:
            data["categories"] = []
        if "settings" not in data:
            data["settings"] = {}
        
        # Normalize settings
        default_settings = self._create_default()["settings"]
        for key, value in default_settings.items():
            if key not in data["settings"]:
                data["settings"][key] = value
                
        return data

    def save(self, config: Optional[dict] = None) -> bool:
        if config is not None:
            self._config = config

        try:
            if self.config_file.exists():
                backup_file = self.backup_dir / f"config.yaml.bak.{int(__import__('time').time())}"
                shutil.copy2(self.config_file, backup_file)
                self._cleanup_old_backups()

            with open(self.config_file, "w", encoding="utf-8") as f:
                yaml.dump(
                    self._config,
                    f,
                    allow_unicode=True,
                    sort_keys=False,
                    indent=2,
                )
            logger.info(f"Saved config to {self.config_file}")
            self._notify_changes()
            return True
        except Exception as e:
            logger.error(f"Failed to save config: {e}")
            return False

    def _cleanup_old_backups(self, keep: int = 10):
        backups = sorted(self.backup_dir.glob("config.yaml.bak.*"))
        for old in backups[:-keep]:
            old.unlink(missing_ok=True)

    def export(self, path: Path) -> bool:
        try:
            with open(path, "w", encoding="utf-8") as f:
                yaml.dump(
                    self._config,
                    f,
                    allow_unicode=True,
                    sort_keys=False,
                    indent=2,
                )
            return True
        except Exception as e:
            logger.error(f"Failed to export config: {e}")
            return False

    def import_config(self, path: Path) -> bool:
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = yaml.safe_load(f) or {}
            self._config = self._normalize_config(data)
            return self.save()
        except Exception as e:
            logger.error(f"Failed to import config: {e}")
            return False

    def add_action(self, action: dict) -> bool:
        if "id" not in action:
            action["id"] = uuid.uuid4().hex[:8]
        self._config["actions"].append(action)
        return self.save()

    def update_action(self, action: dict) -> bool:
        for i, a in enumerate(self._config["actions"]):
            if a["id"] == action["id"]:
                self._config["actions"][i] = action
                return self.save()
        return False

    def delete_action(self, action_id: str) -> bool:
        self._config["actions"] = [a for a in self._config["actions"] if a["id"] != action_id]
        return self.save()

    def duplicate_action(self, action: dict) -> bool:
        new_action = action.copy()
        new_action["id"] = uuid.uuid4().hex[:8]
        new_action["name"] = f"{action['name']} (副本)"
        new_action["hotkey"] = ""
        new_action["order"] = action.get("order", 0) + 1
        return self.add_action(new_action)

    def add_category(self, category: dict) -> bool:
        if "id" not in category:
            category["id"] = uuid.uuid4().hex[:8]
        self._config["categories"].append(category)
        return self.save()

    def update_category(self, category: dict) -> bool:
        for i, c in enumerate(self._config["categories"]):
            if c["id"] == category["id"]:
                self._config["categories"][i] = category
                return self.save()
        return False

    def delete_category(self, category_id: str) -> bool:
        self._config["categories"] = [c for c in self._config["categories"] if c["id"] != category_id]
        for action in self._config["actions"]:
            if action.get("category") == category_id:
                action["category"] = "默认"
        return self.save()

    def update_settings(self, settings: dict) -> bool:
        self._config["settings"].update(settings)
        return self.save()

    def get_actions(self) -> List[dict]:
        return self._config["actions"]

    def get_categories(self) -> List[dict]:
        return self._config["categories"]

    def get_categories_model(self) -> List[str]:
        return [c["name"] for c in self._config["categories"]]

    def get_category_index(self, category_name: str) -> int:
        for i, c in enumerate(self._config["categories"]):
            if c["name"] == category_name:
                return i
        return 0

    def search_actions(self, query: str) -> List[dict]:
        query = query.lower()
        results = []
        for action in self._config["actions"]:
            if not action.get("enabled", True):
                continue
            if query in action.get("name", "").lower() or query in action.get("tooltip", "").lower():
                results.append(action)
        return results

    def get_categorized_actions(self) -> List[dict]:
        actions_by_cat = {}
        for action in self._config["actions"]:
            if not action.get("enabled", True):
                continue
            cat = action.get("category", "默认")
            if cat not in actions_by_cat:
                actions_by_cat[cat] = []
            actions_by_cat[cat].append(action)
        
        result = []
        for category in sorted(self._config["categories"], key=lambda c: c.get("order", 0)):
            cat_actions = actions_by_cat.get(category["name"], [])
            if cat_actions or category["name"] == "默认":
                result.append({
                    "categoryName": category["name"],
                    "categoryIcon": category.get("icon", "ic_fluent_folder_20_regular"),
                    "actions": sorted(cat_actions, key=lambda a: a.get("order", 0))
                })
        return result

    def register_change_callback(self, callback: Callable[[], None]):
        if callback not in self._change_callbacks:
            self._change_callbacks.append(callback)

    def unregister_change_callback(self, callback: Callable[[], None]):
        if callback in self._change_callbacks:
            self._change_callbacks.remove(callback)

    def _notify_changes(self):
        for callback in self._change_callbacks:
            try:
                callback()
            except Exception as e:
                logger.error(f"Config change callback failed: {e}")

    def start_watching(self):
        if self._observer is not None:
            return
        self._observer = Observer()
        handler = ConfigChangeHandler(self._on_external_change)
        self._observer.schedule(handler, str(self.config_dir), recursive=False)
        self._observer.start()
        logger.info("Started config file watcher")

    def stop_watching(self):
        if self._observer is not None:
            self._observer.stop()
            self._observer.join()
            self._observer = None
            logger.info("Stopped config file watcher")

    def _on_external_change(self):
        logger.info("Config file changed externally, reloading...")
        self._config = self.load()
        self._notify_changes()

    def set_auto_start(self, enable: bool):
        if os.name != "nt":
            return
        try:
            import winreg
            key = winreg.OpenKey(
                winreg.HKEY_CURRENT_USER,
                r"Software\Microsoft\Windows\CurrentVersion\Run",
                0, winreg.KEY_SET_VALUE
            )
            if enable:
                import sys
                exe_path = sys.executable if getattr(sys, 'frozen', False) else f'"{sys.executable}" "{sys.argv[0]}"'
                winreg.SetValueEx(key, "RinLauncher", 0, winreg.REG_SZ, exe_path)
            else:
                winreg.DeleteValue(key, "RinLauncher")
            winreg.CloseKey(key)
            self._config["settings"]["autoStart"] = enable
        except Exception as e:
            logger.error(f"Failed to set auto start: {e}")

    def open_config_folder(self):
        from PySide6.QtCore import QUrl
        from PySide6.QtGui import QDesktopServices
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(self.config_dir)))

    def open_config_file(self):
        from PySide6.QtCore import QUrl
        from PySide6.QtGui import QDesktopServices
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(self.config_file)))

    def import_config_dialog(self):
        # This will be called from QML via FileDialog
        pass

    def export_config_dialog(self):
        # This will be called from QML via FileDialog
        pass

    def reset_to_defaults(self):
        self._config = self._create_default()
        self.save()

    def restart_as_admin(self) -> bool:
        if os.name != "nt":
            return False
        try:
            import ctypes
            from ctypes import wintypes
            
            if ctypes.windll.shell32.IsUserAnAdmin():
                return True
            
            import sys
            if getattr(sys, 'frozen', False):
                exe_path = sys.executable
                params = " ".join([f'"{arg}"' for arg in sys.argv[1:]])
            else:
                exe_path = sys.executable
                script = sys.argv[0]
                args = " ".join([f'"{arg}"' for arg in sys.argv[1:]])
                params = f'"{script}" {args}'
            
            sei = wintypes.SHELLEXECUTEINFOW()
            sei.cbSize = ctypes.sizeof(sei)
            sei.fMask = 0x00000040
            sei.hwnd = 0
            sei.lpVerb = "runas"
            sei.lpFile = exe_path
            sei.lpParameters = params
            sei.nShow = 1
            
            if ctypes.windll.shell32.ShellExecuteExW(ctypes.byref(sei)):
                os._exit(0)
            return False
        except Exception as e:
            logger.error(f"Failed to restart as admin: {e}")
            return False

    # ------------------------------------------------------------------
    # QML-facing API (camelCase slots exposed to the QML layer)
    # ------------------------------------------------------------------
    @Slot(result="QVariantList")
    def getActions(self) -> List[dict]:
        return self.get_actions()

    @Slot(result="QVariantList")
    def getCategories(self) -> List[dict]:
        return self.get_categories()

    @Slot(result="QStringList")
    def getCategoriesModel(self) -> List[str]:
        return self.get_categories_model()

    @Slot(str, result=int)
    def getCategoryIndex(self, category_name: str) -> int:
        return self.get_category_index(category_name)

    @Slot(str, result="QVariantList")
    def searchActions(self, query: str) -> List[dict]:
        return self.search_actions(query)

    @Slot(result="QVariantList")
    def getCategorizedActions(self) -> List[dict]:
        return self.get_categorized_actions()

    @Slot("QVariantMap", result=bool)
    def addAction(self, action: dict) -> bool:
        return self.add_action(dict(action))

    @Slot("QVariantMap", result=bool)
    def updateAction(self, action: dict) -> bool:
        return self.update_action(dict(action))

    @Slot(str, result=bool)
    def deleteAction(self, action_id: str) -> bool:
        return self.delete_action(action_id)

    @Slot("QVariantMap", result=bool)
    def duplicateAction(self, action: dict) -> bool:
        return self.duplicate_action(dict(action))

    @Slot("QVariantMap", result=bool)
    def addCategory(self, category: dict) -> bool:
        return self.add_category(dict(category))

    @Slot("QVariantMap", result=bool)
    def updateCategory(self, category: dict) -> bool:
        return self.update_category(dict(category))

    @Slot(str, result=bool)
    def deleteCategory(self, category_id: str) -> bool:
        return self.delete_category(category_id)

    @Slot("QVariantMap", result=bool)
    def updateSettings(self, settings: dict) -> bool:
        return self.update_settings(dict(settings))

    @Slot(result=bool)
    def saveConfig(self) -> bool:
        return self.save()

    @Slot(bool)
    def setAutoStart(self, enable: bool) -> None:
        self.set_auto_start(enable)
        self.save()

    @Slot(result=bool)
    def resetToDefaults(self) -> bool:
        self.reset_to_defaults()
        return True

    @Slot(result=bool)
    def restartAsAdmin(self) -> bool:
        return self.restart_as_admin()

    @Slot()
    def openConfigFolder(self) -> None:
        self.open_config_folder()

    @Slot()
    def openConfigFile(self) -> None:
        self.open_config_file()

    @Slot(result=bool)
    def importConfig(self) -> bool:
        from PySide6.QtWidgets import QFileDialog
        path, _ = QFileDialog.getOpenFileName(
            None, "导入配置", str(self.config_dir), "YAML (*.yaml *.yml)"
        )
        if not path:
            return False
        return self.import_config(Path(path))

    @Slot(result=bool)
    def exportConfig(self) -> bool:
        from PySide6.QtWidgets import QFileDialog
        path, _ = QFileDialog.getSaveFileName(
            None, "导出配置", str(self.config_dir / "config.yaml"), "YAML (*.yaml *.yml)"
        )
        if not path:
            return False
        return self.export(Path(path))

    @Slot("QVariantMap")
    def executeAction(self, action: dict) -> None:
        if self.action_executor is None:
            self.showToast.emit("动作执行器未初始化", "error")
            return
        ok = self.action_executor.execute(dict(action))
        if ok:
            self.showToast.emit(f"已执行: {action.get('name', '')}", "success")
        else:
            self.showToast.emit(f"执行失败: {action.get('name', '')}", "error")