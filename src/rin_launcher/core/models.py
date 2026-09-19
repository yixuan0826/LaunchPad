from __future__ import annotations

import enum
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Literal


class ActionType(str, enum.Enum):
    FILE = "file"
    CMD = "cmd"
    URL = "url"
    KEYMOUSE = "keymouse"


class RunAs(str, enum.Enum):
    USER = "user"
    ADMIN = "admin"


@dataclass
class KeyMouseStep:
    type: Literal["key", "mouse", "wait"]
    key: str | None = None
    action: Literal["press", "release", "click", "move", "scroll"] | None = None
    x: int | None = None
    y: int | None = None
    dx: int | None = None
    dy: int | None = None
    button: Literal["left", "right", "middle"] = "left"
    duration: float = 0.0


@dataclass
class Action:
    id: str = field(default_factory=lambda: uuid.uuid4().hex[:8])
    name: str = ""
    icon: str = "fa5s.rocket"
    type: ActionType = ActionType.FILE
    target: str = ""
    arguments: str = ""
    working_dir: str = ""
    run_as: RunAs = RunAs.USER
    keymouse_steps: list[KeyMouseStep] = field(default_factory=list)
    category: str = "默认"
    enabled: bool = True
    hotkey: str = ""
    tooltip: str = ""
    order: int = 0

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "icon": self.icon,
            "type": self.type.value,
            "target": self.target,
            "arguments": self.arguments,
            "working_dir": self.working_dir,
            "run_as": self.run_as.value,
            "keymouse_steps": [
                {
                    "type": s.type,
                    "key": s.key,
                    "action": s.action,
                    "x": s.x,
                    "y": s.y,
                    "dx": s.dx,
                    "dy": s.dy,
                    "button": s.button,
                    "duration": s.duration,
                }
                for s in self.keymouse_steps
            ],
            "category": self.category,
            "enabled": self.enabled,
            "hotkey": self.hotkey,
            "tooltip": self.tooltip,
            "order": self.order,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Action:
        steps = [
            KeyMouseStep(
                type=s["type"],
                key=s.get("key"),
                action=s.get("action"),
                x=s.get("x"),
                y=s.get("y"),
                dx=s.get("dx"),
                dy=s.get("dy"),
                button=s.get("button", "left"),
                duration=s.get("duration", 0.0),
            )
            for s in data.get("keymouse_steps", [])
        ]
        return cls(
            id=data.get("id", uuid.uuid4().hex[:8]),
            name=data.get("name", ""),
            icon=data.get("icon", "fa5s.rocket"),
            type=ActionType(data.get("type", "file")),
            target=data.get("target", ""),
            arguments=data.get("arguments", ""),
            working_dir=data.get("working_dir", ""),
            run_as=RunAs(data.get("run_as", "user")),
            keymouse_steps=steps,
            category=data.get("category", "默认"),
            enabled=data.get("enabled", True),
            hotkey=data.get("hotkey", ""),
            tooltip=data.get("tooltip", ""),
            order=data.get("order", 0),
        )


@dataclass
class Category:
    id: str = field(default_factory=lambda: uuid.uuid4().hex[:8])
    name: str = "默认"
    icon: str = "fa5s.folder"
    order: int = 0
    expanded: bool = True

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "icon": self.icon,
            "order": self.order,
            "expanded": self.expanded,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Category:
        return cls(
            id=data.get("id", uuid.uuid4().hex[:8]),
            name=data.get("name", "默认"),
            icon=data.get("icon", "fa5s.folder"),
            order=data.get("order", 0),
            expanded=data.get("expanded", True),
        )


@dataclass
class AppSettings:
    theme: Literal["system", "light", "dark"] = "system"
    language: str = "zh_CN"
    show_tray: bool = True
    start_minimized: bool = False
    auto_start: bool = False
    global_hotkey: str = "ctrl+space"
    search_engine: str = "https://www.bing.com/search?q={query}"
    grid_columns: int = 6
    item_size: int = 96
    animation_enabled: bool = True
    blur_background: bool = True
    accent_color: str = "#0078d4"
    font_family: str = "Microsoft YaHei UI"
    font_size: int = 12
    admin_auto_elevate: bool = True
    confirm_admin_actions: bool = True
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"

    def to_dict(self) -> dict[str, Any]:
        return {
            "theme": self.theme,
            "language": self.language,
            "show_tray": self.show_tray,
            "start_minimized": self.start_minimized,
            "auto_start": self.auto_start,
            "global_hotkey": self.global_hotkey,
            "search_engine": self.search_engine,
            "grid_columns": self.grid_columns,
            "item_size": self.item_size,
            "animation_enabled": self.animation_enabled,
            "blur_background": self.blur_background,
            "accent_color": self.accent_color,
            "font_family": self.font_family,
            "font_size": self.font_size,
            "admin_auto_elevate": self.admin_auto_elevate,
            "confirm_admin_actions": self.confirm_admin_actions,
            "log_level": self.log_level,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> AppSettings:
        return cls(**{k: v for k, v in data.items() if k in cls.__annotations__})


@dataclass
class LauncherConfig:
    version: int = 1
    actions: list[Action] = field(default_factory=list)
    categories: list[Category] = field(default_factory=list)
    settings: AppSettings = field(default_factory=AppSettings)

    def to_dict(self) -> dict[str, Any]:
        return {
            "version": self.version,
            "actions": [a.to_dict() for a in self.actions],
            "categories": [c.to_dict() for c in self.categories],
            "settings": self.settings.to_dict(),
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> LauncherConfig:
        return cls(
            version=data.get("version", 1),
            actions=[Action.from_dict(a) for a in data.get("actions", [])],
            categories=[Category.from_dict(c) for c in data.get("categories", [])],
            settings=AppSettings.from_dict(data.get("settings", {})),
        )

    def get_default_categories(self) -> list[Category]:
        if not self.categories:
            self.categories = [
                Category(name="常用", icon="fa5s.star", order=0),
                Category(name="系统工具", icon="fa5s.tools", order=1),
                Category(name="开发工具", icon="fa5s.code", order=2),
                Category(name="媒体娱乐", icon="fa5s.film", order=3),
                Category(name="默认", icon="fa5s.folder", order=99),
            ]
        return self.categories