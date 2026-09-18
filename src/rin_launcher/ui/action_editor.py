from __future__ import annotations

import uuid
from typing import Optional

from PySide6.QtCore import Qt, Signal, QSize
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QLabel, QWidget,
    QTabWidget, QFormLayout, QLineEdit, QComboBox, QSpinBox,
    QCheckBox, QTextEdit, QPushButton, QDialogButtonBox,
    QScrollArea, QFrame, QSizePolicy, QMessageBox, QListWidget,
    QListWidgetItem, QAbstractItemView
)

from ..core.models import Action, ActionType, KeyMouseStep, RunAs, Category
from ..core.config_manager import ConfigManager
from .components import (
    RinButton, RinLineEdit, RinComboBox, RinIconButton,
    RinIconPicker, RinHotkeyEdit, RinFilePicker, RinColorPicker,
    RinSwitch, RinCard
)
from .theme import ThemeManager


class KeyMouseStepEditor(QWidget):
    step_changed = Signal()
    delete_requested = Signal()

    def __init__(self, step: Optional[KeyMouseStep] = None, parent: Optional[QWidget] = None):
        super().__init__(parent)
        self._step = step or KeyMouseStep(type="key")

        layout = QHBoxLayout(self)
        layout.setContentsMargins(8, 8, 8, 8)
        layout.setSpacing(8)

        # Type selector
        self._type_combo = RinComboBox()
        self._type_combo.addItems(["按键", "鼠标", "等待"])
        self._type_combo.setCurrentText({"key": "按键", "mouse": "鼠标", "wait": "等待"}[self._step.type])
        self._type_combo.currentTextChanged.connect(self._on_type_changed)
        layout.addWidget(self._type_combo)

        # Stack for different step types
        self._key_widget = self._create_key_widget()
        self._mouse_widget = self._create_mouse_widget()
        self._wait_widget = self._create_wait_widget()

        layout.addWidget(self._key_widget, 1)
        layout.addWidget(self._mouse_widget, 1)
        layout.addWidget(self._wait_widget, 1)

        # Delete button
        del_btn = RinIconButton(icon_name="fa5s.trash", size=14)
        del_btn.setFixedSize(28, 28)
        del_btn.setToolTip("删除此步骤")
        del_btn.clicked.connect(self.delete_requested.emit)
        layout.addWidget(del_btn)

        self._update_visibility()

    def _create_key_widget(self) -> QWidget:
        w = QWidget()
        layout = QHBoxLayout(w)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)

        layout.addWidget(QLabel("按键:"))
        self._key_edit = RinHotkeyEdit()
        self._key_edit.setFixedWidth(180)
        if self._step.key:
            self._key_edit.set_hotkey(self._step.key)
        self._key_edit.textChanged.connect(self.step_changed.emit)
        layout.addWidget(self._key_edit)

        layout.addWidget(QLabel("动作:"))
        self._key_action = RinComboBox()
        self._key_action.addItems(["按下", "释放", "点击"])
        self._key_action.setCurrentText({"press": "按下", "release": "释放", "click": "点击"}[self._step.action or "press"])
        self._key_action.currentTextChanged.connect(self.step_changed.emit)
        layout.addWidget(self._key_action)

        layout.addWidget(QLabel("延迟(ms):"))
        self._key_delay = QSpinBox()
        self._key_delay.setRange(0, 10000)
        self._key_delay.setValue(int(self._step.duration * 1000))
        self._key_delay.valueChanged.connect(self.step_changed.emit)
        layout.addWidget(self._key_delay)

        layout.addStretch()
        return w

    def _create_mouse_widget(self) -> QWidget:
        w = QWidget()
        layout = QHBoxLayout(w)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)

        layout.addWidget(QLabel("动作:"))
        self._mouse_action = RinComboBox()
        self._mouse_action.addItems(["点击", "移动", "滚动"])
        self._mouse_action.setCurrentText({"click": "点击", "move": "移动", "scroll": "滚动"}[self._step.action or "click"])
        self._mouse_action.currentTextChanged.connect(self._on_mouse_action_changed)
        layout.addWidget(self._mouse_action)

        layout.addWidget(QLabel("按钮:"))
        self._mouse_button = RinComboBox()
        self._mouse_button.addItems(["左键", "右键", "中键"])
        self._mouse_button.setCurrentText({"left": "左键", "right": "右键", "middle": "中键"}[self._step.button])
        self._mouse_button.currentTextChanged.connect(self.step_changed.emit)
        layout.addWidget(self._mouse_button)

        layout.addWidget(QLabel("X:"))
        self._mouse_x = QSpinBox()
        self._mouse_x.setRange(-10000, 10000)
        self._mouse_x.setValue(self._step.x or 0)
        self._mouse_x.valueChanged.connect(self.step_changed.emit)
        layout.addWidget(self._mouse_x)

        layout.addWidget(QLabel("Y:"))
        self._mouse_y = QSpinBox()
        self._mouse_y.setRange(-10000, 10000)
        self._mouse_y.setValue(self._step.y or 0)
        self._mouse_y.valueChanged.connect(self.step_changed.emit)
        layout.addWidget(self._mouse_y)

        layout.addWidget(QLabel("ΔX:"))
        self._mouse_dx = QSpinBox()
        self._mouse_dx.setRange(-10000, 10000)
        self._mouse_dx.setValue(self._step.dx or 0)
        self._mouse_dx.valueChanged.connect(self.step_changed.emit)
        layout.addWidget(self._mouse_dx)

        layout.addWidget(QLabel("ΔY:"))
        self._mouse_dy = QSpinBox()
        self._mouse_dy.setRange(-10000, 10000)
        self._mouse_dy.setValue(self._step.dy or 0)
        self._mouse_dy.valueChanged.connect(self.step_changed.emit)
        layout.addWidget(self._mouse_dy)

        layout.addWidget(QLabel("延迟(ms):"))
        self._mouse_delay = QSpinBox()
        self._mouse_delay.setRange(0, 10000)
        self._mouse_delay.setValue(int(self._step.duration * 1000))
        self._mouse_delay.valueChanged.connect(self.step_changed.emit)
        layout.addWidget(self._mouse_delay)

        layout.addStretch()
        return w

    def _create_wait_widget(self) -> QWidget:
        w = QWidget()
        layout = QHBoxLayout(w)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)

        layout.addWidget(QLabel("等待时间(ms):"))
        self._wait_duration = QSpinBox()
        self._wait_duration.setRange(0, 60000)
        self._wait_duration.setValue(int(self._step.duration * 1000))
        self._wait_duration.valueChanged.connect(self.step_changed.emit)
        layout.addWidget(self._wait_duration)

        layout.addStretch()
        return w

    def _on_type_changed(self, text: str):
        type_map = {"按键": "key", "鼠标": "mouse", "等待": "wait"}
        self._step.type = type_map.get(text, "key")
        self._update_visibility()
        self.step_changed.emit()

    def _on_mouse_action_changed(self, text: str):
        action_map = {"点击": "click", "移动": "move", "滚动": "scroll"}
        self._step.action = action_map.get(text, "click")
        self.step_changed.emit()

    def _update_visibility(self):
        self._key_widget.setVisible(self._step.type == "key")
        self._mouse_widget.setVisible(self._step.type == "mouse")
        self._wait_widget.setVisible(self._step.type == "wait")

    def get_step(self) -> KeyMouseStep:
        step = KeyMouseStep(type=self._step.type)

        if self._step.type == "key":
            step.key = self._key_edit.get_hotkey()
            action_map = {"按下": "press", "释放": "release", "点击": "click"}
            step.action = action_map.get(self._key_action.currentText(), "press")
            step.duration = self._key_delay.value() / 1000.0
        elif self._step.type == "mouse":
            action_map = {"点击": "click", "移动": "move", "滚动": "scroll"}
            step.action = action_map.get(self._mouse_action.currentText(), "click")
            button_map = {"左键": "left", "右键": "right", "中键": "middle"}
            step.button = button_map.get(self._mouse_button.currentText(), "left")
            step.x = self._mouse_x.value() if self._mouse_x.value() != 0 else None
            step.y = self._mouse_y.value() if self._mouse_y.value() != 0 else None
            step.dx = self._mouse_dx.value() if self._mouse_dx.value() != 0 else None
            step.dy = self._mouse_dy.value() if self._mouse_dy.value() != 0 else None
            step.duration = self._mouse_delay.value() / 1000.0
        elif self._step.type == "wait":
            step.duration = self._wait_duration.value() / 1000.0

        return step


class ActionEditorDialog(QDialog):
    def __init__(
        self,
        config_manager: ConfigManager,
        action: Optional[Action] = None,
        parent: Optional[QWidget] = None
    ):
        super().__init__(parent)
        self.config_manager = config_manager
        self._action = action or Action()
        self._is_new = action is None

        self.setWindowTitle("编辑操作" if not self._is_new else "新建操作")
        self.setMinimumSize(700, 600)
        self.setModal(True)

        self._setup_ui()
        self._load_action()

    def _setup_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # Tab widget
        self._tabs = QTabWidget()
        layout.addWidget(self._tabs, 1)

        # Basic tab
        self._basic_tab = self._create_basic_tab()
        self._tabs.addTab(self._basic_tab, "基本设置")

        # Advanced tab
        self._advanced_tab = self._create_advanced_tab()
        self._tabs.addTab(self._advanced_tab, "高级设置")

        # Keymouse tab (only for keymouse type)
        self._keymouse_tab = self._create_keymouse_tab()
        self._tabs.addTab(self._keymouse_tab, "键鼠序列")

        # Buttons
        btn_box = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        btn_box.accepted.connect(self._on_accept)
        btn_box.rejected.connect(self.reject)
        layout.addWidget(btn_box)

    def _create_basic_tab(self) -> QWidget:
        w = QWidget()
        layout = QVBoxLayout(w)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(16)

        # Name and icon
        form = QFormLayout()
        form.setLabelAlignment(Qt.AlignmentFlag.AlignRight)
        form.setFormAlignment(Qt.AlignmentFlag.AlignTop)
        form.setSpacing(16)

        # Name
        self._name_edit = RinLineEdit(placeholder="操作名称")
        form.addRow("名称:", self._name_edit)

        # Icon
        icon_layout = QHBoxLayout()
        icon_layout.setSpacing(8)
        self._icon_btn = RinIconButton(icon_name=self._action.icon, size=24)
        self._icon_btn.setFixedSize(48, 48)
        self._icon_btn.clicked.connect(self._pick_icon)
        icon_layout.addWidget(self._icon_btn)

        self._icon_name_label = QLabel(self._action.icon)
        self._icon_name_label.setStyleSheet("color: #605e5c; font-family: Consolas;")
        icon_layout.addWidget(self._icon_name_label)
        icon_layout.addStretch()
        form.addRow("图标:", icon_layout)

        # Type
        self._type_combo = RinComboBox()
        self._type_combo.addItems([
            "文件/程序 (file)",
            "命令行 (cmd)",
            "网址 (url)",
            "键鼠模拟 (keymouse)"
        ])
        type_map = {
            ActionType.FILE: 0,
            ActionType.CMD: 1,
            ActionType.URL: 2,
            ActionType.KEYMOUSE: 3
        }
        self._type_combo.setCurrentIndex(type_map.get(self._action.type, 0))
        self._type_combo.currentIndexChanged.connect(self._on_type_changed)
        form.addRow("类型:", self._type_combo)

        # Target (varies by type)
        self._target_stack = QWidget()
        self._target_layout = QVBoxLayout(self._target_stack)
        self._target_layout.setContentsMargins(0, 0, 0, 0)
        self._target_layout.setSpacing(8)

        # File target
        self._file_target = RinFilePicker(mode="file")
        self._file_target.path_changed.connect(lambda _: None)
        self._target_layout.addWidget(self._file_target)

        # Cmd target
        self._cmd_target = RinLineEdit(placeholder="命令 (如: cmd.exe, powershell.exe, ping)")
        self._target_layout.addWidget(self._cmd_target)

        # URL target
        self._url_target = RinLineEdit(placeholder="网址 (如: https://github.com)")
        self._target_layout.addWidget(self._url_target)

        # Keymouse target (empty, handled in keymouse tab)
        self._keymouse_placeholder = QLabel("在「键鼠序列」标签页配置按键和鼠标操作")
        self._keymouse_placeholder.setStyleSheet("color: #605e5c; padding: 20px;")
        self._keymouse_placeholder.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._target_layout.addWidget(self._keymouse_placeholder)

        form.addRow("目标:", self._target_stack)

        # Arguments
        self._args_edit = RinLineEdit(placeholder="参数 (可选)")
        form.addRow("参数:", self._args_edit)

        # Working directory
        self._workdir_picker = RinFilePicker(mode="dir")
        form.addRow("工作目录:", self._workdir_picker)

        # Category
        self._category_combo = RinComboBox()
        self._update_categories()
        form.addRow("分类:", self._category_combo)

        # Hotkey
        self._hotkey_edit = RinHotkeyEdit()
        form.addRow("热键:", self._hotkey_edit)

        # Tooltip
        self._tooltip_edit = RinLineEdit(placeholder="鼠标悬停提示 (可选)")
        form.addRow("提示:", self._tooltip_edit)

        layout.addLayout(form)

        # Enabled checkbox
        self._enabled_check = RinSwitch("启用此操作")
        self._enabled_check.setChecked(self._action.enabled)
        layout.addWidget(self._enabled_check)

        layout.addStretch()
        return w

    def _create_advanced_tab(self) -> QWidget:
        w = QWidget()
        layout = QVBoxLayout(w)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(16)

        # Run as admin
        self._run_as_admin = RinSwitch("以管理员身份运行")
        self._run_as_admin.setChecked(self._action.run_as == RunAs.ADMIN)
        layout.addWidget(self._run_as_admin)

        # Order
        order_layout = QHBoxLayout()
        order_layout.addWidget(QLabel("排序顺序:"))
        self._order_spin = QSpinBox()
        self._order_spin.setRange(-1000, 1000)
        self._order_spin.setValue(self._action.order)
        order_layout.addWidget(self._order_spin)
        order_layout.addStretch()
        layout.addLayout(order_layout)

        layout.addStretch()
        return w

    def _create_keymouse_tab(self) -> QWidget:
        w = QWidget()
        layout = QVBoxLayout(w)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(16)

        # Toolbar
        toolbar = QHBoxLayout()
        toolbar.setSpacing(8)

        add_key_btn = RinButton("添加按键", icon_name="fa5s.keyboard", style=RinButton.Style.SECONDARY)
        add_key_btn.clicked.connect(lambda: self._add_keymouse_step("key"))
        toolbar.addWidget(add_key_btn)

        add_mouse_btn = RinButton("添加鼠标", icon_name="fa5s.mouse", style=RinButton.Style.SECONDARY)
        add_mouse_btn.clicked.connect(lambda: self._add_keymouse_step("mouse"))
        toolbar.addWidget(add_mouse_btn)

        add_wait_btn = RinButton("添加等待", icon_name="fa5s.clock", style=RinButton.Style.SECONDARY)
        add_wait_btn.clicked.connect(lambda: self._add_keymouse_step("wait"))
        toolbar.addWidget(add_wait_btn)

        toolbar.addStretch()
        layout.addLayout(toolbar)

        # Steps list
        self._steps_list = QListWidget()
        self._steps_list.setDragDropMode(QAbstractItemView.DragDropMode.InternalMove)
        self._steps_list.model().rowsMoved.connect(self._on_steps_reordered)
        layout.addWidget(self._steps_list, 1)

        # Help text
        help_label = QLabel(
            "提示: 拖拽调整顺序。按键支持组合键 (如 Ctrl+C)。鼠标坐标为屏幕绝对坐标，留空为当前位置。"
        )
        help_label.setWordWrap(True)
        help_label.setStyleSheet("color: #605e5c; font-size: 11px;")
        layout.addWidget(help_label)

        return w

    def _update_categories(self):
        self._category_combo.clear()
        categories = self.config_manager.get_all_categories()
        for cat in categories:
            self._category_combo.addItem(cat.name, cat.name)
        if self._action.category:
            index = self._category_combo.findData(self._action.category)
            if index >= 0:
                self._category_combo.setCurrentIndex(index)

    def _on_type_changed(self, index: int):
        type_map = [ActionType.FILE, ActionType.CMD, ActionType.URL, ActionType.KEYMOUSE]
        self._action.type = type_map[index]

        # Show/hide target widgets
        self._file_target.setVisible(index == 0)
        self._cmd_target.setVisible(index == 1)
        self._url_target.setVisible(index == 2)
        self._keymouse_placeholder.setVisible(index == 3)

        # Enable/disable keymouse tab
        self._tabs.setTabEnabled(2, index == 3)

    def _pick_icon(self):
        dialog = RinIconPicker(self, self._action.icon)
        dialog.icon_selected.connect(self._on_icon_selected)
        dialog.exec()

    def _on_icon_selected(self, icon_name: str):
        self._action.icon = icon_name
        try:
            import qtawesome as qta
            self._icon_btn.setIcon(qta.icon(icon_name, color="#0078d4"))
        except ImportError:
            pass
        self._icon_name_label.setText(icon_name)

    def _add_keymouse_step(self, step_type: str):
        step = KeyMouseStep(type=step_type)
        self._action.keymouse_steps.append(step)
        self._refresh_steps_list()

    def _refresh_steps_list(self):
        self._steps_list.clear()
        for i, step in enumerate(self._action.keymouse_steps):
            item = QListWidgetItem()
            item.setSizeHint(QSize(0, 60))
            self._steps_list.addItem(item)

            editor = KeyMouseStepEditor(step)
            editor.step_changed.connect(self._on_step_changed)
            editor.delete_requested.connect(lambda idx=i: self._delete_step(idx))
            self._steps_list.setItemWidget(item, editor)

    def _on_step_changed(self):
        # Update step from editor
        for i in range(self._steps_list.count()):
            item = self._steps_list.item(i)
            editor = self._steps_list.itemWidget(item)
            if editor:
                self._action.keymouse_steps[i] = editor.get_step()

    def _delete_step(self, index: int):
        if 0 <= index < len(self._action.keymouse_steps):
            self._action.keymouse_steps.pop(index)
            self._refresh_steps_list()

    def _on_steps_reordered(self):
        # Reorder steps based on list order
        new_steps = []
        for i in range(self._steps_list.count()):
            item = self._steps_list.item(i)
            editor = self._steps_list.itemWidget(item)
            if editor:
                new_steps.append(editor.get_step())
        self._action.keymouse_steps = new_steps

    def _load_action(self):
        self._name_edit.setText(self._action.name)
        self._args_edit.setText(self._action.arguments)
        self._workdir_picker.set_path(self._action.working_dir)
        self._hotkey_edit.set_hotkey(self._action.hotkey)
        self._tooltip_edit.setText(self._action.tooltip)

        if self._action.type == ActionType.FILE:
            self._file_target.set_path(self._action.target)
        elif self._action.type == ActionType.CMD:
            self._cmd_target.setText(self._action.target)
        elif self._action.type == ActionType.URL:
            self._url_target.setText(self._action.target)

        self._refresh_steps_list()
        self._on_type_changed(self._type_combo.currentIndex())

    def _on_accept(self):
        # Validate
        if not self._name_edit.text().strip():
            QMessageBox.warning(self, "验证失败", "请输入操作名称")
            return

        if self._action.type == ActionType.FILE and not self._file_target.get_path().strip():
            QMessageBox.warning(self, "验证失败", "请选择文件或程序")
            return

        if self._action.type == ActionType.CMD and not self._cmd_target.text().strip():
            QMessageBox.warning(self, "验证失败", "请输入命令")
            return

        if self._action.type == ActionType.URL and not self._url_target.text().strip():
            QMessageBox.warning(self, "验证失败", "请输入网址")
            return

        # Update action
        self._action.name = self._name_edit.text().strip()
        self._action.arguments = self._args_edit.text().strip()
        self._action.working_dir = self._workdir_picker.get_path()
        self._action.category = self._category_combo.currentData() or "默认"
        self._action.hotkey = self._hotkey_edit.get_hotkey()
        self._action.tooltip = self._tooltip_edit.text().strip()
        self._action.enabled = self._enabled_check.isChecked()
        self._action.run_as = RunAs.ADMIN if self._run_as_admin.isChecked() else RunAs.USER
        self._action.order = self._order_spin.value()

        if self._action.type == ActionType.FILE:
            self._action.target = self._file_target.get_path()
        elif self._action.type == ActionType.CMD:
            self._action.target = self._cmd_target.text().strip()
        elif self._action.type == ActionType.URL:
            self._action.target = self._url_target.text().strip()

        # Save
        if self._is_new:
            self.config_manager.add_action(self._action)
        else:
            self.config_manager.update_action(self._action)

        self.accept()