from __future__ import annotations

import enum
from typing import Callable, Optional

from PySide6.QtCore import Qt, QRect, QSize, QPoint, QTimer, Signal, QPropertyAnimation, QEasingCurve, Property
from PySide6.QtGui import QFont, QIcon, QPixmap, QPainter, QColor, QBrush, QPen, QCursor, QAction
from PySide6.QtWidgets import (
    QWidget, QPushButton, QLineEdit, QComboBox, QListView, QTreeView,
    QVBoxLayout, QHBoxLayout, QLabel, QFrame, QSizePolicy, QSpacerItem,
    QGraphicsDropShadowEffect, QToolTip, QMenu, QCheckBox, QRadioButton,
    QSlider, QTabWidget, QGroupBox, QSplitter, QScrollArea, QDialog,
    QDialogButtonBox, QFormLayout, QFileDialog, QMessageBox, QStyle,
    QStyledItemDelegate, QStyleOptionViewItem, QApplication, QWidgetAction
)

from .theme import ThemeManager, Theme


class RinButton(QPushButton):
    class Style(enum.Enum):
        PRIMARY = "primary"
        SECONDARY = "secondary"
        GHOST = "ghost"
        DANGER = "danger"

    def __init__(
        self,
        text: str = "",
        icon: Optional[QIcon] = None,
        icon_name: str = "",
        style: Style = Style.SECONDARY,
        parent: Optional[QWidget] = None
    ):
        super().__init__(text, parent)
        self._style = style
        self._animating = False
        self._hover_progress = 0.0
        self._press_progress = 0.0

        if icon_name:
            try:
                import qtawesome as qta
                self.setIcon(qta.icon(icon_name, color="#0078d4" if style == RinButton.Style.PRIMARY else "#605e5c"))
            except ImportError:
                pass
        elif icon:
            self.setIcon(icon)

        self.setCursor(QCursor(Qt.CursorShape.PointingHandCursor))
        self.setProperty("primary", style == RinButton.Style.PRIMARY)
        self.setProperty("danger", style == RinButton.Style.DANGER)
        self.setProperty("ghost", style == RinButton.Style.GHOST)

        self._setup_animation()

    def _setup_animation(self):
        self._hover_anim = QPropertyAnimation(self, b"hover_progress", self)
        self._hover_anim.setDuration(150)
        self._hover_anim.setEasingCurve(QEasingCurve.Type.OutCubic)

        self._press_anim = QPropertyAnimation(self, b"press_progress", self)
        self._press_anim.setDuration(100)
        self._press_anim.setEasingCurve(QEasingCurve.Type.OutCubic)

    def get_hover_progress(self) -> float:
        return self._hover_progress

    def set_hover_progress(self, value: float):
        self._hover_progress = value
        self.update()

    def get_press_progress(self) -> float:
        return self._press_progress

    def set_press_progress(self, value: float):
        self._press_progress = value
        self.update()

    hover_progress = Property(float, get_hover_progress, set_hover_progress)
    press_progress = Property(float, get_press_progress, set_press_progress)

    def enterEvent(self, event):
        self._hover_anim.setStartValue(self._hover_progress)
        self._hover_anim.setEndValue(1.0)
        self._hover_anim.start()
        super().enterEvent(event)

    def leaveEvent(self, event):
        self._hover_anim.setStartValue(self._hover_progress)
        self._hover_anim.setEndValue(0.0)
        self._hover_anim.start()
        super().leaveEvent(event)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self._press_anim.setStartValue(self._press_progress)
            self._press_anim.setEndValue(1.0)
            self._press_anim.start()
        super().mousePressEvent(event)

    def mouseReleaseEvent(self, event):
        self._press_anim.setStartValue(self._press_progress)
        self._press_anim.setEndValue(0.0)
        self._press_anim.start()
        super().mouseReleaseEvent(event)


class RinIconButton(RinButton):
    def __init__(
        self,
        icon: Optional[QIcon] = None,
        icon_name: str = "",
        size: int = 24,
        parent: Optional[QWidget] = None
    ):
        super().__init__("", style=RinButton.Style.GHOST, parent=parent)
        self.setFixedSize(size + 16, size + 16)
        self.setIconSize(QSize(size, size))

        if icon_name:
            try:
                import qtawesome as qta
                self.setIcon(qta.icon(icon_name, color="#605e5c"))
            except ImportError:
                pass
        elif icon:
            self.setIcon(icon)


class RinLineEdit(QLineEdit):
    def __init__(
        self,
        placeholder: str = "",
        parent: Optional[QWidget] = None,
        clearable: bool = True
    ):
        super().__init__(parent)
        self.setPlaceholderText(placeholder)
        self.setClearButtonEnabled(clearable)
        self.setAttribute(Qt.WidgetAttribute.WA_MacShowFocusRect, False)

        self._icon_label: Optional[QLabel] = None
        self._trailing_widget: Optional[QWidget] = None

    def set_leading_icon(self, icon_name: str, color: str = "#605e5c"):
        try:
            import qtawesome as qta
            icon = qta.icon(icon_name, color=color)
            if self._icon_label is None:
                self._icon_label = QLabel(self)
                self._icon_label.setFixedSize(24, 24)
                self._icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
                self.setTextMargins(32, 0, 0, 0)
            self._icon_label.setPixmap(icon.pixmap(20, 20))
        except ImportError:
            pass

    def set_trailing_widget(self, widget: QWidget):
        if self._trailing_widget:
            self._trailing_widget.deleteLater()
        self._trailing_widget = widget
        widget.setParent(self)
        self.update_trailing_position()

    def update_trailing_position(self):
        if self._trailing_widget:
            self._trailing_widget.move(
                self.width() - self._trailing_widget.width() - 8,
                (self.height() - self._trailing_widget.height()) // 2
            )

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self.update_trailing_position()
        if self._icon_label:
            self._icon_label.move(8, (self.height() - 24) // 2)


class RinSearchBar(RinLineEdit):
    def __init__(
        self,
        placeholder: str = "搜索应用、文件、命令... (Ctrl+Space)",
        parent: Optional[QWidget] = None,
        on_search: Optional[Callable[[str], None]] = None
    ):
        super().__init__(placeholder, parent, clearable=True)
        self._on_search = on_search
        self.set_leading_icon("fa5s.search")
        self.setMinimumHeight(44)
        self.setFont(QFont("Microsoft YaHei UI", 13))
        self.textChanged.connect(self._on_text_changed)
        self.returnPressed.connect(self._on_return_pressed)

        self._clear_btn = RinIconButton(icon_name="fa5s.times", size=16)
        self._clear_btn.clicked.connect(self.clear)
        self._clear_btn.hide()
        self.set_trailing_widget(self._clear_btn)

    def _on_text_changed(self, text: str):
        self._clear_btn.setVisible(bool(text))
        if self._on_search:
            self._on_search(text)

    def _on_return_pressed(self):
        if self.text().strip():
            self._clear_btn.click()


class RinComboBox(QComboBox):
    def __init__(self, parent: Optional[QWidget] = None):
        super().__init__(parent)
        self.setCursor(QCursor(Qt.CursorShape.PointingHandCursor))
        self.view().setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)


class RinCard(QFrame):
    clicked = Signal()
    double_clicked = Signal()

    def __init__(
        self,
        title: str = "",
        subtitle: str = "",
        icon: Optional[QIcon] = None,
        icon_name: str = "",
        parent: Optional[QWidget] = None
    ):
        super().__init__(parent)
        self.setObjectName("RinActionCard")
        self.setCursor(QCursor(Qt.CursorShape.PointingHandCursor))
        self.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 16, 16, 16)
        layout.setSpacing(8)

        if icon_name:
            try:
                import qtawesome as qta
                icon = qta.icon(icon_name, color="#0078d4")
            except ImportError:
                icon = None

        self._icon_label = QLabel()
        self._icon_label.setFixedSize(32, 32)
        self._icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        if icon:
            self._icon_label.setPixmap(icon.pixmap(28, 28))

        self._title_label = QLabel(title)
        self._title_label.setFont(QFont("Microsoft YaHei UI", 12, QFont.Weight.DemiBold))
        self._title_label.setWordWrap(True)

        self._subtitle_label = QLabel(subtitle)
        self._subtitle_label.setFont(QFont("Microsoft YaHei UI", 10))
        self._subtitle_label.setStyleSheet("color: #605e5c;")
        self._subtitle_label.setWordWrap(True)

        layout.addWidget(self._icon_label, 0, Qt.AlignmentFlag.AlignHCenter)
        layout.addWidget(self._title_label, 0, Qt.AlignmentFlag.AlignHCenter)
        if subtitle:
            layout.addWidget(self._subtitle_label, 0, Qt.AlignmentFlag.AlignHCenter)

        self._shadow = QGraphicsDropShadowEffect(self)
        self._shadow.setBlurRadius(20)
        self._shadow.setOffset(0, 4)
        self._shadow.setColor(QColor(0, 0, 0, 30))
        self.setGraphicsEffect(self._shadow)

    def set_icon(self, icon: QIcon):
        self._icon_label.setPixmap(icon.pixmap(28, 28))

    def set_title(self, title: str):
        self._title_label.setText(title)

    def set_subtitle(self, subtitle: str):
        self._subtitle_label.setText(subtitle)
        self._subtitle_label.setVisible(bool(subtitle))

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self._shadow.setBlurRadius(10)
            self._shadow.setOffset(0, 2)
        super().mousePressEvent(event)

    def mouseReleaseEvent(self, event):
        self._shadow.setBlurRadius(20)
        self._shadow.setOffset(0, 4)
        if self.rect().contains(event.pos()):
            self.clicked.emit()
        super().mouseReleaseEvent(event)

    def mouseDoubleClickEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.double_clicked.emit()
        super().mouseDoubleClickEvent(event)

    def enterEvent(self, event):
        self._shadow.setBlurRadius(30)
        self._shadow.setOffset(0, 8)
        super().enterEvent(event)

    def leaveEvent(self, event):
        self._shadow.setBlurRadius(20)
        self._shadow.setOffset(0, 4)
        super().leaveEvent(event)


class RinActionCard(RinCard):
    context_menu_requested = Signal(QPoint)

    def __init__(
        self,
        action_id: str,
        name: str,
        icon_name: str = "fa5s.rocket",
        category: str = "",
        hotkey: str = "",
        parent: Optional[QWidget] = None
    ):
        super().__init__(title=name, icon_name=icon_name, parent=parent)
        self.action_id = action_id
        self._hotkey = hotkey
        self._category = category

        self._hotkey_label = QLabel(hotkey)
        self._hotkey_label.setFont(QFont("Consolas", 8))
        self._hotkey_label.setStyleSheet("color: #a19f9d; padding: 2px 6px; background: #f3f2f1; border-radius: 3px;")
        self._hotkey_label.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        self._hotkey_label.setVisible(bool(hotkey))

        layout = self.layout()
        layout.addSpacing(4)
        layout.addWidget(self._hotkey_label, 0, Qt.AlignmentFlag.AlignRight)

        self.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.customContextMenuRequested.connect(self._show_context_menu)

    def _show_context_menu(self, pos: QPoint):
        self.context_menu_requested.emit(self.mapToGlobal(pos))

    def set_hotkey(self, hotkey: str):
        self._hotkey = hotkey
        self._hotkey_label.setText(hotkey)
        self._hotkey_label.setVisible(bool(hotkey))


class RinCategoryHeader(QFrame):
    def __init__(self, name: str, icon_name: str = "fa5s.folder", expanded: bool = True, parent: Optional[QWidget] = None):
        super().__init__(parent)
        self.setObjectName("RinCategoryHeader")
        self.setFixedHeight(32)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(8, 0, 8, 0)
        layout.setSpacing(8)

        try:
            import qtawesome as qta
            icon = qta.icon(icon_name, color="#605e5c")
            self._icon_label = QLabel()
            self._icon_label.setFixedSize(16, 16)
            self._icon_label.setPixmap(icon.pixmap(16, 16))
        except ImportError:
            self._icon_label = QLabel()

        self._expand_btn = RinIconButton(icon_name="fa5s.chevron-down" if expanded else "fa5s.chevron-right", size=12)
        self._expand_btn.setFixedSize(24, 24)

        self._name_label = QLabel(name)
        self._name_label.setFont(QFont("Microsoft YaHei UI", 10, QFont.Weight.DemiBold))
        self._name_label.setStyleSheet("color: #605e5c; text-transform: uppercase; letter-spacing: 0.5px;")

        layout.addWidget(self._icon_label)
        layout.addWidget(self._expand_btn)
        layout.addWidget(self._name_label)
        layout.addStretch()

    def set_expanded(self, expanded: bool):
        try:
            import qtawesome as qta
            self._expand_btn.setIcon(qta.icon("fa5s.chevron-down" if expanded else "fa5s.chevron-right", color="#605e5c"))
        except ImportError:
            pass


class RinSettingsSection(QGroupBox):
    def __init__(self, title: str, icon_name: str = "", parent: Optional[QWidget] = None):
        super().__init__(title, parent)
        self.setObjectName("RinSettingsSection")
        self.setFont(QFont("Microsoft YaHei UI", 11, QFont.Weight.DemiBold))

        self._main_layout = QVBoxLayout(self)
        self._main_layout.setContentsMargins(20, 24, 20, 16)
        self._main_layout.setSpacing(16)

        if icon_name:
            try:
                import qtawesome as qta
                self._icon_label = QLabel()
                self._icon_label.setPixmap(qta.icon(icon_name, color="#0078d4").pixmap(20, 20))
            except ImportError:
                pass

    def add_widget(self, widget: QWidget):
        self._main_layout.addWidget(widget)

    def add_layout(self, layout):
        self._main_layout.addLayout(layout)

    def add_spacing(self, spacing: int):
        self._main_layout.addSpacing(spacing)


class RinSwitch(QCheckBox):
    def __init__(self, text: str = "", parent: Optional[QWidget] = None):
        super().__init__(text, parent)
        self.setCursor(QCursor(Qt.CursorShape.PointingHandCursor))
        self.setFixedHeight(28)


class RinDialog(QDialog):
    def __init__(self, title: str = "", parent: Optional[QWidget] = None, modal: bool = True):
        super().__init__(parent)
        self.setObjectName("RinDialog")
        self.setWindowTitle(title)
        self.setModal(modal)
        self.setWindowFlags(Qt.WindowType.Dialog | Qt.WindowType.FramelessWindowHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setMinimumWidth(480)

        self._content = QFrame()
        self._content.setObjectName("RinDialogContent")
        self._content.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)

        shadow = QGraphicsDropShadowEffect(self._content)
        shadow.setBlurRadius(40)
        shadow.setOffset(0, 8)
        shadow.setColor(QColor(0, 0, 0, 60))
        self._content.setGraphicsEffect(shadow)

        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(24, 24, 24, 24)
        main_layout.addWidget(self._content)

        self._content_layout = QVBoxLayout(self._content)
        self._content_layout.setContentsMargins(0, 0, 0, 0)
        self._content_layout.setSpacing(0)

    def set_content_layout(self, layout):
        while self._content_layout.count():
            item = self._content_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        self._content_layout.addLayout(layout)


class RinToast(QFrame):
    class Type(enum.Enum):
        INFO = "info"
        SUCCESS = "success"
        WARNING = "warning"
        ERROR = "error"

    def __init__(
        self,
        message: str,
        type: Type = Type.INFO,
        duration: int = 3000,
        parent: Optional[QWidget] = None
    ):
        super().__init__(parent)
        self.setObjectName("RinToast")
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.ToolTip |
            Qt.WindowType.WindowStaysOnTopHint
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(16, 12, 16, 12)
        layout.setSpacing(12)

        try:
            import qtawesome as qta
            icons = {
                self.Type.INFO: "fa5s.info-circle",
                self.Type.SUCCESS: "fa5s.check-circle",
                self.Type.WARNING: "fa5s.exclamation-triangle",
                self.Type.ERROR: "fa5s.times-circle",
            }
            colors = {
                self.Type.INFO: "#0078d4",
                self.Type.SUCCESS: "#107c10",
                self.Type.WARNING: "#ff8c00",
                self.Type.ERROR: "#d13438",
            }
            icon = qta.icon(icons[type], color=colors[type])
            icon_label = QLabel()
            icon_label.setFixedSize(20, 20)
            icon_label.setPixmap(icon.pixmap(20, 20))
            layout.addWidget(icon_label)
        except ImportError:
            pass

        msg_label = QLabel(message)
        msg_label.setFont(QFont("Microsoft YaHei UI", 11))
        msg_label.setWordWrap(True)
        layout.addWidget(msg_label, 1)

        close_btn = RinIconButton(icon_name="fa5s.times", size=14)
        close_btn.clicked.connect(self.close)
        layout.addWidget(close_btn)

        self._timer = QTimer(self)
        self._timer.setSingleShot(True)
        self._timer.timeout.connect(self.close)
        self._timer.start(duration)

    def show_at(self, pos: QPoint):
        self.move(pos)
        self.show()


class RinIconPicker(QDialog):
    icon_selected = Signal(str)

    def __init__(self, parent: Optional[QWidget] = None, current_icon: str = "fa5s.rocket"):
        super().__init__(parent)
        self.setWindowTitle("选择图标")
        self.setMinimumSize(560, 480)
        self.setModal(True)

        self._icon_sets = {
            "Font Awesome 5 Solid": [
                "fa5s.rocket", "fa5s.star", "fa5s.folder", "fa5s.file", "fa5s.code",
                "fa5s.terminal", "fa5s.database", "fa5s.server", "fa5s.cloud", "fa5s.globe",
                "fa5s.play", "fa5s.pause", "fa5s.stop", "fa5s.forward", "fa5s.backward",
                "fa5s.volume-up", "fa5s.volume-mute", "fa5s.image", "fa5s.video", "fa5s.music",
                "fa5s.gamepad", "fa5s.tv", "fa5s.mobile", "fa5s.tablet", "fa5s.laptop",
                "fa5s.desktop", "fa5s.keyboard", "fa5s.mouse", "fa5s.print", "fa5s.camera",
                "fa5s.cog", "fa5s.tools", "fa5s.wrench", "fa5s.hammer", "fa5s.pen",
                "fa5s.pencil", "fa5s.paint-brush", "fa5s.palette", "fa5s.magic", "fa5s.fire",
                "fa5s.bolt", "fa5s.leaf", "fa5s.tree", "fa5s.seedling", "fa5s.sun",
                "fa5s.moon", "fa5s.cloud-sun", "fa5s.cloud-moon", "fa5s.tint", "fa5s.wind",
            ],
            "Font Awesome 5 Brands": [
                "fa5b.github", "fa5b.gitlab", "fa5b.bitbucket", "fa5b.docker", "fa5b.kubernetes",
                "fa5b.aws", "fa5b.google", "fa5b.microsoft", "fa5b.apple", "fa5b.android",
                "fa5b.linux", "fa5b.windows", "fa5b.ubuntu", "fa5b.debian", "fa5b.fedora",
                "fa5b.python", "fa5b.node-js", "fa5b.java", "fa5b.react", "fa5b.vuejs",
                "fa5b.angular", "fa5b.svelte", "fa5b.docker", "fa5b.npm", "fa5b.yarn",
            ],
        }

        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 16, 16, 16)
        layout.setSpacing(16)

        search = RinLineEdit(placeholder="搜索图标...")
        search.set_leading_icon("fa5s.search")
        search.textChanged.connect(self._filter_icons)
        layout.addWidget(search)

        self._tab_widget = QTabWidget()
        for name, icons in self._icon_sets.items():
            page = QWidget()
            page_layout = QVBoxLayout(page)
            page_layout.setContentsMargins(0, 8, 0, 0)

            scroll = QScrollArea()
            scroll.setWidgetResizable(True)
            scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            scroll.setFrameShape(QFrame.Shape.NoFrame)

            grid_widget = QWidget()
            self._grid_layout = QVBoxLayout(grid_widget)
            self._grid_layout.setContentsMargins(0, 0, 0, 0)
            self._grid_layout.setSpacing(8)

            self._icon_buttons = []
            row = QHBoxLayout()
            row.setSpacing(8)
            for i, icon_name in enumerate(icons):
                btn = RinIconButton(icon_name=icon_name, size=28)
                btn.setFixedSize(48, 48)
                btn.setProperty("icon_name", icon_name)
                btn.clicked.connect(lambda _, n=icon_name: self._select_icon(n))
                if icon_name == current_icon:
                    btn.setStyleSheet("border: 2px solid #0078d4; border-radius: 8px;")
                self._icon_buttons.append(btn)
                row.addWidget(btn)
                if (i + 1) % 10 == 0:
                    self._grid_layout.addLayout(row)
                    row = QHBoxLayout()
                    row.setSpacing(8)
            if row.count() > 0:
                self._grid_layout.addLayout(row)
            self._grid_layout.addStretch()

            scroll.setWidget(grid_widget)
            page_layout.addWidget(scroll)
            self._tab_widget.addTab(page, name)

        layout.addWidget(self._tab_widget, 1)

        btn_box = QDialogButtonBox(QDialogButtonBox.StandardButton.Cancel)
        btn_box.rejected.connect(self.reject)
        layout.addWidget(btn_box)

    def _filter_icons(self, text: str):
        text = text.lower()
        for btn in self._icon_buttons:
            icon_name = btn.property("icon_name")
            btn.setVisible(text in icon_name.lower())

    def _select_icon(self, icon_name: str):
        self.icon_selected.emit(icon_name)
        self.accept()


class RinHotkeyEdit(QLineEdit):
    def __init__(self, parent: Optional[QWidget] = None):
        super().__init__(parent)
        self.setPlaceholderText("点击输入热键...")
        self.setReadOnly(True)
        self.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._recording = False
        self._listener = None

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton and not self._recording:
            self._start_recording()
        super().mousePressEvent(event)

    def _start_recording(self):
        self._recording = True
        self.setText("按下热键组合...")
        self.setStyleSheet("background-color: #e8f0fe; border-color: #0078d4;")

        try:
            from pynput import keyboard
            self._pressed_keys = set()

            def on_press(key):
                try:
                    k = key.char.upper() if key.char else key.name
                except AttributeError:
                    k = str(key).replace("Key.", "").upper()
                self._pressed_keys.add(k)
                self._update_display()

            def on_release(key):
                try:
                    k = key.char.upper() if key.char else key.name
                except AttributeError:
                    k = str(key).replace("Key.", "").upper()
                if k in self._pressed_keys:
                    self._pressed_keys.remove(k)
                if not self._pressed_keys:
                    self._finish_recording()

            self._listener = keyboard.Listener(on_press=on_press, on_release=on_release)
            self._listener.start()
        except ImportError:
            self._finish_recording()

    def _update_display(self):
        key_map = {
            "ctrl": "Ctrl", "alt": "Alt", "shift": "Shift", "win": "Win",
            "cmd": "Win", "super": "Win", "space": "Space", "enter": "Enter",
            "esc": "Esc", "tab": "Tab", "backspace": "Backspace", "delete": "Del",
            "up": "Up", "down": "Down", "left": "Left", "right": "Right",
            "f1": "F1", "f2": "F2", "f3": "F3", "f4": "F4", "f5": "F5",
            "f6": "F6", "f7": "F7", "f8": "F8", "f9": "F9", "f10": "F10",
            "f11": "F11", "f12": "F12",
        }
        parts = []
        for k in sorted(self._pressed_keys, key=lambda x: ["ctrl", "alt", "shift", "win"].index(x.lower()) if x.lower() in ["ctrl", "alt", "shift", "win"] else 99):
            parts.append(key_map.get(k.lower(), k.upper()))
        self.setText(" + ".join(parts) if parts else "按下热键组合...")

    def _finish_recording(self):
        if self._listener:
            self._listener.stop()
            self._listener = None
        self._recording = False
        self.setReadOnly(True)
        self.setStyleSheet("")

    def get_hotkey(self) -> str:
        return self.text() if self.text() != "按下热键组合..." else ""

    def set_hotkey(self, hotkey: str):
        self.setText(hotkey)


class RinFilePicker(QWidget):
    path_changed = Signal(str)

    def __init__(
        self,
        mode: str = "file",
        filter: str = "All Files (*.*)",
        parent: Optional[QWidget] = None
    ):
        super().__init__(parent)
        self._mode = mode
        self._filter = filter

        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)

        self._line_edit = RinLineEdit(placeholder="选择路径...")
        self._line_edit.setReadOnly(True)
        layout.addWidget(self._line_edit, 1)

        browse_btn = RinButton("浏览...", style=RinButton.Style.GHOST)
        browse_btn.clicked.connect(self._browse)
        layout.addWidget(browse_btn)

    def _browse(self):
        if self._mode == "file":
            path, _ = QFileDialog.getOpenFileName(self, "选择文件", "", self._filter)
        elif self._mode == "dir":
            path = QFileDialog.getExistingDirectory(self, "选择文件夹")
        else:
            path, _ = QFileDialog.getSaveFileName(self, "保存文件", "", self._filter)

        if path:
            self._line_edit.setText(path)
            self.path_changed.emit(path)

    def set_path(self, path: str):
        self._line_edit.setText(path)

    def get_path(self) -> str:
        return self._line_edit.text()


class RinColorPicker(QPushButton):
    color_changed = Signal(str)

    def __init__(self, color: str = "#0078d4", parent: Optional[QWidget] = None):
        super().__init__(parent)
        self._color = color
        self.setFixedSize(40, 28)
        self.setCursor(QCursor(Qt.CursorShape.PointingHandCursor))
        self.clicked.connect(self._pick_color)
        self._update_style()

    def _update_style(self):
        self.setStyleSheet(f"""
            QPushButton {{
                background-color: {self._color};
                border: 1px solid #d2d0ce;
                border-radius: 6px;
            }}
            QPushButton:hover {{
                border-color: #0078d4;
            }}
        """)

    def _pick_color(self):
        from PySide6.QtWidgets import QColorDialog
        color = QColorDialog.getColor(QColor(self._color), self, "选择颜色")
        if color.isValid():
            self._color = color.name()
            self._update_style()
            self.color_changed.emit(self._color)

    def get_color(self) -> str:
        return self._color

    def set_color(self, color: str):
        self._color = color
        self._update_style()