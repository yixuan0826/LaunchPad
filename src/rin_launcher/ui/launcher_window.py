from __future__ import annotations

import os
import sys
from typing import Optional

from PySide6.QtCore import Qt, QRect, QSize, QPoint, QTimer, Signal, QPropertyAnimation, QEasingCurve, QEvent, QSettings
from PySide6.QtGui import QFont, QIcon, QPixmap, QPainter, QColor, QBrush, QPen, QCursor, QAction, QKeySequence, QShortcut, QGuiApplication
from PySide6.QtWidgets import (
    QWidget, QMainWindow, QVBoxLayout, QHBoxLayout, QLabel, QFrame,
    QSizePolicy, QSpacerItem, QGraphicsDropShadowEffect, QScrollArea,
    QApplication, QStyle, QMenu, QSystemTrayIcon, QMessageBox
)

from ..core.models import Action, ActionType, Category, RunAs
from ..core.config_manager import ConfigManager
from .theme import ThemeManager, get_theme
from .components import (
    RinButton, RinIconButton, RinLineEdit, RinSearchBar,
    RinCard, RinActionCard, RinCategoryHeader, RinSettingsSection,
    RinSwitch, RinDialog, RinToast, RinIconPicker, RinHotkeyEdit,
    RinFilePicker, RinColorPicker
)
from .theme import ThemeManager


class LauncherWindow(QMainWindow):
    def __init__(self, config_manager: ConfigManager):
        super().__init__()
        self.config_manager = config_manager
        self.theme_manager = ThemeManager()

        self.setWindowTitle("Rin Launcher")
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.Tool |
            Qt.WindowType.WindowStaysOnTopHint
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating)

        self._setup_ui()
        self._setup_shortcuts()
        self._setup_tray()
        self._apply_theme()
        self._load_config()

        self._animating = False
        self._visible = False

    def _setup_ui(self):
        self._central = QWidget()
        self._central.setObjectName("LauncherCentral")
        self._central.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)

        shadow = QGraphicsDropShadowEffect(self._central)
        shadow.setBlurRadius(40)
        shadow.setOffset(0, 8)
        shadow.setColor(QColor(0, 0, 0, 60))
        self._central.setGraphicsEffect(shadow)

        self.setCentralWidget(self._central)

        central_layout = QVBoxLayout(self._central)
        central_layout.setContentsMargins(24, 24, 24, 24)
        central_layout.setSpacing(16)

        # Search bar
        self._search_bar = RinSearchBar(
            placeholder="搜索应用、文件、命令... (Ctrl+Space)",
            on_search=self._on_search
        )
        self._search_bar.setFixedHeight(56)
        central_layout.addWidget(self._search_bar)

        # Categories and actions area
        self._scroll_area = QScrollArea()
        self._scroll_area.setWidgetResizable(True)
        self._scroll_area.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self._scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self._scroll_area.setFrameShape(QFrame.Shape.NoFrame)
        self._scroll_area.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self._scroll_area.viewport().setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)

        self._content_widget = QWidget()
        self._content_widget.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self._content_layout = QVBoxLayout(self._content_widget)
        self._content_layout.setContentsMargins(0, 0, 0, 0)
        self._content_layout.setSpacing(16)
        self._content_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

        self._scroll_area.setWidget(self._content_widget)
        central_layout.addWidget(self._scroll_area, 1)

        # Footer with settings button
        footer_layout = QHBoxLayout()
        footer_layout.setContentsMargins(0, 8, 0, 0)

        self._settings_btn = RinIconButton(icon_name="fa5s.cog", size=20)
        self._settings_btn.setFixedSize(40, 40)
        self._settings_btn.setToolTip("设置")
        self._settings_btn.clicked.connect(self._show_settings)

        footer_layout.addStretch()
        footer_layout.addWidget(self._settings_btn)
        central_layout.addLayout(footer_layout)

        # Set minimum size
        self.setMinimumSize(640, 480)
        self.resize(800, 600)

    def _setup_shortcuts(self):
        settings = self.config_manager.config.settings
        hotkey = settings.global_hotkey or "ctrl+space"

        # Parse hotkey
        modifiers = Qt.KeyboardModifier.NoModifier
        key = Qt.Key.Key_Space

        parts = hotkey.lower().replace(" ", "").split("+")
        for part in parts:
            if part in ("ctrl", "control"):
                modifiers |= Qt.KeyboardModifier.ControlModifier
            elif part in ("alt", "option"):
                modifiers |= Qt.KeyboardModifier.AltModifier
            elif part in ("shift",):
                modifiers |= Qt.KeyboardModifier.ShiftModifier
            elif part in ("win", "meta", "super", "cmd"):
                modifiers |= Qt.KeyboardModifier.MetaModifier
            elif part == "space":
                key = Qt.Key.Key_Space
            elif part == "enter":
                key = Qt.Key.Key_Return
            elif part == "esc":
                key = Qt.Key.Key_Escape
            elif part == "tab":
                key = Qt.Key.Key_Tab
            elif len(part) == 1 and part.isalpha():
                key = getattr(Qt.Key, f"Key_{part.upper()}", Qt.Key.Key_Space)
            elif part.startswith("f") and part[1:].isdigit():
                key = getattr(Qt.Key, f"Key_F{part[1:]}", Qt.Key.Key_Space)

        self._global_shortcut = QShortcut(QKeySequence(modifiers | key), self)
        self._global_shortcut.setContext(Qt.ShortcutContext.ApplicationShortcut)
        self._global_shortcut.activated.connect(self.toggle_visibility)

        # Escape to close
        self._escape_shortcut = QShortcut(QKeySequence(Qt.Key.Key_Escape), self)
        self._escape_shortcut.setContext(Qt.ShortcutContext.WidgetShortcut)
        self._escape_shortcut.activated.connect(self.hide_launcher)

    def _setup_tray(self):
        settings = self.config_manager.config.settings
        if not settings.show_tray:
            return

        try:
            import qtawesome as qta
            icon = qta.icon("fa5s.rocket", color="#0078d4")
        except ImportError:
            icon = QIcon()

        self._tray_icon = QSystemTrayIcon(icon, self)
        self._tray_icon.setToolTip("Rin Launcher")

        tray_menu = QMenu()
        show_action = tray_menu.addAction("显示启动台")
        show_action.triggered.connect(self.show_launcher)

        tray_menu.addSeparator()

        settings_action = tray_menu.addAction("设置")
        settings_action.triggered.connect(self._show_settings)

        tray_menu.addSeparator()

        quit_action = tray_menu.addAction("退出")
        quit_action.triggered.connect(QApplication.instance().quit)

        self._tray_icon.setContextMenu(tray_menu)
        self._tray_icon.activated.connect(self._on_tray_activated)
        self._tray_icon.show()

    def _apply_theme(self):
        theme = self.theme_manager.theme
        self.setStyleSheet(self.theme_manager.stylesheet())
        self._central.setStyleSheet(f"""
            #LauncherCentral {{
                background-color: {theme.colors.surface};
                border-radius: {theme.border_radius_large}px;
                border: 1px solid {theme.colors.border};
            }}
        """)

    def _load_config(self):
        self._render_actions()

    def _render_actions(self):
        # Clear existing
        while self._content_layout.count():
            item = self._content_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
            elif item.layout():
                self._clear_layout(item.layout())

        config = self.config_manager.config
        categories = config.categories
        actions = config.actions

        # Group actions by category
        actions_by_cat = {}
        for action in actions:
            if not action.enabled:
                continue
            cat = action.category
            if cat not in actions_by_cat:
                actions_by_cat[cat] = []
            actions_by_cat[cat].append(action)

        # Sort categories by order
        categories.sort(key=lambda c: c.order)

        for category in categories:
            cat_actions = actions_by_cat.get(category.name, [])
            if not cat_actions and category.name != "默认":
                continue

            # Category header
            header = RinCategoryHeader(category.name, category.icon, category.expanded)
            header._expand_btn.clicked.connect(
                lambda checked, c=category: self._toggle_category(c)
            )
            self._content_layout.addWidget(header)

            # Actions container
            if category.expanded or not cat_actions:
                container = QWidget()
                container.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
                grid_layout = QVBoxLayout(container)
                grid_layout.setContentsMargins(8, 4, 8, 4)
                grid_layout.setSpacing(8)

                # Grid layout for actions
                settings = config.settings
                cols = settings.grid_columns
                item_size = settings.item_size

                row_layout = None
                for i, action in enumerate(sorted(cat_actions, key=lambda a: a.order)):
                    if i % cols == 0:
                        row_layout = QHBoxLayout()
                        row_layout.setSpacing(8)
                        grid_layout.addLayout(row_layout)

                    card = RinActionCard(
                        action_id=action.id,
                        name=action.name,
                        icon_name=action.icon,
                        category=action.category,
                        hotkey=action.hotkey
                    )
                    card.setFixedSize(item_size, item_size)
                    card.clicked.connect(lambda _, a=action: self._execute_action(a))
                    card.context_menu_requested.connect(self._show_action_context_menu)
                    row_layout.addWidget(card)

                if row_layout:
                    row_layout.addStretch()

                self._content_layout.addWidget(container)
                category._container = container
            else:
                category._container = None

        self._content_layout.addStretch()

    def _clear_layout(self, layout):
        while layout.count():
            item = layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
            elif item.layout():
                self._clear_layout(item.layout())

    def _toggle_category(self, category: Category):
        category.expanded = not category.expanded
        self.config_manager.update_category(category)
        self._render_actions()

    def _on_search(self, query: str):
        if not query.strip():
            self._render_actions()
            return

        results = self.config_manager.search_actions(query)

        # Clear and show results
        while self._content_layout.count():
            item = self._content_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
            elif item.layout():
                self._clear_layout(item.layout())

        if results:
            header = RinCategoryHeader(f"搜索结果 ({len(results)})", "fa5s.search", True)
            self._content_layout.addWidget(header)

            container = QWidget()
            container.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
            grid_layout = QVBoxLayout(container)
            grid_layout.setContentsMargins(8, 4, 8, 4)
            grid_layout.setSpacing(8)

            settings = self.config_manager.config.settings
            cols = settings.grid_columns
            item_size = settings.item_size

            row_layout = None
            for i, action in enumerate(results):
                if i % cols == 0:
                    row_layout = QHBoxLayout()
                    row_layout.setSpacing(8)
                    grid_layout.addLayout(row_layout)

                card = RinActionCard(
                    action_id=action.id,
                    name=action.name,
                    icon_name=action.icon,
                    category=action.category,
                    hotkey=action.hotkey
                )
                card.setFixedSize(item_size, item_size)
                card.clicked.connect(lambda _, a=action: self._execute_action(a))
                card.context_menu_requested.connect(self._show_action_context_menu)
                row_layout.addWidget(card)

            if row_layout:
                row_layout.addStretch()

            self._content_layout.addWidget(container)
        else:
            # No results
            no_results = QLabel("未找到匹配的操作")
            no_results.setAlignment(Qt.AlignmentFlag.AlignCenter)
            no_results.setStyleSheet("color: #a19f9d; padding: 40px; font-size: 14px;")
            self._content_layout.addWidget(no_results)

        self._content_layout.addStretch()

    def _execute_action(self, action: Action):
        from ..actions.executor import ActionExecutor
        executor = ActionExecutor(self.config_manager)
        executor.execute(action)
        self.hide_launcher()

    def _show_action_context_menu(self, pos: QPoint):
        # Find the action card at position
        sender = self.sender()
        if not isinstance(sender, RinActionCard):
            return

        action = next((a for a in self.config_manager.config.actions if a.id == sender.action_id), None)
        if not action:
            return

        menu = QMenu(self)
        edit_action = menu.addAction("编辑")
        edit_action.triggered.connect(lambda: self._edit_action(action))

        duplicate_action = menu.addAction("复制")
        duplicate_action.triggered.connect(lambda: self._duplicate_action(action))

        delete_action = menu.addAction("删除")
        delete_action.triggered.connect(lambda: self._delete_action(action))

        menu.exec(pos)

    def _edit_action(self, action: Action):
        from .action_editor import ActionEditorDialog
        dialog = ActionEditorDialog(self.config_manager, action, self)
        if dialog.exec():
            self._render_actions()

    def _duplicate_action(self, action: Action):
        import uuid
        new_action = Action(
            id=uuid.uuid4().hex[:8],
            name=f"{action.name} (副本)",
            icon=action.icon,
            type=action.type,
            target=action.target,
            arguments=action.arguments,
            working_dir=action.working_dir,
            run_as=action.run_as,
            keymouse_steps=action.keymouse_steps,
            category=action.category,
            enabled=action.enabled,
            hotkey="",
            tooltip=action.tooltip,
            order=action.order + 1
        )
        self.config_manager.add_action(new_action)
        self._render_actions()

    def _delete_action(self, action: Action):
        reply = QMessageBox.question(
            self, "确认删除",
            f"确定要删除操作 \"{action.name}\" 吗？",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        if reply == QMessageBox.StandardButton.Yes:
            self.config_manager.delete_action(action.id)
            self._render_actions()

    def _show_settings(self):
        from .settings_dialog import SettingsDialog
        dialog = SettingsDialog(self.config_manager, self)
        dialog.exec()
        self._apply_theme()
        self._render_actions()

    def _on_tray_activated(self, reason):
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            self.toggle_visibility()

    def show_launcher(self):
        if self._visible:
            return

        self._visible = True
        self._search_bar.clear()
        self._search_bar.setFocus()
        self._position_window()
        self.show()
        self.raise_()
        self.activateWindow()

    def hide_launcher(self):
        if not self._visible:
            return
        self._visible = False
        self.hide()

    def toggle_visibility(self):
        if self._visible:
            self.hide_launcher()
        else:
            self.show_launcher()

    def _position_window(self):
        screen = QGuiApplication.primaryScreen()
        if screen:
            geometry = screen.availableGeometry()
            x = (geometry.width() - self.width()) // 2
            y = (geometry.height() - self.height()) // 3
            self.move(x, y)

    def closeEvent(self, event):
        if self.config_manager.config.settings.show_tray:
            event.ignore()
            self.hide_launcher()
        else:
            event.accept()

    def changeEvent(self, event):
        if event.type() == QEvent.Type.WindowStateChange:
            if self.isMinimized():
                event.ignore()
                self.hide_launcher()
        super().changeEvent(event)


def main():
    import logging
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    )

    app = QApplication(sys.argv)
    app.setApplicationName("Rin Launcher")
    app.setApplicationVersion("1.0.0")
    app.setQuitOnLastWindowClosed(False)

    # High DPI
    QGuiApplication.setHighDpiScaleFactorRoundingPolicy(
        Qt.HighDpiScaleFactorRoundingPolicy.PassThrough
    )

    config_manager = ConfigManager()
    window = LauncherWindow(config_manager)

    # Start with launcher hidden
    window.hide_launcher()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()