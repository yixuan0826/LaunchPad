import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import QtQuick.Controls 2.15 as QQC2
import RinUI

QQC2.Dialog {
    id: settingsDialog
    title: qsTr("设置")
    modal: true
    standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
    width: 820
    height: 620

    // Editing works on a detached copy; nothing is written until the user hits OK.
    property var settingsModel: ConfigManager.getSettings()
    property var actionsModel: []
    property var categoriesModel: []
    property int sectionIndex: 0

    // Editing actions/categories needs the editor dialogs owned by LauncherWindow,
    // so this dialog only announces the intent.
    signal newActionRequested()
    signal editActionRequested(var action)
    signal newCategoryRequested()
    signal editCategoryRequested(var category)

    readonly property var sections: [
        { "title": qsTr("常规"), "icon": "ic_fluent_home_20_regular", "page": generalPage },
        { "title": qsTr("外观"), "icon": "ic_fluent_palette_20_regular", "page": appearancePage },
        { "title": qsTr("动作管理"), "icon": "ic_fluent_cog_20_regular", "page": actionsPage },
        { "title": qsTr("热键"), "icon": "ic_fluent_keyboard_20_regular", "page": hotkeysPage },
        { "title": qsTr("高级"), "icon": "ic_fluent_toolbox_20_regular", "page": advancedPage },
        { "title": qsTr("关于"), "icon": "ic_fluent_info_20_regular", "page": aboutPage }
    ]

    onAboutToShow: {
        settingsModel = ConfigManager.getSettings()
        actionsModel = ConfigManager.getActions()
        categoriesModel = ConfigManager.getCategories()
        sectionIndex = 0
    }

    onAccepted: ConfigManager.updateSettings(settingsModel)

    Connections {
        target: ConfigManager

        function onConfigChanged() {
            settingsDialog.actionsModel = ConfigManager.getActions()
            settingsDialog.categoriesModel = ConfigManager.getCategories()
        }
    }

    ConfirmDialog {
        id: confirmDialog
    }

    FluentPage {
        anchors.fill: parent
        title: qsTr("设置")
        spacing: 20
        padding: 24

        // FluentPage's content area is a ColumnLayout, so the two-pane layout has
        // to live inside a plain Item.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 460

            Column {
                id: sidebar
                width: 200
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                spacing: 4

                Repeater {
                    model: settingsDialog.sections

                    delegate: SettingCard {
                        width: sidebar.width
                        title: modelData.title
                        description: ""
                        icon.name: modelData.icon
                        icon.color: index === settingsDialog.sectionIndex
                            ? Theme.currentTheme.colors.primaryColor
                            : Theme.currentTheme.colors.textColor
                        clickable: true
                        onClicked: settingsDialog.sectionIndex = index
                    }
                }
            }

            Loader {
                anchors.left: sidebar.right
                anchors.leftMargin: 24
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                sourceComponent: settingsDialog.sections[settingsDialog.sectionIndex].page
            }
        }
    }

    // ------------------------------------------------------------------
    // 常规
    // ------------------------------------------------------------------
    Component {
        id: generalPage

        FluentPage {
            title: qsTr("常规")
            spacing: 20

            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("启动行为")
                icon.name: "ic_fluent_play_20_regular"
                expanded: true

                SettingItem {
                    title: qsTr("开机自动启动")
                    Switch {
                        checked: settingsDialog.settingsModel.autoStart
                        onCheckedChanged: settingsDialog.settingsModel.autoStart = checked
                    }
                }
                SettingItem {
                    title: qsTr("启动时最小化到托盘")
                    Switch {
                        checked: settingsDialog.settingsModel.startMinimized
                        onCheckedChanged: settingsDialog.settingsModel.startMinimized = checked
                    }
                }
                SettingItem {
                    title: qsTr("显示系统托盘图标")
                    Switch {
                        checked: settingsDialog.settingsModel.showTray
                        onCheckedChanged: settingsDialog.settingsModel.showTray = checked
                    }
                }
            }

            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("搜索设置")
                icon.name: "ic_fluent_search_20_regular"
                expanded: true

                SettingItem {
                    title: qsTr("默认搜索引擎")
                    TextField {
                        width: 400
                        placeholderText: qsTr("使用 {query} 作为占位符")
                        text: settingsDialog.settingsModel.searchEngine
                        onTextChanged: settingsDialog.settingsModel.searchEngine = text
                    }
                }
            }

            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("启动台布局")
                icon.name: "ic_fluent_grid_20_regular"
                expanded: true

                SettingItem {
                    title: qsTr("网格列数")
                    Slider {
                        id: columnsSlider
                        width: 200
                        from: 3
                        to: 12
                        stepSize: 1
                        value: settingsDialog.settingsModel.gridColumns
                        onValueChanged: settingsDialog.settingsModel.gridColumns = Math.round(value)
                    }
                    Text { text: Math.round(columnsSlider.value) }
                }
                SettingItem {
                    title: qsTr("图标大小")
                    Slider {
                        id: iconSizeSlider
                        width: 200
                        from: 64
                        to: 144
                        stepSize: 8
                        value: settingsDialog.settingsModel.itemSize
                        onValueChanged: settingsDialog.settingsModel.itemSize = Math.round(value)
                    }
                    Text { text: Math.round(iconSizeSlider.value) + " px" }
                }
                SettingItem {
                    title: qsTr("启用动画效果")
                    Switch {
                        checked: settingsDialog.settingsModel.animationEnabled
                        onCheckedChanged: settingsDialog.settingsModel.animationEnabled = checked
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // 外观
    // ------------------------------------------------------------------
    Component {
        id: appearancePage

        FluentPage {
            title: qsTr("外观")
            spacing: 20

            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("主题")
                icon.name: "ic_fluent_color_20_regular"
                expanded: true

                SettingItem {
                    title: qsTr("主题模式")
                    ComboBox {
                        width: 200
                        model: [qsTr("跟随系统"), qsTr("浅色"), qsTr("深色")]
                        currentIndex: ["system", "light", "dark"].indexOf(settingsDialog.settingsModel.theme)
                        onCurrentIndexChanged: settingsDialog.settingsModel.theme =
                            ["system", "light", "dark"][currentIndex]
                    }
                }
                SettingItem {
                    title: qsTr("启用背景模糊")
                    Switch {
                        checked: settingsDialog.settingsModel.blurBackground
                        onCheckedChanged: settingsDialog.settingsModel.blurBackground = checked
                    }
                }
            }

            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("强调色")
                icon.name: "ic_fluent_paint_brush_20_regular"
                expanded: true

                SettingItem {
                    title: qsTr("强调色")
                    DropDownColorPicker {
                        id: accentPicker
                        color: settingsDialog.settingsModel.accentColor
                        onColorChanged: settingsDialog.settingsModel.accentColor = color
                    }
                    ToolButton {
                        icon.name: "ic_fluent_arrow_reset_20_regular"
                        ToolTip.text: qsTr("重置")
                        onClicked: {
                            accentPicker.color = "#0078d4"
                            settingsDialog.settingsModel.accentColor = accentPicker.color
                        }
                    }
                }
            }

            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("字体")
                icon.name: "ic_fluent_text_font_20_regular"
                expanded: true

                SettingItem {
                    title: qsTr("字体")
                    TextField {
                        width: 300
                        text: settingsDialog.settingsModel.fontFamily
                        onTextChanged: settingsDialog.settingsModel.fontFamily = text
                    }
                }
                SettingItem {
                    title: qsTr("字体大小")
                    Slider {
                        id: fontSizeSlider
                        width: 200
                        from: 8
                        to: 24
                        stepSize: 1
                        value: settingsDialog.settingsModel.fontSize
                        onValueChanged: settingsDialog.settingsModel.fontSize = Math.round(value)
                    }
                    Text { text: Math.round(fontSizeSlider.value) + " pt" }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // 动作管理
    // ------------------------------------------------------------------
    Component {
        id: actionsPage

        FluentPage {
            title: qsTr("动作管理")
            spacing: 20

            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("操作列表")
                icon.name: "ic_fluent_list_20_regular"
                expanded: true

                Row {
                    Layout.fillWidth: true
                    spacing: 8
                    Button {
                        text: qsTr("新建操作")
                        highlighted: true
                        icon.name: "ic_fluent_add_20_regular"
                        onClicked: settingsDialog.newActionRequested()
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    height: 280
                    clip: true
                    model: settingsDialog.actionsModel

                    delegate: SettingCard {
                        width: ListView.view.width
                        title: modelData.name
                        description: modelData.type + " - " + modelData.category
                        icon.name: modelData.icon || ""

                        Row {
                            spacing: 8
                            Button {
                                text: qsTr("编辑")
                                onClicked: settingsDialog.editActionRequested(modelData)
                            }
                            Button {
                                text: qsTr("删除")
                                flat: true
                                onClicked: confirmDialog.ask(
                                    qsTr("确定要删除操作“%1”吗？").arg(modelData.name),
                                    function() { ConfigManager.deleteAction(modelData.id) })
                            }
                        }
                    }
                }
            }

            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("分类管理")
                icon.name: "ic_fluent_folder_20_regular"
                expanded: true

                Row {
                    Layout.fillWidth: true
                    spacing: 8
                    Button {
                        text: qsTr("新建分类")
                        highlighted: true
                        icon.name: "ic_fluent_add_20_regular"
                        onClicked: settingsDialog.newCategoryRequested()
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    height: 200
                    clip: true
                    model: settingsDialog.categoriesModel

                    delegate: SettingCard {
                        width: ListView.view.width
                        title: modelData.name
                        description: qsTr("顺序: %1").arg(modelData.order)
                        icon.name: modelData.icon || ""

                        Row {
                            spacing: 8
                            Button {
                                text: qsTr("编辑")
                                onClicked: settingsDialog.editCategoryRequested(modelData)
                            }
                            Button {
                                text: qsTr("删除")
                                flat: true
                                onClicked: confirmDialog.ask(
                                    qsTr("确定要删除分类“%1”吗？").arg(modelData.name),
                                    function() { ConfigManager.deleteCategory(modelData.id) })
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // 热键
    // ------------------------------------------------------------------
    Component {
        id: hotkeysPage

        FluentPage {
            title: qsTr("热键")
            spacing: 20

            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("全局热键")
                icon.name: "ic_fluent_magic_wand_20_regular"
                expanded: true

                SettingItem {
                    title: qsTr("显示/隐藏启动台")
                    TextField {
                        width: 300
                        readOnly: true
                        placeholderText: qsTr("点击输入热键...")
                        text: settingsDialog.settingsModel.globalHotkey
                    }
                }
                SettingItem {
                    showDivider: false
                    Text {
                        wrapMode: Text.Wrap
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("提示: 点击输入框后按下任意组合键设置热键。修改后需重启应用生效。")
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // 高级
    // ------------------------------------------------------------------
    Component {
        id: advancedPage

        FluentPage {
            title: qsTr("高级")
            spacing: 20

            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("管理员权限")
                icon.name: "ic_fluent_shield_20_regular"
                expanded: true

                SettingItem {
                    title: qsTr("自动提权执行管理员操作")
                    Switch {
                        checked: settingsDialog.settingsModel.adminAutoElevate
                        onCheckedChanged: settingsDialog.settingsModel.adminAutoElevate = checked
                    }
                }
                SettingItem {
                    title: qsTr("执行管理员操作前确认")
                    Switch {
                        checked: settingsDialog.settingsModel.confirmAdminActions
                        onCheckedChanged: settingsDialog.settingsModel.confirmAdminActions = checked
                    }
                }
                SettingItem {
                    title: qsTr("以管理员身份重启")
                    Button {
                        text: qsTr("立即重启")
                        flat: true
                        icon.name: "ic_fluent_restart_20_regular"
                        onClicked: ConfigManager.restartAsAdmin()
                    }
                }
            }

            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("配置管理")
                icon.name: "ic_fluent_database_20_regular"
                expanded: true

                SettingItem {
                    title: qsTr("配置文件")
                    Row {
                        spacing: 8
                        Button {
                            text: qsTr("打开文件夹")
                            icon.name: "ic_fluent_folder_open_20_regular"
                            onClicked: ConfigManager.openConfigFolder()
                        }
                        Button {
                            text: qsTr("打开文件")
                            icon.name: "ic_fluent_file_20_regular"
                            onClicked: ConfigManager.openConfigFile()
                        }
                    }
                }
                SettingItem {
                    title: qsTr("导入 / 导出")
                    Row {
                        spacing: 8
                        Button {
                            text: qsTr("导入")
                            icon.name: "ic_fluent_import_20_regular"
                            onClicked: ConfigManager.importConfig()
                        }
                        Button {
                            text: qsTr("导出")
                            icon.name: "ic_fluent_export_20_regular"
                            onClicked: ConfigManager.exportConfig()
                        }
                    }
                }
                SettingItem {
                    title: qsTr("重置所有设置")
                    Button {
                        text: qsTr("重置")
                        flat: true
                        icon.name: "ic_fluent_arrow_reset_20_regular"
                        onClicked: confirmDialog.ask(
                            qsTr("这将重置所有设置为默认值，且不可恢复。确定继续吗？"),
                            function() { ConfigManager.resetToDefaults() })
                    }
                }
                SettingItem {
                    title: qsTr("日志级别")
                    ComboBox {
                        width: 200
                        model: ["DEBUG", "INFO", "WARNING", "ERROR"]
                        currentIndex: ["DEBUG", "INFO", "WARNING", "ERROR"]
                            .indexOf(settingsDialog.settingsModel.logLevel)
                        onCurrentIndexChanged: settingsDialog.settingsModel.logLevel =
                            ["DEBUG", "INFO", "WARNING", "ERROR"][currentIndex]
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // 关于
    // ------------------------------------------------------------------
    Component {
        id: aboutPage

        FluentPage {
            title: qsTr("关于")
            spacing: 20

            SettingCard {
                Layout.fillWidth: true
                title: qsTr("Rin Launcher")
                description: qsTr("类似希沃桌面助手的启动台应用")
                icon.name: "\ueb95"
                icon.size: 48
            }

            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("链接")
                icon.name: "ic_fluent_link_20_regular"
                expanded: true

                SettingItem {
                    title: qsTr("GitHub 仓库")
                    showDivider: false
                    actionIcon.name: "ic_fluent_open_20_regular"
                    clickable: true
                    onClicked: Qt.openUrlExternally("https://github.com/yixuan0826/LaunchPad")
                }
            }

            SettingExpander {
                Layout.fillWidth: true
                title: qsTr("许可证")
                icon.name: "ic_fluent_shield_20_regular"
                expanded: true

                SettingItem {
                    title: qsTr("GPL-3.0-or-later")
                    showDivider: false
                    Hyperlink {
                        text: qsTr("查看完整许可证")
                        openUrl: "https://www.gnu.org/licenses/gpl-3.0.html"
                    }
                }
            }

            SettingItem {
                showDivider: false
                Text {
                    color: Theme.currentTheme.colors.textSecondaryColor
                    text: qsTr("版本: 1.0.0")
                }
            }
        }
    }
}
