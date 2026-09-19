from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Optional

try:
    import winreg
except ImportError:
    winreg = None

from PySide6.QtCore import Qt, Signal, QSize
from PySide6.QtGui import QFont, QIcon, QDesktopServices
from PySide6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QLabel, QWidget,
    QTabWidget, QFormLayout, QLineEdit, QComboBox, QSpinBox,
    QCheckBox, QPushButton, QDialogButtonBox, QScrollArea,
    QFrame, QSizePolicy, QMessageBox, QFileDialog, QListWidget,
    QListWidgetItem, QAbstractItemView, QGroupBox
)

from ..core.models import Action, Category, AppSettings
from ..core.config_manager import ConfigManager
from .components import (
    RinButton, RinLineEdit, RinComboBox, RinIconButton,
    RinIconPicker, RinHotkeyEdit, RinFilePicker, RinColorPicker,
    RinSwitch, RinCard, RinSettingsSection, RinToast
)
from .theme import ThemeManager, get_theme, LIGHT_THEME, DARK_THEME


class SettingsDialog(QDialog):
    def __init__(self, config_manager: ConfigManager, parent: Optional[QWidget] = None):
        super().__init__(parent)
        self.config_manager = config_manager
        self.settings = config_manager.config.settings
        self.theme_manager = ThemeManager()

        self.setWindowTitle("设置")
        self.setMinimumSize(800, 600)
        self.setModal(True)
        self.setWindowFlags(Qt.WindowType.Dialog | Qt.WindowType.FramelessWindowHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)

        self._setup_ui()
        self._load_settings()

    def _setup_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(0)

        # Content frame
        self._content = QFrame()
        self._content.setObjectName("SettingsContent")
        self._content.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)

        from ..ui.theme import ThemeManager
        theme = self.theme_manager.theme
        self._content.setStyleSheet(f"""
            #SettingsContent {{
                background-color: {theme.colors.surface};
                border-radius: 12px;
                border: 1px solid {theme.colors.border};
            }}
        """)

        shadow = QWidget()
        shadow.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        # Shadow effect handled by parent

        content_layout = QVBoxLayout(self._content)
        content_layout.setContentsMargins(0, 0, 0, 0)
        content_layout.setSpacing(0)

        # Header
        header = QWidget()
        header.setFixedHeight(64)
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(24, 0, 24, 0)

        title = QLabel("设置")
        title.setFont(QFont("Microsoft YaHei UI", 18, QFont.Weight.DemiBold))
        header_layout.addWidget(title)

        header_layout.addStretch()

        close_btn = RinIconButton(icon_name="fa5s.times", size=18)
        close_btn.setFixedSize(36, 36)
        close_btn.clicked.connect(self.reject)
        header_layout.addWidget(close_btn)

        content_layout.addWidget(header)

        # Divider
        divider = QFrame()
        divider.setFixedHeight(1)
        divider.setStyleSheet(f"background-color: {theme.colors.border}; border: none;")
        content_layout.addWidget(divider)

        # Main area with sidebar and content
        main_area = QHBoxLayout()
        main_area.setContentsMargins(0, 0, 0, 0)
        main_area.setSpacing(0)

        # Sidebar
        self._sidebar = QListWidget()
        self._sidebar.setObjectName("SettingsSidebar")
        self._sidebar.setFixedWidth(200)
        self._sidebar.setFrameShape(QFrame.Shape.NoFrame)
        self._sidebar.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self._sidebar.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self._sidebar.currentRowChanged.connect(self._on_sidebar_changed)

        sidebar_items = [
            ("常规", "fa5s.home"),
            ("外观", "fa5s.palette"),
            ("动作管理", "fa5s.cogs"),
            ("热键", "fa5s.keyboard"),
            ("高级", "fa5s.tools"),
            ("关于", "fa5s.info-circle"),
        ]

        try:
            import qtawesome as qta
            for name, icon_name in sidebar_items:
                item = QListWidgetItem()
                item.setText(f"  {name}")
                item.setIcon(qta.icon(icon_name, color="#605e5c"))
                item.setSizeHint(QSize(0, 44))
                item.setFont(QFont("Microsoft YaHei UI", 11))
                self._sidebar.addItem(item)
        except ImportError:
            for name, _ in sidebar_items:
                item = QListWidgetItem(name)
                item.setSizeHint(QSize(0, 44))
                item.setFont(QFont("Microsoft YaHei UI", 11))
                self._sidebar.addItem(item)

        self._sidebar.setStyleSheet(f"""
            #SettingsSidebar {{
                background-color: transparent;
                border: none;
                outline: none;
            }}
            #SettingsSidebar::item {{
                padding: 8px 16px;
                border-radius: 0;
                color: #605e5c;
            }}
            #SettingsSidebar::item:selected {{
                background-color: {theme.colors.primary_light};
                color: {theme.colors.primary};
                font-weight: 600;
            }}
            #SettingsSidebar::item:hover:!selected {{
                background-color: {theme.colors.background_hover};
                color: #323130;
            }}
        """)

        main_area.addWidget(self._sidebar)

        # Content stack
        self._content_stack = QWidget()
        self._content_stack_layout = QVBoxLayout(self._content_stack)
        self._content_stack_layout.setContentsMargins(0, 0, 0, 0)

        # Create pages
        self._pages = []
        self._pages.append(self._create_general_page())
        self._pages.append(self._create_appearance_page())
        self._pages.append(self._create_actions_page())
        self._pages.append(self._create_hotkeys_page())
        self._pages.append(self._create_advanced_page())
        self._pages.append(self._create_about_page())

        for page in self._pages:
            self._content_stack_layout.addWidget(page)
            page.hide()

        self._pages[0].show()

        main_area.addWidget(self._content_stack, 1)
        content_layout.addLayout(main_area, 1)

        # Bottom buttons
        btn_layout = QHBoxLayout()
        btn_layout.setContentsMargins(24, 16, 24, 24)
        btn_layout.setSpacing(12)

        btn_layout.addStretch()

        self._import_btn = RinButton("导入配置", style=RinButton.Style.GHOST)
        self._import_btn.clicked.connect(self._import_config)
        btn_layout.addWidget(self._import_btn)

        self._export_btn = RinButton("导出配置", style=RinButton.Style.GHOST)
        self._export_btn.clicked.connect(self._export_config)
        btn_layout.addWidget(self._export_btn)

        self._reset_btn = RinButton("重置默认", style=RinButton.Style.DANGER)
        self._reset_btn.clicked.connect(self._reset_settings)
        btn_layout.addWidget(self._reset_btn)

        self._cancel_btn = RinButton("取消", style=RinButton.Style.GHOST)
        self._cancel_btn.clicked.connect(self.reject)
        btn_layout.addWidget(self._cancel_btn)

        self._save_btn = RinButton("保存", style=RinButton.Style.PRIMARY)
        self._save_btn.clicked.connect(self._save_settings)
        btn_layout.addWidget(self._save_btn)

        content_layout.addLayout(btn_layout)

        layout.addWidget(self._content)

    def _create_page(self, title: str, icon_name: str = "") -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(20)

        # Page header
        header = QHBoxLayout()
        if icon_name:
            try:
                import qtawesome as qta
                icon = QLabel()
                icon.setPixmap(qta.icon(icon_name, color="#0078d4").pixmap(24, 24))
                header.addWidget(icon)
            except ImportError:
                pass

        title_label = QLabel(title)
        title_label.setFont(QFont("Microsoft YaHei UI", 16, QFont.Weight.DemiBold))
        header.addWidget(title_label)
        header.addStretch()
        layout.addLayout(header)

        # Scroll area for content
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setStyleSheet("QScrollArea { background: transparent; border: none; }")

        content = QWidget()
        content.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        content_layout = QVBoxLayout(content)
        content_layout.setContentsMargins(0, 0, 0, 0)
        content_layout.setSpacing(16)

        scroll.setWidget(content)
        layout.addWidget(scroll, 1)

        page._content_layout = content_layout
        return page

    def _create_general_page(self) -> QWidget:
        page = self._create_page("常规", "fa5s.home")

        # Startup section
        startup_section = RinSettingsSection("启动行为", "fa5s.play")
        self._auto_start = RinSwitch("开机自动启动")
        self._auto_start.setChecked(self.settings.auto_start)
        self._auto_start.toggled.connect(self._on_auto_start_changed)
        startup_section.add_widget(self._auto_start)

        self._start_minimized = RinSwitch("启动时最小化到托盘")
        self._start_minimized.setChecked(self.settings.start_minimized)
        startup_section.add_widget(self._start_minimized)

        self._show_tray = RinSwitch("显示系统托盘图标")
        self._show_tray.setChecked(self.settings.show_tray)
        startup_section.add_widget(self._show_tray)

        page._content_layout.addWidget(startup_section)

        # Search section
        search_section = RinSettingsSection("搜索设置", "fa5s.search")
        self._search_engine = RinLineEdit(placeholder="搜索引擎 URL (使用 {query} 作为占位符)")
        self._search_engine.setText(self.settings.search_engine)
        search_section.add_widget(QLabel("默认搜索引擎:"))
        search_section.add_widget(self._search_engine)

        page._content_layout.addWidget(search_section)

        # Layout section
        layout_section = RinSettingsSection("启动台布局", "fa5s.th-large")
        
        grid_layout = QHBoxLayout()
        grid_layout.addWidget(QLabel("网格列数:"))
        self._grid_columns = QSpinBox()
        self._grid_columns.setRange(3, 12)
        self._grid_columns.setValue(self.settings.grid_columns)
        grid_layout.addWidget(self._grid_columns)
        grid_layout.addStretch()
        layout_section.add_layout(grid_layout)

        size_layout = QHBoxLayout()
        size_layout.addWidget(QLabel("图标大小:"))
        self._item_size = QSpinBox()
        self._item_size.setRange(64, 144)
        self._item_size.setValue(self.settings.item_size)
        self._item_size.setSuffix(" px")
        size_layout.addWidget(self._item_size)
        size_layout.addStretch()
        layout_section.add_layout(size_layout)

        self._animation_enabled = RinSwitch("启用动画效果")
        self._animation_enabled.setChecked(self.settings.animation_enabled)
        layout_section.add_widget(self._animation_enabled)

        page._content_layout.addWidget(layout_section)

        page._content_layout.addStretch()
        return page

    def _create_appearance_page(self) -> QWidget:
        page = self._create_page("外观", "fa5s.palette")

        # Theme section
        theme_section = RinSettingsSection("主题", "fa5s.adjust")
        self._theme_combo = RinComboBox()
        self._theme_combo.addItems(["跟随系统", "浅色", "深色"])
        theme_map = {"system": 0, "light": 1, "dark": 2}
        self._theme_combo.setCurrentIndex(theme_map.get(self.settings.theme, 0))
        self._theme_combo.currentIndexChanged.connect(self._on_theme_changed)
        theme_section.add_widget(QLabel("主题模式:"))
        theme_section.add_widget(self._theme_combo)

        self._blur_background = RinSwitch("启用背景模糊 (Windows 11 Mica/Acrylic)")
        self._blur_background.setChecked(self.settings.blur_background)
        theme_section.add_widget(self._blur_background)

        page._content_layout.addWidget(theme_section)

        # Colors section
        color_section = RinSettingsSection("强调色", "fa5s.tint")
        self._accent_picker = RinColorPicker(self.settings.accent_color)
        self._accent_picker.color_changed.connect(self._on_accent_changed)
        color_section.add_widget(QLabel("强调色:"))
        color_section.add_widget(self._accent_picker)

        page._content_layout.addWidget(color_section)

        # Font section
        font_section = RinSettingsSection("字体", "fa5s.font")
        self._font_family = RinLineEdit(placeholder="字体名称")
        self._font_family.setText(self.settings.font_family)
        font_section.add_widget(QLabel("字体:"))
        font_section.add_widget(self._font_family)

        font_size_layout = QHBoxLayout()
        font_size_layout.addWidget(QLabel("字体大小:"))
        self._font_size = QSpinBox()
        self._font_size.setRange(8, 24)
        self._font_size.setValue(self.settings.font_size)
        self._font_size.setSuffix(" pt")
        font_size_layout.addWidget(self._font_size)
        font_size_layout.addStretch()
        font_section.add_layout(font_size_layout)

        page._content_layout.addWidget(font_section)

        page._content_layout.addStretch()
        return page

    def _create_actions_page(self) -> QWidget:
        page = self._create_page("动作管理", "fa5s.cogs")

        # Actions list
        actions_section = RinSettingsSection("操作列表", "fa5s.list")
        
        toolbar = QHBoxLayout()
        toolbar.setSpacing(8)

        add_btn = RinButton("新建操作", icon_name="fa5s.plus", style=RinButton.Style.PRIMARY)
        add_btn.clicked.connect(self._add_action)
        toolbar.addWidget(add_btn)

        import_btn = RinButton("导入操作", icon_name="fa5s.file-import", style=RinButton.Style.SECONDARY)
        import_btn.clicked.connect(self._import_actions)
        toolbar.addWidget(import_btn)

        export_btn = RinButton("导出操作", icon_name="fa5s.file-export", style=RinButton.Style.SECONDARY)
        export_btn.clicked.connect(self._export_actions)
        toolbar.addWidget(export_btn)

        toolbar.addStretch()
        actions_section.add_layout(toolbar)

        self._actions_list = QListWidget()
        self._actions_list.setAlternatingRowColors(True)
        self._actions_list.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        self._actions_list.itemDoubleClicked.connect(self._edit_action)
        actions_section.add_widget(self._actions_list)

        # Context menu
        self._actions_list.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self._actions_list.customContextMenuRequested.connect(self._show_action_context_menu)

        page._content_layout.addWidget(actions_section, 1)

        # Categories
        cat_section = RinSettingsSection("分类管理", "fa5s.folder")
        
        cat_toolbar = QHBoxLayout()
        add_cat_btn = RinButton("新建分类", icon_name="fa5s.plus", style=RinButton.Style.PRIMARY)
        add_cat_btn.clicked.connect(self._add_category)
        cat_toolbar.addWidget(add_cat_btn)
        cat_toolbar.addStretch()
        cat_section.add_layout(cat_toolbar)

        self._categories_list = QListWidget()
        self._categories_list.setAlternatingRowColors(True)
        self._categories_list.itemDoubleClicked.connect(self._edit_category)
        cat_section.add_widget(self._categories_list)

        page._content_layout.addWidget(cat_section)

        self._refresh_actions_list()
        self._refresh_categories_list()

        return page

    def _create_hotkeys_page(self) -> QWidget:
        page = self._create_page("热键", "fa5s.keyboard")

        # Global hotkey
        global_section = RinSettingsSection("全局热键", "fa5s.magic")
        self._global_hotkey = RinHotkeyEdit()
        self._global_hotkey.set_hotkey(self.settings.global_hotkey)
        global_section.add_widget(QLabel("显示/隐藏启动台:"))
        global_section.add_widget(self._global_hotkey)

        hint = QLabel("提示: 点击输入框后按下任意组合键设置热键。修改后需重启应用生效。")
        hint.setWordWrap(True)
        hint.setStyleSheet("color: #605e5c; font-size: 11px;")
        global_section.add_widget(hint)

        page._content_layout.addWidget(global_section)

        # Action hotkeys
        hotkey_section = RinSettingsSection("操作热键", "fa5s.keyboard")
        hint2 = QLabel("在「动作管理」中为每个操作单独设置热键。热键冲突时优先级: 全局热键 > 操作热键。")
        hint2.setWordWrap(True)
        hint2.setStyleSheet("color: #605e5c; font-size: 11px;")
        hotkey_section.add_widget(hint2)

        page._content_layout.addWidget(hotkey_section)

        page._content_layout.addStretch()
        return page

    def _create_advanced_page(self) -> QWidget:
        page = self._create_page("高级", "fa5s.tools")

        # Admin section
        admin_section = RinSettingsSection("管理员权限", "fa5s.user-shield")
        self._admin_auto_elevate = RinSwitch("自动提权执行管理员操作")
        self._admin_auto_elevate.setChecked(self.settings.admin_auto_elevate)
        admin_section.add_widget(self._admin_auto_elevate)

        self._confirm_admin = RinSwitch("执行管理员操作前确认")
        self._confirm_admin.setChecked(self.settings.confirm_admin_actions)
        admin_section.add_widget(self._confirm_admin)

        restart_admin_btn = RinButton("以管理员身份重启", icon_name="fa5s.power-off", style=RinButton.Style.DANGER)
        restart_admin_btn.clicked.connect(self._restart_as_admin)
        admin_section.add_widget(restart_admin_btn)

        page._content_layout.addWidget(admin_section)

        # Config section
        config_section = RinSettingsSection("配置管理", "fa5s.database")
        
        config_btns = QHBoxLayout()
        open_config_btn = RinButton("打开配置文件夹", icon_name="fa5s.folder-open", style=RinButton.Style.SECONDARY)
        open_config_btn.clicked.connect(self._open_config_folder)
        config_btns.addWidget(open_config_btn)

        open_config_file_btn = RinButton("打开配置文件", icon_name="fa5s.file-alt", style=RinButton.Style.SECONDARY)
        open_config_file_btn.clicked.connect(self._open_config_file)
        config_btns.addWidget(open_config_file_btn)
        config_btns.addStretch()
        config_section.add_layout(config_btns)

        page._content_layout.addWidget(config_section)

        # Logging section
        log_section = RinSettingsSection("日志", "fa5s.file-alt")
        self._log_level = RinComboBox()
        self._log_level.addItems(["DEBUG", "INFO", "WARNING", "ERROR"])
        self._log_level.setCurrentText(self.settings.log_level)
        log_section.add_widget(QLabel("日志级别:"))
        log_section.add_widget(self._log_level)

        page._content_layout.addWidget(log_section)

        # Danger zone
        danger_section = RinSettingsSection("危险区域", "fa5s.exclamation-triangle")
        danger_section.setStyleSheet("QGroupBox { border-color: #d13438; }")

        reset_btn = RinButton("重置所有设置", icon_name="fa5s.trash", style=RinButton.Style.DANGER)
        reset_btn.clicked.connect(self._reset_settings)
        danger_section.add_widget(reset_btn)

        page._content_layout.addWidget(danger_section)

        page._content_layout.addStretch()
        return page

    def _create_about_page(self) -> QWidget:
        page = self._create_page("关于", "fa5s.info-circle")

        # App info
        info_card = RinCard("Rin Launcher", "类似希沃桌面助手的启动台应用", icon_name="fa5s.rocket")
        page._content_layout.addWidget(info_card)

        version_label = QLabel("版本: 1.0.0")
        version_label.setStyleSheet("color: #605e5c; font-size: 13px;")
        page._content_layout.addWidget(version_label)

        # Links
        links_section = RinSettingsSection("链接", "fa5s.external-link-alt")
        
        github_btn = RinButton("GitHub 仓库", icon_name="fa5b.github", style=RinButton.Style.GHOST)
        github_btn.clicked.connect(lambda: QDesktopServices.openUrl("https://github.com"))
        links_section.add_widget(github_btn)

        issues_btn = RinButton("问题反馈", icon_name="fa5s.bug", style=RinButton.Style.GHOST)
        issues_btn.clicked.connect(lambda: QDesktopServices.openUrl("https://github.com/issues"))
        links_section.add_widget(issues_btn)

        page._content_layout.addWidget(links_section)

        # License
        license_section = RinSettingsSection("许可证", "fa5s.file-contract")
        license_text = QLabel(
            "本软件基于 GPL-3.0-or-later 许可证开源发布。\n"
            "您可以自由使用、修改和分发本软件。"
        )
        license_text.setWordWrap(True)
        license_text.setStyleSheet("color: #605e5c;")
        license_section.add_widget(license_text)

        page._content_layout.addWidget(license_section)

        page._content_layout.addStretch()
        return page

    def _on_sidebar_changed(self, index: int):
        for i, page in enumerate(self._pages):
            page.setVisible(i == index)

    def _load_settings(self):
        # Theme
        self._theme_combo.setCurrentIndex({"system": 0, "light": 1, "dark": 2}.get(self.settings.theme, 0))

        # Other settings loaded in _create_xxx_page

    def _on_theme_changed(self, index: int):
        theme_map = {0: "system", 1: "light", 2: "dark"}
        theme_name = theme_map.get(index, "system")
        self.theme_manager.set_theme(theme_name)
        self.settings.theme = theme_name

        # Update dialog style
        theme = self.theme_manager.theme
        self._content.setStyleSheet(f"""
            #SettingsContent {{
                background-color: {theme.colors.surface};
                border-radius: 12px;
                border: 1px solid {theme.colors.border};
            }}
        """)

        # Update sidebar style
        self._sidebar.setStyleSheet(f"""
            #SettingsSidebar {{
                background-color: transparent;
                border: none;
                outline: none;
            }}
            #SettingsSidebar::item {{
                padding: 8px 16px;
                border-radius: 0;
                color: #605e5c;
            }}
            #SettingsSidebar::item:selected {{
                background-color: {theme.colors.primary_light};
                color: {theme.colors.primary};
                font-weight: 600;
            }}
            #SettingsSidebar::item:hover:!selected {{
                background-color: {theme.colors.background_hover};
                color: #323130;
            }}
        """)

    def _on_accent_changed(self, color: str):
        self.settings.accent_color = color
        # Apply to theme manager
        # Note: This would require theme manager to support custom accent colors

    def _on_auto_start_changed(self, checked: bool):
        self._set_auto_start(checked)

    def _set_auto_start(self, enable: bool):
        if sys.platform != "win32" or winreg is None:
            QMessageBox.information(self, "提示", "开机自启仅支持 Windows 系统")
            self._auto_start.setChecked(not enable)
            return

        try:
            key = winreg.OpenKey(
                winreg.HKEY_CURRENT_USER,
                r"Software\Microsoft\Windows\CurrentVersion\Run",
                0, winreg.KEY_SET_VALUE
            )
            if enable:
                exe_path = sys.executable if getattr(sys, 'frozen', False) else f'"{sys.executable}" "{sys.argv[0]}"'
                winreg.SetValueEx(key, "RinLauncher", 0, winreg.REG_SZ, exe_path)
            else:
                winreg.DeleteValue(key, "RinLauncher")
            winreg.CloseKey(key)
            self.settings.auto_start = enable
        except Exception as e:
            QMessageBox.warning(self, "错误", f"设置开机自启失败: {e}")
            self._auto_start.setChecked(not enable)

    def _refresh_actions_list(self):
        self._actions_list.clear()
        actions = self.config_manager.config.actions
        for action in actions:
            item = QListWidgetItem()
            item.setData(Qt.ItemDataRole.UserRole, action.id)
            
            widget = QWidget()
            layout = QHBoxLayout(widget)
            layout.setContentsMargins(8, 4, 8, 4)
            layout.setSpacing(12)

            try:
                import qtawesome as qta
                icon = QLabel()
                icon.setPixmap(qta.icon(action.icon, color="#0078d4").pixmap(24, 24))
                layout.addWidget(icon)
            except ImportError:
                pass

            name_label = QLabel(action.name)
            name_label.setFont(QFont("Microsoft YaHei UI", 11))
            layout.addWidget(name_label, 1)

            type_label = QLabel(action.type.value)
            type_label.setStyleSheet("color: #605e5c; font-size: 10px; padding: 2px 8px; background: #f3f2f1; border-radius: 4px;")
            layout.addWidget(type_label)

            if action.hotkey:
                hk_label = QLabel(action.hotkey)
                hk_label.setStyleSheet("color: #605e5c; font-family: Consolas; font-size: 10px;")
                layout.addWidget(hk_label)

            self._actions_list.addItem(item)
            self._actions_list.setItemWidget(item, widget)

    def _refresh_categories_list(self):
        self._categories_list.clear()
        categories = self.config_manager.config.categories
        for cat in categories:
            item = QListWidgetItem()
            item.setData(Qt.ItemDataRole.UserRole, cat.id)
            
            widget = QWidget()
            layout = QHBoxLayout(widget)
            layout.setContentsMargins(8, 4, 8, 4)
            layout.setSpacing(12)

            try:
                import qtawesome as qta
                icon = QLabel()
                icon.setPixmap(qta.icon(cat.icon, color="#605e5c").pixmap(20, 20))
                layout.addWidget(icon)
            except ImportError:
                pass

            name_label = QLabel(cat.name)
            name_label.setFont(QFont("Microsoft YaHei UI", 11))
            layout.addWidget(name_label, 1)

            order_label = QLabel(f"顺序: {cat.order}")
            order_label.setStyleSheet("color: #a19f9d; font-size: 10px;")
            layout.addWidget(order_label)

            self._categories_list.addItem(item)
            self._categories_list.setItemWidget(item, widget)

    def _add_action(self):
        from .action_editor import ActionEditorDialog
        dialog = ActionEditorDialog(self.config_manager, None, self)
        if dialog.exec():
            self._refresh_actions_list()

    def _edit_action(self, item: QListWidgetItem):
        action_id = item.data(Qt.ItemDataRole.UserRole)
        action = next((a for a in self.config_manager.config.actions if a.id == action_id), None)
        if action:
            from .action_editor import ActionEditorDialog
            dialog = ActionEditorDialog(self.config_manager, action, self)
            if dialog.exec():
                self._refresh_actions_list()

    def _show_action_context_menu(self, pos):
        item = self._actions_list.itemAt(pos)
        if not item:
            return

        action_id = item.data(Qt.ItemDataRole.UserRole)
        action = next((a for a in self.config_manager.config.actions if a.id == action_id), None)
        if not action:
            return

        menu = QMenu(self)
        edit_action = menu.addAction("编辑")
        edit_action.triggered.connect(lambda: self._edit_action(item))

        duplicate_action = menu.addAction("复制")
        duplicate_action.triggered.connect(lambda: self._duplicate_action(action))

        delete_action = menu.addAction("删除")
        delete_action.triggered.connect(lambda: self._delete_action(action))

        menu.exec(self._actions_list.mapToGlobal(pos))

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
        self._refresh_actions_list()

    def _delete_action(self, action: Action):
        reply = QMessageBox.question(
            self, "确认删除",
            f"确定要删除操作 \"{action.name}\" 吗？",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        if reply == QMessageBox.StandardButton.Yes:
            self.config_manager.delete_action(action.id)
            self._refresh_actions_list()

    def _import_actions(self):
        path, _ = QFileDialog.getOpenFileName(self, "导入操作", "", "YAML Files (*.yaml *.yml)")
        if path:
            # Import actions from file
            pass

    def _export_actions(self):
        path, _ = QFileDialog.getSaveFileName(self, "导出操作", "actions.yaml", "YAML Files (*.yaml *.yml)")
        if path:
            # Export actions to file
            pass

    def _add_category(self):
        from .category_editor import CategoryEditorDialog
        dialog = CategoryEditorDialog(self.config_manager, None, self)
        if dialog.exec():
            self._refresh_categories_list()

    def _edit_category(self, item: QListWidgetItem):
        cat_id = item.data(Qt.ItemDataRole.UserRole)
        category = next((c for c in self.config_manager.config.categories if c.id == cat_id), None)
        if category:
            from .category_editor import CategoryEditorDialog
            dialog = CategoryEditorDialog(self.config_manager, category, self)
            if dialog.exec():
                self._refresh_categories_list()

    def _import_config(self):
        path, _ = QFileDialog.getOpenFileName(self, "导入配置", "", "YAML Files (*.yaml *.yml)")
        if path:
            if self.config_manager.import_config(Path(path)):
                RinToast("配置导入成功", RinToast.Type.SUCCESS, parent=self).show_at(self.mapToGlobal(QPoint(200, 200)))
                self._load_settings()
                self._refresh_actions_list()
                self._refresh_categories_list()
            else:
                RinToast("配置导入失败", RinToast.Type.ERROR, parent=self).show_at(self.mapToGlobal(QPoint(200, 200)))

    def _export_config(self):
        path, _ = QFileDialog.getSaveFileName(self, "导出配置", "rin-launcher-config.yaml", "YAML Files (*.yaml *.yml)")
        if path:
            if self.config_manager.export(Path(path)):
                RinToast("配置导出成功", RinToast.Type.SUCCESS, parent=self).show_at(self.mapToGlobal(QPoint(200, 200)))
            else:
                RinToast("配置导出失败", RinToast.Type.ERROR, parent=self).show_at(self.mapToGlobal(QPoint(200, 200)))

    def _reset_settings(self):
        reply = QMessageBox.warning(
            self, "确认重置",
            "这将重置所有设置为默认值，且不可恢复。确定继续吗？",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        if reply == QMessageBox.StandardButton.Yes:
            self.config_manager._config = self.config_manager._create_default()
            self.config_manager.save()
            self._load_settings()
            self._refresh_actions_list()
            self._refresh_categories_list()
            RinToast("已重置为默认设置", RinToast.Type.INFO, parent=self).show_at(self.mapToGlobal(QPoint(200, 200)))

    def _open_config_folder(self):
        QDesktopServices.openUrl(f"file:///{self.config_manager.config_dir}")

    def _open_config_file(self):
        QDesktopServices.openUrl(f"file:///{self.config_manager.config_file}")

    def _restart_as_admin(self):
        from ..actions.executor import ActionExecutor
        executor = ActionExecutor(self.config_manager)
        if executor.restart_as_admin():
            self.accept()

    def _save_settings(self):
        # Update settings from UI
        self.settings.theme = {0: "system", 1: "light", 2: "dark"}[self._theme_combo.currentIndex()]
        self.settings.search_engine = self._search_engine.text()
        self.settings.grid_columns = self._grid_columns.value()
        self.settings.item_size = self._item_size.value()
        self.settings.animation_enabled = self._animation_enabled.isChecked()
        self.settings.blur_background = self._blur_background.isChecked()
        self.settings.accent_color = self._accent_picker.get_color()
        self.settings.font_family = self._font_family.text()
        self.settings.font_size = self._font_size.value()
        self.settings.admin_auto_elevate = self._admin_auto_elevate.isChecked()
        self.settings.confirm_admin_actions = self._confirm_admin.isChecked()
        self.settings.log_level = self._log_level.currentText()
        self.settings.global_hotkey = self._global_hotkey.get_hotkey()
        self.settings.show_tray = self._show_tray.isChecked()
        self.settings.start_minimized = self._start_minimized.isChecked()

        if self.config_manager.update_settings(self.settings):
            RinToast("设置已保存", RinToast.Type.SUCCESS, parent=self).show_at(self.mapToGlobal(QPoint(200, 200)))
            self.accept()
        else:
            RinToast("保存失败", RinToast.Type.ERROR, parent=self).show_at(self.mapToGlobal(QPoint(200, 200)))


# Add missing import
from PySide6.QtCore import QPoint