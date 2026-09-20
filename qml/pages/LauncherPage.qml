import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import QtQuick.Window 2.15
import RinUI

import "../components"
import "../dialogs"

// 启动台。
//
// 版式参考希沃桌面助手的侧边栏：软件区（应用快捷方式）、工具区（批注/截图一类
// 的快捷工具）、简易功能设置区（节能、护眼等一键开关）三段纵向排布。这里是同一
// 思路在 RinUI 上的落地 —— 三段都放在一个滚动区里，顶部固定搜索与新建入口。
Item {
    id: launcherPage

    property var sections: []          // [{categoryName, categoryIcon, actions}]
    property var allActions: []        // 扁平条目，供搜索联想
    property bool searching: false
    property int tileSize: 96
    property int gridColumns: 6
    property bool allCollapsed: false  // 一键折叠/展开全部分区

    // 工具区用的是 RinUI 的 Button，图标只能走 Fluent 字体图标；Lawnicons 只在
    // AppIcon（分区标题、条目卡片、设置分组）里出现。
    readonly property var tools: [
        { "title": qsTr("打开配置目录"), "icon": "ic_fluent_folder_open_20_regular",
          "kind": "configFolder" },
        { "title": qsTr("重新加载配置"), "icon": "ic_fluent_arrow_sync_20_regular",
          "kind": "reload" },
        { "title": qsTr("档案管理"), "icon": "ic_fluent_book_20_regular",
          "kind": "records" },
        { "title": qsTr("设置"), "icon": "ic_fluent_settings_20_regular",
          "kind": "settings" },
        { "title": qsTr("以管理员身份重启"), "icon": "ic_fluent_shield_20_regular",
          "kind": "elevate" }
    ]

    EntryEditorDialog {
        id: entryEditor
        onSaved: launcherPage.reload()
    }

    ConfirmDialog {
        id: confirmDialog
    }

    // 条目右键菜单。position 必须是 None，否则 RinUI 的 Menu 会按锚点重新计算
    // posX/posY，把 popup() 指定的坐标覆盖掉。
    Menu {
        id: entryMenu
        position: Position.None

        property var entry: null

        MenuItem {
            text: qsTr("打开")
            icon.name: "ic_fluent_open_20_regular"
            onTriggered: launcherPage.runEntry(entryMenu.entry)
        }
        MenuItem {
            text: qsTr("以管理员身份打开")
            icon.name: "ic_fluent_shield_20_regular"
            visible: entryMenu.entry
                && (entryMenu.entry.type === "file" || entryMenu.entry.type === "cmd")
            onTriggered: launcherPage.runEntryAsAdmin(entryMenu.entry)
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("编辑…")
            icon.name: "ic_fluent_edit_20_regular"
            onTriggered: entryEditor.editEntry(entryMenu.entry)
        }
        MenuItem {
            text: qsTr("复制一份")
            icon.name: "ic_fluent_copy_20_regular"
            onTriggered: ConfigManager.duplicateAction(entryMenu.entry)
        }
        MenuItem {
            text: entryMenu.entry && entryMenu.entry.enabled === false ? qsTr("启用") : qsTr("停用")
            icon.name: "ic_fluent_eye_20_regular"
            onTriggered: ConfigManager.toggleAction(
                entryMenu.entry.id, entryMenu.entry.enabled === false)
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("上移")
            icon.name: "ic_fluent_arrow_up_20_regular"
            onTriggered: ConfigManager.moveAction(entryMenu.entry.id, -1)
        }
        MenuItem {
            text: qsTr("下移")
            icon.name: "ic_fluent_arrow_down_20_regular"
            onTriggered: ConfigManager.moveAction(entryMenu.entry.id, 1)
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("删除…")
            icon.name: "ic_fluent_delete_20_regular"
            onTriggered: launcherPage.confirmDelete(entryMenu.entry)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── 顶部：搜索 + 入口 ──
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 12

            TextField {
                id: searchField
                Layout.fillWidth: true
                Layout.maximumWidth: 520
                placeholderText: qsTr("搜索应用、文件、命令…")
                clearEnabled: true
                onTextChanged: launcherPage.applyFilter(text)
            }

            Button {
                text: qsTr("新建条目")
                icon.name: "ic_fluent_add_20_regular"
                highlighted: true
                onClicked: entryEditor.newEntry("")
            }

            Item { Layout.fillWidth: true }

            ToolButton {
                icon.name: "ic_fluent_arrow_minimize_20_regular"
                ToolTip.text: launcherPage.allCollapsed ? qsTr("展开全部分区") : qsTr("折叠全部分区")
                onClicked: launcherPage.allCollapsed = !launcherPage.allCollapsed
            }

            ToolButton {
                icon.name: "ic_fluent_arrow_sync_20_regular"
                ToolTip.text: qsTr("重新加载配置")
                onClicked: ConfigManager.reloadConfig()
            }
        }

        // ── 滚动内容：软件区 / 工具区 / 简易设置 ──
        Flickable {
            id: scroller
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: contentColumn.implicitHeight + 28
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: contentColumn
                x: 16
                width: scroller.width - 32
                spacing: 12

                // ── 软件区 ──
                ZoneHeader {
                    iconKey: "ic_fluent_apps_20_regular"
                    title: qsTr("软件区")
                    trailing: qsTr("%1 个条目").arg(launcherPage.allActions.length)
                }

                Repeater {
                    model: launcherPage.sections

                    delegate: CategorySection {
                        id: sectionItem

                        Layout.fillWidth: true
                        Layout.maximumWidth: sectionItem.maxGridWidth
                        categoryName: modelData.categoryName
                        categoryIcon: modelData.categoryIcon
                        entries: modelData.actions
                        tileSize: launcherPage.tileSize
                        columns: launcherPage.gridColumns
                        collapsed: launcherPage.allCollapsed
                        onEntryActivated: launcherPage.runEntry(entry)
                        onEntryMenuRequested: launcherPage.showEntryMenu(entry, sceneX, sceneY)
                    }
                }

                // 空状态
                Frame {
                    Layout.fillWidth: true
                    implicitHeight: 140
                    visible: launcherPage.sections.length === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        AppIcon {
                            Layout.alignment: Qt.AlignHCenter
                            iconKey: "ic_fluent_search_20_regular"
                            iconSize: 28
                            tint: Theme.currentTheme.colors.textSecondaryColor
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            color: Theme.currentTheme.colors.textSecondaryColor
                            text: launcherPage.searching
                                ? qsTr("没有匹配的条目")
                                : qsTr("启动台还是空的，先新建一个条目吧")
                        }
                    }
                }

                // ── 工具区 ──
                ZoneHeader {
                    Layout.topMargin: 8
                    iconKey: "ic_fluent_wrench_20_regular"
                    title: qsTr("工具区")
                    trailing: qsTr("常用命令与跳转")
                }

                Frame {
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Flow {
                            Layout.fillWidth: true
                            Layout.preferredHeight: childrenRect.height
                            spacing: 8

                            Repeater {
                                model: launcherPage.tools

                                delegate: Button {
                                    text: modelData.title
                                    icon.name: modelData.icon
                                    onClicked: launcherPage.runTool(modelData.kind)
                                }
                            }
                        }
                    }
                }

                // ── 简易功能设置区 ──
                ZoneHeader {
                    Layout.topMargin: 8
                    iconKey: "ic_fluent_settings_20_regular"
                    title: qsTr("简易设置")
                    trailing: qsTr("改动立即生效")
                }

                Frame {
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10

                        FormRow {
                            label: qsTr("主题模式")
                            ComboBox {
                                id: themeCombo
                                Layout.preferredWidth: 160
                                model: [qsTr("跟随系统"), qsTr("浅色"), qsTr("深色")]
                                // 用 Connections 而不是 onCurrentIndexChanged，避免覆盖
                                // RinUI ComboBox 内部用于同步下拉高亮的同名处理函数。
                                Connections {
                                    target: themeCombo
                                    function onCurrentIndexChanged() {
                                        if (themeCombo.currentIndex >= 0) {
                                            launcherPage.setSetting(
                                                "theme",
                                                ["system", "light", "dark"][themeCombo.currentIndex])
                                        }
                                    }
                                }
                            }
                        }

                        FormRow {
                            label: qsTr("窗口置顶")
                            description: qsTr("启动台始终显示在其他窗口之上")
                            Switch {
                                id: topSwitch
                                checkedText: qsTr("开")
                                uncheckedText: qsTr("关")
                                onCheckedChanged: launcherPage.setSetting("alwaysOnTop", checked)
                            }
                        }

                        FormRow {
                            label: qsTr("系统托盘图标")
                            description: qsTr("关闭后只能靠热键唤出启动台")
                            Switch {
                                id: traySwitch
                                checkedText: qsTr("开")
                                uncheckedText: qsTr("关")
                                onCheckedChanged: launcherPage.setSetting("showTray", checked)
                            }
                        }

                        FormRow {
                            label: qsTr("条目尺寸")
                            description: qsTr("启动台网格里每个图标卡片的边长")
                            SpinBox {
                                id: tileSpin
                                from: 72
                                to: 144
                                stepSize: 8
                                onValueModified: launcherPage.setSetting("itemSize", value)
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // 数据
    // ------------------------------------------------------------------
    Component.onCompleted: reload()

    Connections {
        target: ConfigManager

        // 配置每次成功写入都会发这个信号，网格因此不需要每个对话框来推它。
        function onConfigChanged() {
            launcherPage.reload()
        }
    }

    function reload() {
        allActions = ConfigManager.getActions()
        sections = searching
            ? ConfigManager.searchActions(searchField.text)
            : ConfigManager.getCategorizedActions()
        syncQuickSettings()
    }

    function syncQuickSettings() {
        var settings = ConfigManager.getSettings()
        themeCombo.currentIndex = Math.max(0, ["system", "light", "dark"].indexOf(settings.theme))
        topSwitch.checked = settings.alwaysOnTop !== false
        traySwitch.checked = settings.showTray !== false
        tileSpin.value = settings.itemSize || launcherPage.tileSize
        launcherPage.tileSize = tileSpin.value
        launcherPage.gridColumns = settings.gridColumns || 6
    }

    function applyFilter(text) {
        searching = text.length > 0
        sections = ConfigManager.searchActions(text)
    }

    // 只在值真的变了才落盘：快捷开关反复同步时不会白白重写配置。
    function setSetting(key, value) {
        if (ConfigManager.getSettings()[key] === value) {
            return
        }
        var payload = {}
        payload[key] = value
        ConfigManager.updateSettings(payload)
    }

    // ------------------------------------------------------------------
    // 交互
    // ------------------------------------------------------------------
    function runEntry(entry) {
        if (!entry) {
            return
        }
        ConfigManager.executeAction(entry)
        if (searching) {
            searchField.text = ""
        }
    }

    function runEntryAsAdmin(entry) {
        if (!entry) {
            return
        }
        var elevated = JSON.parse(JSON.stringify(entry))
        elevated.run_as = "admin"
        ConfigManager.executeAction(elevated)
    }

    function runTool(kind) {
        switch (kind) {
        case "configFolder":
            ConfigManager.openConfigFolder()
            break
        case "reload":
            ConfigManager.reloadConfig()
            break
        case "elevate":
            ConfigManager.restartAsAdmin()
            break
        case "records":
            launcherPage.navigate("records")
            break
        case "settings":
            launcherPage.navigate("settings")
            break
        }
    }

    // 页面由 NavigationView 按 URL 装载，拿不到主窗口的 id，因此借道窗口上的
    // requestedPage 属性 —— 托盘跳转走的也是这条链路。
    function navigate(page) {
        var host = Window.window
        if (host && host.navigationView !== undefined) {
            host.requestedPage = page
        }
    }

    function showEntryMenu(entry, sceneX, sceneY) {
        entryMenu.entry = entry
        var local = launcherPage.mapFromItem(null, sceneX, sceneY)
        entryMenu.popup(Qt.point(local.x, local.y))
    }

    function confirmDelete(entry) {
        if (!entry) {
            return
        }
        confirmDialog.ask(qsTr("确定要删除条目“%1”吗？此操作不可撤销。").arg(entry.name),
                          function () { ConfigManager.deleteAction(entry.id) })
    }
}
