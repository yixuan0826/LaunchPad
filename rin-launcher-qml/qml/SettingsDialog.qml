import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

Dialog {
    id: settingsDialog
    title: qsTr("设置")
    modal: true
    standardButtons: Dialog.Ok | Dialog.Cancel
    width: 800
    height: 600
    
    property var ConfigManager: null
    signal settingsChanged()
    
    onAccepted: {
        ConfigManager.updateSettings(settingsModel)
        settingsChanged()
    }
    
    // Settings model
    property var settingsModel: QtObject {
        property string theme: "system"
        property string language: "zh_CN"
        property bool showTray: true
        property bool startMinimized: false
        property bool autoStart: false
        property string globalHotkey: "Ctrl+Space"
        property string searchEngine: "https://www.bing.com/search?q={query}"
        property int gridColumns: 6
        property int itemSize: 96
        property bool animationEnabled: true
        property bool blurBackground: true
        property string accentColor: "#0078d4"
        property string fontFamily: "Microsoft YaHei UI"
        property int fontSize: 12
        property bool adminAutoElevate: true
        property bool confirmAdminActions: true
        property string logLevel: "INFO"
    }
    
    FluentPage {
        id: settingsPage
        title: qsTr("设置")
        spacing: 20
        padding: 24
        
        // Sidebar navigation
        Column {
            id: sidebar
            width: 200
            spacing: 4
            
            SettingCard {
                title: qsTr("常规")
                icon.name: "ic_fluent_home_20_regular"
                clickable: true
                onClicked: stackView.push(generalSettingsComponent)
            }
            SettingCard {
                title: qsTr("外观")
                icon.name: "ic_fluent_palette_20_regular"
                clickable: true
                onClicked: stackView.push(appearanceSettingsComponent)
            }
            SettingCard {
                title: qsTr("动作管理")
                icon.name: "ic_fluent_cog_20_regular"
                clickable: true
                onClicked: stackView.push(actionsSettingsComponent)
            }
            SettingCard {
                title: qsTr("热键")
                icon.name: "ic_fluent_keyboard_20_regular"
                clickable: true
                onClicked: stackView.push(hotkeysSettingsComponent)
            }
            SettingCard {
                title: qsTr("高级")
                icon.name: "ic_fluent_toolbox_20_regular"
                clickable: true
                onClicked: stackView.push(advancedSettingsComponent)
            }
            SettingCard {
                title: qsTr("关于")
                icon.name: "ic_fluent_info_20_regular"
                clickable: true
                onClicked: stackView.push(aboutSettingsComponent)
            }
        }
        
        // Content stack
        StackView {
            id: stackView
            width: parent.width - sidebar.width - 24
            anchors.left: sidebar.right
            anchors.leftMargin: 24
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            initialItem: generalSettingsComponent
        }
    }
    
    // General Settings Page
    Component {
        id: generalSettingsComponent
        FluentPage {
            title: qsTr("常规")
            spacing: 20
            
            // Startup Behavior
            SettingExpander {
                width: parent.width
                title: qsTr("启动行为")
                icon.name: "ic_fluent_play_20_regular"
                expanded: true
                content: Column {
                    width: parent.width
                    spacing: 8
                    
                    SettingItem {
                        title: qsTr("开机自动启动")
                        Switch {
                            checked: settingsModel.autoStart
                            onCheckedChanged: {
                                settingsModel.autoStart = checked
                                ConfigManager.setAutoStart(checked)
                            }
                        }
                    }
                    SettingItem {
                        title: qsTr("启动时最小化到托盘")
                        Switch {
                            checked: settingsModel.startMinimized
                            onCheckedChanged: settingsModel.startMinimized = checked
                        }
                    }
                    SettingItem {
                        title: qsTr("显示系统托盘图标")
                        Switch {
                            checked: settingsModel.showTray
                            onCheckedChanged: settingsModel.showTray = checked
                        }
                    }
                }
            }
            
            // Search Settings
            SettingExpander {
                width: parent.width
                title: qsTr("搜索设置")
                icon.name: "ic_fluent_search_20_regular"
                expanded: true
                content: Column {
                    width: parent.width
                    spacing: 8
                    
                    SettingItem {
                        title: qsTr("默认搜索引擎")
                        TextField {
                            width: 400
                            text: settingsModel.searchEngine
                            placeholderText: "使用 {query} 作为占位符"
                            onTextChanged: settingsModel.searchEngine = text
                        }
                    }
                }
            }
            
            // Layout Settings
            SettingExpander {
                width: parent.width
                title: qsTr("启动台布局")
                icon.name: "ic_fluent_grid_20_regular"
                expanded: true
                content: Column {
                    width: parent.width
                    spacing: 12
                    
                    SettingItem {
                        title: qsTr("网格列数")
                        Slider {
                            width: 200
                            from: 3
                            to: 12
                            stepSize: 1
                            value: settingsModel.gridColumns
                            onValueChanged: settingsModel.gridColumns = Math.round(value)
                        }
                        Text { text: settingsModel.gridColumns }
                    }
                    
                    SettingItem {
                        title: qsTr("图标大小")
                        Slider {
                            width: 200
                            from: 64
                            to: 144
                            stepSize: 8
                            value: settingsModel.itemSize
                            onValueChanged: settingsModel.itemSize = Math.round(value)
                        }
                        Text { text: settingsModel.itemSize + " px" }
                    }
                    
                    SettingItem {
                        title: qsTr("启用动画效果")
                        Switch {
                            checked: settingsModel.animationEnabled
                            onCheckedChanged: settingsModel.animationEnabled = checked
                        }
                    }
                }
            }
        }
    }
    
    // Appearance Settings Page
    Component {
        id: appearanceSettingsComponent
        FluentPage {
            title: qsTr("外观")
            spacing: 20
            
            SettingExpander {
                width: parent.width
                title: qsTr("主题")
                icon.name: "ic_fluent_color_20_regular"
                expanded: true
                content: Column {
                    width: parent.width
                    spacing: 12
                    
                    SettingItem {
                        title: qsTr("主题模式")
                        ComboBox {
                            width: 200
                            model: [qsTr("跟随系统"), qsTr("浅色"), qsTr("深色")]
                            currentIndex: ["system", "light", "dark"].indexOf(settingsModel.theme)
                            onCurrentIndexChanged: settingsModel.theme = ["system", "light", "dark"][currentIndex]
                        }
                    }
                    
                    SettingItem {
                        title: qsTr("启用背景模糊")
                        Switch {
                            checked: settingsModel.blurBackground
                            onCheckedChanged: settingsModel.blurBackground = checked
                        }
                    }
                }
            }
            
            SettingExpander {
                width: parent.width
                title: qsTr("强调色")
                icon.name: "ic_fluent_paint_brush_20_regular"
                expanded: true
                content: Column {
                    width: parent.width
                    spacing: 12
                    
                    SettingItem {
                        title: qsTr("强调色")
                        Row {
                            spacing: 12
                            DropDownColorPicker {
                                id: accentPicker
                                color: settingsModel.accentColor
                                onColorChanged: settingsModel.accentColor = color
                            }
                            ToolButton {
                                icon.name: "ic_fluent_arrow_reset_20_regular"
                                ToolTip.text: qsTr("重置")
                                onClicked: accentPicker.color = "#0078d4"
                            }
                        }
                    }
                }
            }
            
            SettingExpander {
                width: parent.width
                title: qsTr("字体")
                icon.name: "ic_fluent_text_font_20_regular"
                expanded: true
                content: Column {
                    width: parent.width
                    spacing: 12
                    
                    SettingItem {
                        title: qsTr("字体")
                        TextField {
                            width: 300
                            text: settingsModel.fontFamily
                            onTextChanged: settingsModel.fontFamily = text
                        }
                    }
                    
                    SettingItem {
                        title: qsTr("字体大小")
                        Slider {
                            width: 200
                            from: 8
                            to: 24
                            stepSize: 1
                            value: settingsModel.fontSize
                            onValueChanged: settingsModel.fontSize = Math.round(value)
                        }
                        Text { text: settingsModel.fontSize + " pt" }
                    }
                }
            }
        }
    }
    
    // Actions Settings Page
    Component {
        id: actionsSettingsComponent
        FluentPage {
            title: qsTr("动作管理")
            spacing: 20
            
            SettingExpander {
                width: parent.width
                title: qsTr("操作列表")
                icon.name: "ic_fluent_list_20_regular"
                expanded: true
                content: Column {
                    width: parent.width
                    spacing: 12
                    
                    Row {
                        spacing: 8
                        Button {
                            text: qsTr("新建操作")
                            highlighted: true
                            icon.name: "ic_fluent_add_20_regular"
                            onClicked: {
                                actionEditorDialog.newAction()
                            }
                        }
                        Button {
                            text: qsTr("导入操作")
                            icon.name: "ic_fluent_download_20_regular"
                            onClicked: {
                                // TODO: Import actions
                            }
                        }
                        Button {
                            text: qsTr("导出操作")
                            icon.name: "ic_fluent_upload_20_regular"
                            onClicked: {
                                // TODO: Export actions
                            }
                        }
                    }
                    
                    ListView {
                        width: parent.width
                        height: 300
                        model: ConfigManager.getActions()
                        delegate: SettingCard {
                            width: parent.width
                            title: modelData.name
                            description: modelData.type + " - " + modelData.category
                            icon.name: modelData.icon || "\ueb95"
                            clickable: true
                            onClicked: actionEditorDialog.editAction(modelData)
                            
                            content: Row {
                                spacing: 8
                                Button {
                                    text: qsTr("编辑")
                                    
                                    onClicked: actionEditorDialog.editAction(modelData)
                                }
                                Button {
                                    text: qsTr("删除")
                                    flat: true
                                    
                                    onClicked: {
                                        var msg = Qt.createQmlObject('import QtQuick.Controls 2.15; MessageDialog { title: "确认删除"; text: "确定要删除操作 \\"" + modelData.name + qsTr("\\" 吗？"); standardButtons: MessageDialog.Yes | MessageDialog.No; onAccepted: ConfigManager.deleteAction(modelData.id); }', actionEditorDialog)
                                        msg.open()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            SettingExpander {
                width: parent.width
                title: qsTr("分类管理")
                icon.name: "ic_fluent_folder_20_regular"
                expanded: true
                content: Column {
                    width: parent.width
                    spacing: 12
                    
                    Row {
                        spacing: 8
                        Button {
                            text: qsTr("新建分类")
                            highlighted: true
                            icon.name: "ic_fluent_add_20_regular"
                            onClicked: categoryEditorDialog.newCategory()
                        }
                    }
                    
                    ListView {
                        width: parent.width
                        height: 200
                        model: ConfigManager.getCategories()
                        delegate: SettingCard {
                            width: parent.width
                            title: modelData.name
                            description: "顺序: " + modelData.order
                            icon.name: modelData.icon || "\ueb8f"
                            clickable: true
                            onClicked: categoryEditorDialog.editCategory(modelData)
                            
                            content: Row {
                                spacing: 8
                                Button {
                                    text: qsTr("编辑")
                                    
                                    onClicked: categoryEditorDialog.editCategory(modelData)
                                }
                                Button {
                                    text: qsTr("删除")
                                    flat: true
                                    
                                    onClicked: {
                                        var msg = Qt.createQmlObject('import QtQuick.Controls 2.15; MessageDialog { title: "确认删除"; text: "确定要删除分类 \\"" + modelData.name + qsTr("\\" 吗？"); standardButtons: MessageDialog.Yes | MessageDialog.No; onAccepted: ConfigManager.deleteCategory(modelData.id); }', categoryEditorDialog)
                                        msg.open()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Hotkeys Settings Page
    Component {
        id: hotkeysSettingsComponent
        FluentPage {
            title: qsTr("热键")
            spacing: 20
            
            SettingExpander {
                width: parent.width
                title: qsTr("全局热键")
                icon.name: "ic_fluent_magic_wand_20_regular"
                expanded: true
                content: Column {
                    width: parent.width
                    spacing: 12
                    
                    SettingItem {
                        title: qsTr("显示/隐藏启动台")
                        TextField {
                            id: hotkeyField
                            width: 300
                            readOnly: true
                            text: settingsModel.globalHotkey
                            placeholderText: "点击输入热键..."
                            MouseArea {
                                anchors.fill: parent
                                onClicked: startHotkeyRecording()
                            }
                        }
                    }
                    
                    SettingItem {
                        Text {
                            text: qsTr("提示: 点击输入框后按下任意组合键设置热键。修改后需重启应用生效。")
                            color: Theme.currentTheme.colors.textSecondaryColor
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }
    
    // Advanced Settings Page
    Component {
        id: advancedSettingsComponent
        FluentPage {
            title: qsTr("高级")
            spacing: 20
            
            SettingExpander {
                width: parent.width
                title: qsTr("管理员权限")
                icon.name: "ic_fluent_shield_20_regular"
                expanded: true
                content: Column {
                    width: parent.width
                    spacing: 12
                    
                    SettingItem {
                        title: qsTr("自动提权执行管理员操作")
                        Switch {
                            checked: settingsModel.adminAutoElevate
                            onCheckedChanged: settingsModel.adminAutoElevate = checked
                        }
                    }
                    SettingItem {
                        title: qsTr("执行管理员操作前确认")
                        Switch {
                            checked: settingsModel.confirmAdminActions
                            onCheckedChanged: settingsModel.confirmAdminActions = checked
                        }
                    }
                    
                    SettingItem {
                        Button {
                            text: qsTr("以管理员身份重启")
                            flat: true
                            icon.name: "ic_fluent_restart_20_regular"
                            onClicked: ConfigManager.restartAsAdmin()
                        }
                    }
                }
            }
            
            SettingExpander {
                width: parent.width
                title: qsTr("配置管理")
                icon.name: "ic_fluent_database_20_regular"
                expanded: true
                content: Column {
                    width: parent.width
                    spacing: 12
                    
                    Row {
                        spacing: 8
                        Button {
                            text: qsTr("打开配置文件夹")
                            icon.name: "ic_fluent_folder_open_20_regular"
                            onClicked: ConfigManager.openConfigFolder()
                        }
                        Button {
                            text: qsTr("打开配置文件")
                            icon.name: "ic_fluent_file_20_regular"
                            onClicked: ConfigManager.openConfigFile()
                        }
                    }
                    
                    Row {
                        spacing: 8
                        Button {
                            text: qsTr("导入配置")
                            icon.name: "ic_fluent_import_20_regular"
                            onClicked: ConfigManager.importConfig()
                        }
                        Button {
                            text: qsTr("导出配置")
                            icon.name: "ic_fluent_export_20_regular"
                            onClicked: ConfigManager.exportConfig()
                        }
                    }
                    
                    Row {
                        spacing: 8
                        Button {
                            text: qsTr("重置所有设置")
                            flat: true
                            icon.name: "ic_fluent_arrow_reset_20_regular"
                            onClicked: {
                                var msg = Qt.createQmlObject('import QtQuick.Controls 2.15; MessageDialog { title: "确认重置"; text: "这将重置所有设置为默认值，且不可恢复。确定继续吗？"; standardButtons: MessageDialog.Yes | MessageDialog.No; onAccepted: ConfigManager.resetToDefaults(); }', settingsDialog)
                                msg.open()
                            }
                        }
                    }
                }
            }
            
            SettingExpander {
                width: parent.width
                title: qsTr("日志")
                icon.name: "ic_fluent_document_20_regular"
                expanded: true
                content: Column {
                    width: parent.width
                    spacing: 12
                    
                    SettingItem {
                        title: qsTr("日志级别")
                        ComboBox {
                            width: 200
                            model: ["DEBUG", "INFO", "WARNING", "ERROR"]
                            currentIndex: ["DEBUG", "INFO", "WARNING", "ERROR"].indexOf(settingsModel.logLevel)
                            onCurrentIndexChanged: settingsModel.logLevel = ["DEBUG", "INFO", "WARNING", "ERROR"][currentIndex]
                        }
                    }
                }
            }
        }
    }
    
    // About Settings Page
    Component {
        id: aboutSettingsComponent
        FluentPage {
            title: qsTr("关于")
            spacing: 20
            
            SettingCard {
                width: parent.width
                title: qsTr("Rin Launcher")
                description: qsTr("类似希沃桌面助手的启动台应用")
                icon.name: "\ueb95"
                icon.size: 48
            }
            
            SettingItem {
                Text {
                    text: qsTr("版本: 1.0.0")
                    color: Theme.currentTheme.colors.textSecondaryColor
                }
            }
            
            SettingExpander {
                width: parent.width
                title: qsTr("链接")
                icon.name: "ic_fluent_link_20_regular"
                expanded: true
                content: Column {
                    width: parent.width
                    spacing: 8
                    
                    SettingItem {
                        title: qsTr("GitHub 仓库")
                        actionIcon.name: "ic_fluent_open_20_regular"
                        clickable: true
                        onClicked: Qt.openUrlExternally("https://github.com")
                    }
                    SettingItem {
                        title: qsTr("问题反馈")
                        actionIcon.name: "ic_fluent_bug_20_regular"
                        clickable: true
                        onClicked: Qt.openUrlExternally("https://github.com/issues")
                    }
                }
            }
            
            SettingExpander {
                width: parent.width
                title: qsTr("许可证")
                icon.name: "ic_fluent_shield_20_regular"
                expanded: true
                content: Column {
                    width: parent.width
                    spacing: 8
                    
                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("本软件基于 GPL-3.0-or-later 许可证开源发布。您可以自由使用、修改和分发本软件。")
                    }
                    
                    SettingItem {
                        Hyperlink {
                            text: qsTr("查看完整许可证")
                            openUrl: "https://www.gnu.org/licenses/gpl-3.0.html"
                        }
                    }
                }
            }
        }
    }
    
    function startHotkeyRecording() {
        hotkeyField.text = "按下热键组合..."
        hotkeyField.property = "recording"
        // TODO: Implement actual hotkey recording
    }
}