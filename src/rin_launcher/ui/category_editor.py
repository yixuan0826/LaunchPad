from __future__ import annotations

from typing import Optional

from PySide6.QtCore import Qt
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QLabel, QWidget,
    QFormLayout, QLineEdit, QSpinBox, QCheckBox,
    QPushButton, QDialogButtonBox, QMessageBox
)

from ..core.models import Category
from ..core.config_manager import ConfigManager
from .components import RinButton, RinLineEdit, RinIconButton, RinIconPicker, RinSwitch
from .theme import ThemeManager


class CategoryEditorDialog(QDialog):
    def __init__(
        self,
        config_manager: ConfigManager,
        category: Optional[Category] = None,
        parent: Optional[QWidget] = None
    ):
        super().__init__(parent)
        self.config_manager = config_manager
        self._category = category or Category()
        self._is_new = category is None

        self.setWindowTitle("编辑分类" if not self._is_new else "新建分类")
        self.setMinimumSize(480, 360)
        self.setModal(True)
        self.setWindowFlags(Qt.WindowType.Dialog | Qt.WindowType.FramelessWindowHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)

        self._setup_ui()
        self._load_category()

    def _setup_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # Content frame
        self._content = QWidget()
        self._content.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        
        theme = ThemeManager().theme
        self._content.setStyleSheet(f"""
            QWidget {{
                background-color: {theme.colors.surface};
                border-radius: 12px;
                border: 1px solid {theme.colors.border};
            }}
        """)

        content_layout = QVBoxLayout(self._content)
        content_layout.setContentsMargins(0, 0, 0, 0)
        content_layout.setSpacing(0)

        # Header
        header = QWidget()
        header.setFixedHeight(56)
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(20, 0, 20, 0)

        title = QLabel("编辑分类" if not self._is_new else "新建分类")
        title.setFont(QFont("Microsoft YaHei UI", 15, QFont.Weight.DemiBold))
        header_layout.addWidget(title)

        header_layout.addStretch()

        close_btn = RinIconButton(icon_name="fa5s.times", size=16)
        close_btn.setFixedSize(32, 32)
        close_btn.clicked.connect(self.reject)
        header_layout.addWidget(close_btn)

        content_layout.addWidget(header)

        # Divider
        divider = QFrame()
        divider.setFixedHeight(1)
        divider.setStyleSheet(f"background-color: {theme.colors.border}; border: none;")
        content_layout.addWidget(divider)

        # Form
        form_widget = QWidget()
        form_layout = QFormLayout(form_widget)
        form_layout.setContentsMargins(24, 24, 24, 24)
        form_layout.setLabelAlignment(Qt.AlignmentFlag.AlignRight)
        form_layout.setFormAlignment(Qt.AlignmentFlag.AlignTop)
        form_layout.setSpacing(16)

        # Name
        self._name_edit = RinLineEdit(placeholder="分类名称")
        form_layout.addRow("名称:", self._name_edit)

        # Icon
        icon_layout = QHBoxLayout()
        icon_layout.setSpacing(8)
        self._icon_btn = RinIconButton(icon_name=self._category.icon, size=24)
        self._icon_btn.setFixedSize(48, 48)
        self._icon_btn.clicked.connect(self._pick_icon)
        icon_layout.addWidget(self._icon_btn)

        self._icon_name_label = QLabel(self._category.icon)
        self._icon_name_label.setStyleSheet("color: #605e5c; font-family: Consolas;")
        icon_layout.addWidget(self._icon_name_label)
        icon_layout.addStretch()
        form_layout.addRow("图标:", icon_layout)

        # Order
        self._order_spin = QSpinBox()
        self._order_spin.setRange(-1000, 1000)
        self._order_spin.setValue(self._category.order)
        form_layout.addRow("排序:", self._order_spin)

        # Expanded by default
        self._expanded_check = RinSwitch("默认展开")
        self._expanded_check.setChecked(self._category.expanded)
        form_layout.addRow("", self._expanded_check)

        content_layout.addWidget(form_widget, 1)

        # Buttons
        btn_layout = QHBoxLayout()
        btn_layout.setContentsMargins(24, 0, 24, 24)
        btn_layout.setSpacing(12)
        btn_layout.addStretch()

        cancel_btn = RinButton("取消", style=RinButton.Style.GHOST)
        cancel_btn.clicked.connect(self.reject)
        btn_layout.addWidget(cancel_btn)

        save_btn = RinButton("保存", style=RinButton.Style.PRIMARY)
        save_btn.clicked.connect(self._on_save)
        btn_layout.addWidget(save_btn)

        content_layout.addLayout(btn_layout)

        layout.addWidget(self._content)

    def _pick_icon(self):
        dialog = RinIconPicker(self, self._category.icon)
        dialog.icon_selected.connect(self._on_icon_selected)
        dialog.exec()

    def _on_icon_selected(self, icon_name: str):
        self._category.icon = icon_name
        try:
            import qtawesome as qta
            self._icon_btn.setIcon(qta.icon(icon_name, color="#0078d4"))
        except ImportError:
            pass
        self._icon_name_label.setText(icon_name)

    def _load_category(self):
        self._name_edit.setText(self._category.name)
        self._order_spin.setValue(self._category.order)
        self._expanded_check.setChecked(self._category.expanded)

    def _on_save(self):
        if not self._name_edit.text().strip():
            QMessageBox.warning(self, "验证失败", "请输入分类名称")
            return

        self._category.name = self._name_edit.text().strip()
        self._category.order = self._order_spin.value()
        self._category.expanded = self._expanded_check.isChecked()

        if self._is_new:
            self.config_manager.add_category(self._category)
        else:
            self.config_manager.update_category(self._category)

        self.accept()