from __future__ import annotations

import logging
import shutil
from pathlib import Path
from typing import Any

import yaml
from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

from .models import Action, AppSettings, Category, LauncherConfig

logger = logging.getLogger(__name__)


class ConfigChangeHandler(FileSystemEventHandler):
    def __init__(self, callback):
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


class ConfigManager:
    def __init__(self, config_dir: Path | None = None):
        if config_dir is None:
            config_dir = Path.home() / "AppData" / "Roaming" / "RinLauncher"
        self.config_dir = config_dir
        self.config_dir.mkdir(parents=True, exist_ok=True)

        self.config_file = self.config_dir / "config.yaml"
        self.backup_dir = self.config_dir / "backups"
        self.backup_dir.mkdir(exist_ok=True)

        self._config: LauncherConfig | None = None
        self._observer: Observer | None = None
        self._change_callbacks: list[callable] = []

    @property
    def config(self) -> LauncherConfig:
        if self._config is None:
            self._config = self.load()
        return self._config

    def load(self) -> LauncherConfig:
        if self.config_file.exists():
            try:
                with open(self.config_file, "r", encoding="utf-8") as f:
                    data = yaml.safe_load(f) or {}
                logger.info(f"Loaded config from {self.config_file}")
                return LauncherConfig.from_dict(data)
            except Exception as e:
                logger.error(f"Failed to load config: {e}")
                return self._create_default()
        return self._create_default()

    def _create_default(self) -> LauncherConfig:
        config = LauncherConfig()
        config.categories = config.get_default_categories()
        self.save(config)
        return config

    def save(self, config: LauncherConfig | None = None) -> bool:
        if config is not None:
            self._config = config

        if self._config is None:
            return False

        try:
            if self.config_file.exists():
                backup_file = self.backup_dir / f"config.yaml.bak.{int(__import__('time').time())}"
                shutil.copy2(self.config_file, backup_file)
                self._cleanup_old_backups()

            with open(self.config_file, "w", encoding="utf-8") as f:
                yaml.dump(
                    self._config.to_dict(),
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
            if self._config is None:
                self._config = self.load()
            with open(path, "w", encoding="utf-8") as f:
                yaml.dump(
                    self._config.to_dict(),
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
            self._config = LauncherConfig.from_dict(data)
            return self.save()
        except Exception as e:
            logger.error(f"Failed to import config: {e}")
            return False

    def add_action(self, action: Action) -> bool:
        self.config.actions.append(action)
        return self.save()

    def update_action(self, action: Action) -> bool:
        for i, a in enumerate(self.config.actions):
            if a.id == action.id:
                self.config.actions[i] = action
                return self.save()
        return False

    def delete_action(self, action_id: str) -> bool:
        self.config.actions = [a for a in self.config.actions if a.id != action_id]
        return self.save()

    def add_category(self, category: Category) -> bool:
        self.config.categories.append(category)
        return self.save()

    def update_category(self, category: Category) -> bool:
        for i, c in enumerate(self.config.categories):
            if c.id == category.id:
                self.config.categories[i] = category
                return self.save()
        return False

    def delete_category(self, category_id: str) -> bool:
        self.config.categories = [c for c in self.config.categories if c.id != category_id]
        for action in self.config.actions:
            if action.category == category_id:
                action.category = "默认"
        return self.save()

    def update_settings(self, settings: AppSettings) -> bool:
        self.config.settings = settings
        return self.save()

    def register_change_callback(self, callback: callable):
        if callback not in self._change_callbacks:
            self._change_callbacks.append(callback)

    def unregister_change_callback(self, callback: callable):
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
        old_config = self._config
        self._config = self.load()
        self._notify_changes()

    def get_actions_by_category(self, category: str) -> list[Action]:
        return [a for a in self.config.actions if a.category == category and a.enabled]

    def get_all_categories(self) -> list[Category]:
        return self.config.categories

    def search_actions(self, query: str) -> list[Action]:
        query = query.lower()
        results = []
        for action in self.config.actions:
            if not action.enabled:
                continue
            if query in action.name.lower() or query in action.tooltip.lower():
                results.append(action)
        return results