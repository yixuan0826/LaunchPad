from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal


@dataclass
class ColorPalette:
    primary: str = "#0078d4"
    primary_hover: str = "#106ebe"
    primary_pressed: str = "#005a9e"
    primary_light: str = "#e8f0fe"

    secondary: str = "#6c757d"
    secondary_hover: str = "#5a6268"
    secondary_pressed: str = "#495057"

    success: str = "#107c10"
    success_hover: str = "#0e6e0e"
    warning: str = "#ff8c00"
    warning_hover: str = "#e67e00"
    error: str = "#d13438"
    error_hover: str = "#b42b2b"

    background: str = "#ffffff"
    background_secondary: str = "#f3f2f1"
    background_tertiary: str = "#edebe9"
    background_hover: str = "#e1dfdd"
    background_pressed: str = "#d2d0ce"

    surface: str = "#ffffff"
    surface_hover: str = "#faf9f8"
    surface_pressed: str = "#f3f2f1"

    border: str = "#d2d0ce"
    border_hover: str = "#a19f9d"
    border_focus: str = "#0078d4"

    text_primary: str = "#323130"
    text_secondary: str = "#605e5c"
    text_disabled: str = "#a19f9d"
    text_on_primary: str = "#ffffff"

    shadow_ambient: str = "rgba(0, 0, 0, 0.08)"
    shadow_key: str = "rgba(0, 0, 0, 0.12)"
    shadow_spread: str = "rgba(0, 0, 0, 0.04)"

    overlay: str = "rgba(0, 0, 0, 0.4)"
    backdrop: str = "rgba(255, 255, 255, 0.8)"


@dataclass
class DarkColorPalette:
    primary: str = "#0078d4"
    primary_hover: str = "#2991e7"
    primary_pressed: str = "#0069c0"
    primary_light: str = "#1a3c5e"

    secondary: str = "#8a8886"
    secondary_hover: str = "#9b9997"
    secondary_pressed: str = "#787674"

    success: str = "#4caf50"
    success_hover: str = "#43a047"
    warning: str = "#ffb300"
    warning_hover: str = "#ffa000"
    error: str = "#ef5350"
    error_hover: str = "#e53935"

    background: str = "#1f1f1f"
    background_secondary: str = "#2d2d2d"
    background_tertiary: str = "#333333"
    background_hover: str = "#3e3e42"
    background_pressed: str = "#484644"

    surface: str = "#2d2d2d"
    surface_hover: str = "#333333"
    surface_pressed: str = "#3e3e42"

    border: str = "#3e3e42"
    border_hover: str = "#484644"
    border_focus: str = "#0078d4"

    text_primary: str = "#ffffff"
    text_secondary: str = "#b9b9b9"
    text_disabled: str = "#6a6a6a"
    text_on_primary: str = "#ffffff"

    shadow_ambient: str = "rgba(0, 0, 0, 0.3)"
    shadow_key: str = "rgba(0, 0, 0, 0.4)"
    shadow_spread: str = "rgba(0, 0, 0, 0.2)"

    overlay: str = "rgba(0, 0, 0, 0.6)"
    backdrop: str = "rgba(31, 31, 31, 0.9)"


@dataclass
class Theme:
    name: Literal["light", "dark"]
    colors: ColorPalette | DarkColorPalette
    border_radius: int = 8
    border_radius_small: int = 4
    border_radius_large: int = 12
    spacing_xs: int = 4
    spacing_sm: int = 8
    spacing_md: int = 16
    spacing_lg: int = 24
    spacing_xl: int = 32
    font_family: str = "Microsoft YaHei UI"
    font_size_sm: int = 11
    font_size_md: int = 13
    font_size_lg: int = 15
    font_size_xl: int = 20
    font_size_xxl: int = 28
    line_height: float = 1.5
    transition_fast: int = 150
    transition_normal: int = 250
    transition_slow: int = 350


LIGHT_THEME = Theme(
    name="light",
    colors=ColorPalette(),
)

DARK_THEME = Theme(
    name="dark",
    colors=DarkColorPalette(),
)


def get_theme(name: Literal["light", "dark", "system"] = "system") -> Theme:
    if name == "system":
        try:
            import darkdetect
            return DARK_THEME if darkdetect.isDark() else LIGHT_THEME
        except ImportError:
            return LIGHT_THEME
    return DARK_THEME if name == "dark" else LIGHT_THEME


def generate_stylesheet(theme: Theme) -> str:
    c = theme.colors
    return f"""
/* Base */
QWidget {{
    background-color: {c.background};
    color: {c.text_primary};
    font-family: "{theme.font_family}";
    font-size: {theme.font_size_md}px;
    line-height: {theme.line_height};
}}

/* Main Window */
MainWindow, LauncherWindow {{
    background-color: {c.background};
    border: none;
}}

/* Buttons */
RinButton, QPushButton {{
    background-color: {c.background_secondary};
    border: 1px solid {c.border};
    border-radius: {theme.border_radius}px;
    padding: {theme.spacing_xs}px {theme.spacing_md}px;
    color: {c.text_primary};
    font-size: {theme.font_size_md}px;
    min-height: 28px;
}}
RinButton:hover, QPushButton:hover {{
    background-color: {c.background_hover};
    border-color: {c.border_hover};
}}
RinButton:pressed, QPushButton:pressed {{
    background-color: {c.background_pressed};
    border-color: {c.border_hover};
}}
RinButton:disabled, QPushButton:disabled {{
    background-color: {c.background_secondary};
    border-color: {c.border};
    color: {c.text_disabled};
}}

/* Primary Button */
RinButton[primary="true"], QPushButton[primary="true"] {{
    background-color: {c.primary};
    border-color: {c.primary};
    color: {c.text_on_primary};
}}
RinButton[primary="true"]:hover, QPushButton[primary="true"]:hover {{
    background-color: {c.primary_hover};
    border-color: {c.primary_hover};
}}
RinButton[primary="true"]:pressed, QPushButton[primary="true"]:pressed {{
    background-color: {c.primary_pressed};
    border-color: {c.primary_pressed};
}}

/* Danger Button */
RinButton[danger="true"], QPushButton[danger="true"] {{
    background-color: {c.error};
    border-color: {c.error};
    color: {c.text_on_primary};
}}
RinButton[danger="true"]:hover, QPushButton[danger="true"]:hover {{
    background-color: {c.error_hover};
    border-color: {c.error_hover};
}}

/* Ghost Button */
RinButton[ghost="true"], QPushButton[ghost="true"] {{
    background-color: transparent;
    border-color: transparent;
}}
RinButton[ghost="true"]:hover, QPushButton[ghost="true"]:hover {{
    background-color: {c.background_hover};
}}
RinButton[ghost="true"]:pressed, QPushButton[ghost="true"]:pressed {{
    background-color: {c.background_pressed};
}}

/* Line Edit */
RinLineEdit, QLineEdit {{
    background-color: {c.surface};
    border: 1px solid {c.border};
    border-radius: {theme.border_radius}px;
    padding: {theme.spacing_xs}px {theme.spacing_sm}px;
    color: {c.text_primary};
    font-size: {theme.font_size_md}px;
    min-height: 28px;
}}
RinLineEdit:focus, QLineEdit:focus {{
    border-color: {c.border_focus};
    background-color: {c.surface};
}}
RinLineEdit:disabled, QLineEdit:disabled {{
    background-color: {c.background_secondary};
    border-color: {c.border};
    color: {c.text_disabled};
}}

/* ComboBox */
RinComboBox, QComboBox {{
    background-color: {c.surface};
    border: 1px solid {c.border};
    border-radius: {theme.border_radius}px;
    padding: {theme.spacing_xs}px {theme.spacing_sm}px;
    color: {c.text_primary};
    font-size: {theme.font_size_md}px;
    min-height: 28px;
}}
RinComboBox:hover, QComboBox:hover {{
    border-color: {c.border_hover};
}}
RinComboBox:focus, QComboBox:focus {{
    border-color: {c.border_focus};
}}
RinComboBox::drop-down, QComboBox::drop-down {{
    border: none;
    width: 24px;
}}
RinComboBox::down-arrow, QComboBox::down-arrow {{
    image: none;
    border-left: 5px solid transparent;
    border-right: 5px solid transparent;
    border-top: 5px solid {c.text_primary};
    margin-right: 8px;
}}

/* ListView / TreeView */
RinListView, QListView, RinTreeView, QTreeView {{
    background-color: {c.surface};
    border: 1px solid {c.border};
    border-radius: {theme.border_radius}px;
    outline: none;
}}
RinListView::item, QListView::item, RinTreeView::item, QTreeView::item {{
    padding: {theme.spacing_xs}px {theme.spacing_sm}px;
    border-radius: {theme.border_radius_small}px;
    margin: 1px;
}}
RinListView::item:selected, QListView::item:selected, 
RinTreeView::item:selected, QTreeView::item:selected {{
    background-color: {c.primary_light};
    color: {c.primary};
}}
RinListView::item:hover, QListView::item:hover,
RinTreeView::item:hover, QTreeView::item:hover {{
    background-color: {c.background_hover};
}}

/* ScrollBar */
QScrollBar:vertical {{
    background-color: transparent;
    width: 8px;
    margin: 0;
}}
QScrollBar::handle:vertical {{
    background-color: {c.border_hover};
    border-radius: 4px;
    min-height: 30px;
}}
QScrollBar::handle:vertical:hover {{
    background-color: {c.text_disabled};
}}
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{
    height: 0;
}}
QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {{
    background: none;
}}
QScrollBar:horizontal {{
    background-color: transparent;
    height: 8px;
    margin: 0;
}}
QScrollBar::handle:horizontal {{
    background-color: {c.border_hover};
    border-radius: 4px;
    min-width: 30px;
}}
QScrollBar::handle:horizontal:hover {{
    background-color: {c.text_disabled};
}}
QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal {{
    width: 0;
}}

/* ToolTip */
QToolTip {{
    background-color: {c.background_tertiary};
    border: 1px solid {c.border};
    border-radius: {theme.border_radius_small}px;
    padding: {theme.spacing_xs}px {theme.spacing_sm}px;
    color: {c.text_primary};
    font-size: {theme.font_size_sm}px;
}}

/* Menu */
QMenu {{
    background-color: {c.surface};
    border: 1px solid {c.border};
    border-radius: {theme.border_radius}px;
    padding: {theme.spacing_xs}px 0;
}}
QMenu::item {{
    padding: {theme.spacing_xs}px {theme.spacing_md}px;
    color: {c.text_primary};
}}
QMenu::item:selected {{
    background-color: {c.background_hover};
}}
QMenu::separator {{
    height: 1px;
    background-color: {c.border};
    margin: {theme.spacing_xs}px {theme.spacing_sm}px;
}}

/* CheckBox / RadioButton */
QCheckBox, QRadioButton {{
    spacing: {theme.spacing_xs}px;
    color: {c.text_primary};
}}
QCheckBox::indicator, QRadioButton::indicator {{
    width: 18px;
    height: 18px;
    border-radius: {theme.border_radius_small}px;
    border: 1px solid {c.border};
    background-color: {c.surface};
}}
QCheckBox::indicator:checked, QRadioButton::indicator:checked {{
    background-color: {c.primary};
    border-color: {c.primary};
}}
QCheckBox::indicator:hover, QRadioButton::indicator:hover {{
    border-color: {c.border_hover};
}}

/* Slider */
QSlider::groove:horizontal {{
    height: 4px;
    background-color: {c.background_tertiary};
    border-radius: 2px;
}}
QSlider::handle:horizontal {{
    width: 16px;
    height: 16px;
    margin: -6px 0;
    background-color: {c.primary};
    border-radius: 8px;
}}
QSlider::handle:horizontal:hover {{
    background-color: {c.primary_hover};
}}
QSlider::sub-page:horizontal {{
    background-color: {c.primary};
    border-radius: 2px;
}}

/* TabWidget */
QTabWidget::pane {{
    border: 1px solid {c.border};
    border-radius: {theme.border_radius}px;
    background-color: {c.surface};
    margin-top: -1px;
}}
QTabBar::tab {{
    background-color: transparent;
    border: none;
    padding: {theme.spacing_xs}px {theme.spacing_md}px;
    margin-right: 2px;
    border-top-left-radius: {theme.border_radius_small}px;
    border-top-right-radius: {theme.border_radius_small}px;
    color: {c.text_secondary};
}}
QTabBar::tab:selected {{
    background-color: {c.surface};
    color: {c.text_primary};
    border-bottom: 2px solid {c.primary};
}}
QTabBar::tab:hover:!selected {{
    background-color: {c.background_hover};
    color: {c.text_primary};
}}

/* GroupBox */
QGroupBox {{
    border: 1px solid {c.border};
    border-radius: {theme.border_radius}px;
    margin-top: {theme.spacing_md}px;
    padding-top: {theme.spacing_md}px;
    color: {c.text_primary};
    font-weight: bold;
}}
QGroupBox::title {{
    subcontrol-origin: margin;
    left: {theme.spacing_md}px;
    padding: 0 {theme.spacing_xs}px;
    color: {c.text_secondary};
}}

/* Splitter */
QSplitter::handle {{
    background-color: {c.border};
}}
QSplitter::handle:horizontal {{
    width: 1px;
}}
QSplitter::handle:vertical {{
    height: 1px;
}}

/* Card / Action Item */
RinActionCard {{
    background-color: {c.surface};
    border: 1px solid {c.border};
    border-radius: {theme.border_radius_large}px;
}}
RinActionCard:hover {{
    background-color: {c.surface_hover};
    border-color: {c.border_hover};
}}
RinActionCard:focus {{
    border-color: {c.border_focus};
    outline: none;
}}

/* Category Header */
RinCategoryHeader {{
    color: {c.text_secondary};
    font-weight: 600;
    font-size: {theme.font_size_sm}px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}}

/* Search Bar */
RinSearchBar {{
    background-color: {c.surface};
    border: 1px solid {c.border};
    border-radius: {theme.border_radius_large}px;
    padding: 0 {theme.spacing_md}px;
}}
RinSearchBar:focus-within {{
    border-color: {c.border_focus};
    background-color: {c.surface};
}}

/* Settings Panel */
RinSettingsPanel {{
    background-color: {c.background};
    border: none;
}}
RinSettingsSection {{
    background-color: {c.surface};
    border: 1px solid {c.border};
    border-radius: {theme.border_radius_large}px;
    margin-bottom: {theme.spacing_md}px;
}}

/* Dialog */
RinDialog, QDialog {{
    background-color: {c.background};
    border: 1px solid {c.border};
    border-radius: {theme.border_radius_large}px;
}}

/* Toast / Notification */
RinToast {{
    background-color: {c.background_tertiary};
    border: 1px solid {c.border};
    border-radius: {theme.border_radius}px;
    padding: {theme.spacing_sm}px {theme.spacing_md}px;
    color: {c.text_primary};
}}

/* Icon Button */
RinIconButton {{
    background-color: transparent;
    border: none;
    border-radius: {theme.border_radius_small}px;
    padding: {theme.spacing_xs}px;
    color: {c.text_secondary};
}}
RinIconButton:hover {{
    background-color: {c.background_hover};
    color: {c.text_primary};
}}
RinIconButton:pressed {{
    background-color: {c.background_pressed};
}}

/* Badge */
RinBadge {{
    background-color: {c.primary};
    color: {c.text_on_primary};
    border-radius: {theme.border_radius_small}px;
    padding: 0 {theme.spacing_xs}px;
    font-size: {theme.font_size_sm}px;
    font-weight: 600;
}}
"""


class ThemeManager:
    _instance: ThemeManager | None = None
    _theme: Theme = LIGHT_THEME
    _callbacks: list[callable] = []

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    @property
    def theme(self) -> Theme:
        return self._theme

    def set_theme(self, name: Literal["light", "dark", "system"]):
        new_theme = get_theme(name)
        if new_theme.name != self._theme.name:
            self._theme = new_theme
            self._notify()

    def _notify(self):
        for cb in self._callbacks:
            try:
                cb(self._theme)
            except Exception:
                pass

    def register(self, callback: callable):
        if callback not in self._callbacks:
            self._callbacks.append(callback)

    def unregister(self, callback: callable):
        if callback in self._callbacks:
            self._callbacks.remove(callback)

    def stylesheet(self) -> str:
        return generate_stylesheet(self._theme)