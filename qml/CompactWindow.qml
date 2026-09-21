import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import Qt5Compat.GraphicalEffects
import RinUI
// QtQuick.Window 必须排在 RinUI 后面：QML 里后导入的类型优先级更高，
// 否则 Window 会解析到 RinUI 那套自带标题栏与背景矩形的窗口包装，桌面挂件就变成
// 普通窗口了。副作用是 QtQuick 的 Text 也会盖过 RinUI 的 Text，所以本文件里的
// 文字用 font.pixelSize / color 这些 Qt 原生属性，不写 RinUI 特有的 typography。
import QtQuick.Window 2.15

import "components"
import "dialogs"

// 常驻桌面右下角的启动台小窗。
//
// 版式参考希沃桌面助手 / Ink Workspace 那类桌面挂件：无边框、半透明卡片、竖版
// 一块贴在桌面角落。自上而下是「状态条 → 搜索 → 分区网格 → 工具 → 快捷设置 →
// 底部操作条」，上面那段是拖拽区。
//
// 档案与设置仍然由大窗口（LauncherWindow）承载 —— 小窗只负责「点一下就用」，
// 需要编辑和维护的活儿走 openMainRequested 交给主窗口。
Window {
    id: compact

    // ── 形态 ──
    // 投影要落在卡片外面，所以窗口比卡片大一圈，四周留出 shadowMargin 的透明边。
    readonly property int shadowMargin: 10
    readonly property int edgeMargin: 16      // 贴边时与桌面边缘的距离
    readonly property int contentMargin: 14

    width: 348
    height: 584
    visible: false
    color: "transparent"
    title: qsTr("Rin Launcher")
    // 无边框 + 工具窗口（不占任务栏）是桌面挂件的标准形态。置顶不在这里写死：
    // 它跟着 settings.alwaysOnTop 走，由 Python 侧统一加/减 WindowStaysOnTopHint，
    // 两边都写会互相打架。
    flags: Qt.FramelessWindowHint | Qt.Tool

    // ── 网格 ──
    readonly property real cardWidth: width - shadowMargin * 2
    readonly property real gridWidth: cardWidth - contentMargin * 2
    readonly property int gridColumns: 4
    readonly property int gridSpacing: 12
    readonly property real tileSize: Math.floor(
        (gridWidth - (gridColumns - 1) * gridSpacing) / gridColumns)
    // 分区标题与网格要一起夹到「每行正好 N 格」的宽度，两者才对得齐。
    readonly property real maxGridWidth: gridColumns * tileSize
        + (gridColumns - 1) * gridSpacing

    // ── 状态 ──
    property var sections: []
    property int actionCount: 0
    property bool searching: false
    property date now: new Date()
    property bool cornerPinned: true
    // 从 settings 同步过来的一份镜像：直接写 ConfigManager.getSettings() 既不会随
    // 配置变化刷新，销毁时会因为上下文属性已置空而报 TypeError。
    property bool alwaysOnTop: true

    // 小窗只发信号，窗口切换/退出这类跨窗口的活儿统一交给 Python 决定。
    signal openMainRequested(string page)
    signal hideRequested()
    signal quitRequested()

    readonly property var tools: [
        { "title": qsTr("打开配置目录"), "icon": "ic_fluent_folder_open_20_regular",
          "kind": "configFolder" },
        { "title": qsTr("重新加载配置"), "icon": "ic_fluent_arrow_sync_20_regular",
          "kind": "reload" },
        { "title": qsTr("档案管理"), "icon": "ic_fluent_book_20_regular",
          "kind": "records" },
        { "title": qsTr("设置"), "icon": "ic_fluent_settings_20_regular",
          "kind": "settings" },
        { "title": qsTr("打开完整窗口"), "icon": "ic_fluent_window_20_regular",
          "kind": "main" },
        { "title": qsTr("以管理员身份重启"), "icon": "ic_fluent_shield_20_regular",
          "kind": "elevate" }
    ]

    // ------------------------------------------------------------------
    // 位置：默认贴右下角；拖动过就记住坐标，直到在菜单里点「回到右下角」。
    // ------------------------------------------------------------------
    function snapToCorner() {
        // Screen 给的是窗口所在（未显示时是主）显示器的可用区域，已经排除任务栏。
        x = Screen.virtualX + Screen.desktopAvailableWidth - width - edgeMargin
        y = Screen.virtualY + Screen.desktopAvailableHeight - height - edgeMargin
        cornerPinned = true
        setSetting("compactPos", "")
    }

    function restorePosition() {
        var parts = String(ConfigManager.getSettings().compactPos || "").split(",")
        var px = parseInt(parts[0], 10)
        var py = parseInt(parts[1], 10)
        if (parts.length === 2 && !isNaN(px) && !isNaN(py)) {
            x = px
            y = py
            cornerPinned = false
            return
        }
        snapToCorner()
    }

    function persistPosition() {
        if (cornerPinned) {
            return
        }
        setSetting("compactPos", x + "," + y)
    }

    // ------------------------------------------------------------------
    // 内容
    // ------------------------------------------------------------------
    Item {
        anchors.fill: parent
        anchors.margins: compact.shadowMargin

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 14
            // 半透明，让桌面透一点出来，接近参考图那种毛玻璃观感。
            color: Qt.rgba(Theme.currentTheme.colors.backgroundColor.r,
                           Theme.currentTheme.colors.backgroundColor.g,
                           Theme.currentTheme.colors.backgroundColor.b, 0.94)
            border.width: 1
            border.color: Theme.currentTheme.colors.windowBorderColor
            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                horizontalOffset: 0
                verticalOffset: 4
                radius: 18
                samples: 25
                color: "#66000000"
            }
        }

        ColumnLayout {
            anchors.fill: card
            anchors.margins: compact.contentMargin
            spacing: 10

            // ── ① 状态条（也是拖拽区）──
            Item {
                id: statusBar
                Layout.fillWidth: true
                Layout.preferredHeight: 58

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        Text {
                            font.pixelSize: 30
                            font.bold: true
                            color: Theme.currentTheme.colors.textColor
                            text: Qt.formatDateTime(compact.now, "HH:mm")
                        }

                        Text {
                            font.pixelSize: 11
                            color: Theme.currentTheme.colors.textSecondaryColor
                            text: Qt.formatDateTime(compact.now, "M月d日")
                                + " " + compact.weekdayName(compact.now)
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignRight
                            font.pixelSize: 11
                            color: Theme.currentTheme.colors.textSecondaryColor
                            text: qsTr("%1 个条目").arg(compact.actionCount)
                        }

                        Row {
                            Layout.alignment: Qt.AlignRight
                            spacing: 6

                            AppIcon {
                                iconKey: "ic_fluent_pin_20_regular"
                                iconSize: 14
                                tint: Theme.currentTheme.colors.primaryColor
                                visible: compact.alwaysOnTop
                            }

                            AppIcon {
                                iconKey: "ic_fluent_clock_20_regular"
                                iconSize: 14
                                tint: Theme.currentTheme.colors.textSecondaryColor
                            }
                        }
                    }
                }

                DragHandler {
                    target: null
                    onActiveChanged: {
                        if (!active) {
                            return
                        }
                        // startSystemMove() 阻塞到系统把窗口拖完，返回时 x/y 已是新位置。
                        compact.startSystemMove()
                        compact.cornerPinned = false
                        compact.persistPosition()
                    }
                }
            }

            // ── ② 搜索 ──
            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: qsTr("搜索应用、文件、命令…")
                clearEnabled: true
                onTextChanged: compact.applyFilter(text)
            }

            // ── ③ 分区网格（可滚动）──
            Flickable {
                id: scroller
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: contentColumn.implicitHeight + 8
                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: contentColumn
                    x: 0
                    width: scroller.width
                    spacing: 12

                    Repeater {
                        // objectName 是给无头验收脚本定位这个 Repeater 用的。
                        objectName: "sectionsRepeater"
                        model: compact.sections

                        delegate: ColumnLayout {
                            id: sectionBox

                            property var sectionData: modelData

                            Layout.fillWidth: true
                            Layout.maximumWidth: compact.maxGridWidth
                            spacing: 8

                            ZoneHeader {
                                iconKey: sectionBox.sectionData.categoryIcon
                                title: sectionBox.sectionData.categoryName
                                trailing: qsTr("%1 项").arg(
                                    sectionBox.sectionData.actions.length)
                            }

                            Flow {
                                Layout.fillWidth: true
                                Layout.preferredHeight: childrenRect.height
                                spacing: compact.gridSpacing

                                Repeater {
                                    model: sectionBox.sectionData.actions

                                    delegate: CompactTile {
                                        entry: modelData
                                        tileSize: compact.tileSize
                                        onActivated: compact.runEntry(modelData)
                                        onMenuRequested: compact.showEntryMenu(
                                            modelData, sceneX, sceneY)
                                    }
                                }
                            }
                        }
                    }

                    // 空状态
                    Frame {
                        Layout.fillWidth: true
                        implicitHeight: 120
                        visible: compact.sections.length === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            AppIcon {
                                Layout.alignment: Qt.AlignHCenter
                                iconKey: "ic_fluent_search_20_regular"
                                iconSize: 24
                                tint: Theme.currentTheme.colors.textSecondaryColor
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                width: 220
                                wrapMode: Text.Wrap
                                color: Theme.currentTheme.colors.textSecondaryColor
                                text: compact.searching
                                    ? qsTr("没有匹配的条目")
                                    : qsTr("启动台还是空的")
                            }
                        }
                    }

                    // ── ④ 工具 ──
                    ZoneHeader {
                        Layout.topMargin: 4
                        iconKey: "ic_fluent_wrench_20_regular"
                        title: qsTr("工具")
                    }

                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: childrenRect.height
                        spacing: 4

                        Repeater {
                            model: compact.tools

                            delegate: ToolButton {
                                icon.name: modelData.icon
                                ToolTip.text: modelData.title
                                onClicked: compact.runTool(modelData.kind)
                            }
                        }
                    }

                    // ── ⑤ 快捷设置 ──
                    ZoneHeader {
                        Layout.topMargin: 4
                        iconKey: "ic_fluent_settings_20_regular"
                        title: qsTr("快捷设置")
                    }

                    FormRow {
                        label: qsTr("主题")
                        labelWidth: 48

                        ComboBox {
                            id: themeCombo
                            Layout.preferredWidth: 150
                            model: [qsTr("跟随系统"), qsTr("浅色"), qsTr("深色")]
                            // 用 Connections 而不是 onCurrentIndexChanged：RinUI 的
                            // ComboBox 内部已经定义过同名处理函数，外部再写会把它覆盖掉。
                            Connections {
                                target: themeCombo
                                function onCurrentIndexChanged() {
                                    if (themeCombo.currentIndex >= 0) {
                                        compact.setSetting(
                                            "theme",
                                            ["system", "light", "dark"][themeCombo.currentIndex])
                                    }
                                }
                            }
                        }
                    }

                    FormRow {
                        label: qsTr("置顶")
                        labelWidth: 48

                        Switch {
                            id: topSwitch
                            checkedText: qsTr("开")
                            uncheckedText: qsTr("关")
                            onCheckedChanged: compact.setSetting("alwaysOnTop", checked)
                        }
                    }
                }
            }

            // ── ⑥ 底部操作条 ──
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                spacing: 6

                Button {
                    Layout.fillWidth: true
                    text: qsTr("打开完整窗口")
                    icon.name: "ic_fluent_window_20_regular"
                    onClicked: compact.openMain("launcher")
                }

                ToolButton {
                    icon.name: "ic_fluent_book_20_regular"
                    ToolTip.text: qsTr("档案")
                    onClicked: compact.openMain("records")
                }

                ToolButton {
                    icon.name: "ic_fluent_settings_20_regular"
                    ToolTip.text: qsTr("设置")
                    onClicked: compact.openMain("settings")
                }

                ToolButton {
                    icon.name: "ic_fluent_more_vertical_20_regular"
                    ToolTip.text: qsTr("更多")
                    onClicked: {
                        // position 必须是 None，否则 RinUI 的 Menu 会按锚点重算
                        // posX/posY，覆盖掉 popup() 指定的坐标。
                        var scene = parent.mapToItem(null, 0, 0)
                        moreMenu.popup(Qt.point(scene.x, scene.y + parent.height + 4))
                    }
                }
            }
        }

        // 简易 toast：常驻小窗没有 FloatLayer 那种半屏宽的容器，自绘一条更合适。
        Rectangle {
            id: toast
            anchors.horizontalCenter: card.horizontalCenter
            anchors.bottom: card.bottom
            anchors.bottomMargin: 52
            z: 900
            width: Math.min(toastText.implicitWidth + 24, card.width - 32)
            height: 32
            radius: 8
            color: Theme.currentTheme.colors.primaryColor
            opacity: 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 160 }
            }

            Text {
                id: toastText
                anchors.centerIn: parent
                width: parent.width - 20
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: "white"
                font.pixelSize: 12
                text: ""
            }

            Timer {
                id: toastTimer
                interval: 2600
                onTriggered: toast.opacity = 0
            }
        }
    }

    // ------------------------------------------------------------------
    // 菜单
    // ------------------------------------------------------------------
    Menu {
        id: entryMenu
        position: Position.None

        property var entry: null

        MenuItem {
            text: qsTr("打开")
            icon.name: "ic_fluent_open_20_regular"
            onTriggered: compact.runEntry(entryMenu.entry)
        }
        MenuItem {
            text: qsTr("以管理员身份打开")
            icon.name: "ic_fluent_shield_20_regular"
            visible: entryMenu.entry
                && (entryMenu.entry.type === "file" || entryMenu.entry.type === "cmd")
            onTriggered: compact.runEntryAsAdmin(entryMenu.entry)
        }
        MenuSeparator {}
        MenuItem {
            text: entryMenu.entry && entryMenu.entry.enabled === false ? qsTr("启用") : qsTr("停用")
            icon.name: "ic_fluent_eye_20_regular"
            onTriggered: ConfigManager.toggleAction(
                entryMenu.entry.id, entryMenu.entry.enabled === false)
        }
        MenuItem {
            text: qsTr("在档案里编辑…")
            icon.name: "ic_fluent_edit_20_regular"
            onTriggered: compact.openMain("records")
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("删除…")
            icon.name: "ic_fluent_delete_20_regular"
            onTriggered: compact.confirmDelete(entryMenu.entry)
        }
    }

    Menu {
        id: moreMenu
        position: Position.None

        MenuItem {
            text: qsTr("回到右下角")
            icon.name: "ic_fluent_pin_20_regular"
            onTriggered: compact.snapToCorner()
        }
        MenuItem {
            text: qsTr("打开完整窗口")
            icon.name: "ic_fluent_window_20_regular"
            onTriggered: compact.openMain("launcher")
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("隐藏小窗")
            icon.name: "ic_fluent_eye_off_20_regular"
            onTriggered: compact.hideRequested()
        }
        MenuItem {
            text: qsTr("退出")
            icon.name: "ic_fluent_power_20_regular"
            onTriggered: compact.quitRequested()
        }
    }

    ConfirmDialog {
        id: confirmDialog
        // 默认的 420px 比这个小窗还宽，会把按钮挤出窗口外面。
        width: 288
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: compact.now = new Date()
    }

    Component.onCompleted: {
        restorePosition()
        reload()
        syncSettings()
    }

    Connections {
        target: ConfigManager

        // 配置每次成功写入都会发这个信号，网格因此不需要每个对话框来推它。
        function onConfigChanged() {
            compact.reload()
        }

        function onShowToast(message, _severity) {
            toastText.text = message
            toast.opacity = 1
            toastTimer.restart()
        }
    }

    // ------------------------------------------------------------------
    // 数据
    // ------------------------------------------------------------------
    function reload() {
        var actions = ConfigManager.getActions()
        actionCount = actions.length
        sections = searching
            ? ConfigManager.searchActions(searchField.text)
            : ConfigManager.getCategorizedActions()
    }

    function syncSettings() {
        var settings = ConfigManager.getSettings()
        themeCombo.currentIndex = Math.max(0, ["system", "light", "dark"].indexOf(settings.theme))
        topSwitch.checked = settings.alwaysOnTop !== false
        alwaysOnTop = settings.alwaysOnTop !== false
    }

    function applyFilter(text) {
        searching = text.length > 0
        sections = ConfigManager.searchActions(text)
    }

    // 只在值真的变了才落盘：反复同步时不会白白重写配置。
    function setSetting(key, value) {
        if (ConfigManager.getSettings()[key] === value) {
            return
        }
        var payload = {}
        payload[key] = value
        ConfigManager.updateSettings(payload)
    }

    function weekdayName(date) {
        return [qsTr("周日"), qsTr("周一"), qsTr("周二"), qsTr("周三"),
                qsTr("周四"), qsTr("周五"), qsTr("周六")][date.getDay()]
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
            compact.openMain("records")
            break
        case "settings":
            compact.openMain("settings")
            break
        case "main":
            compact.openMain("launcher")
            break
        }
    }

    // 小窗是独立的 QML 根，够不到主窗口，跨窗口的请求统一走信号交给 Python。
    function openMain(page) {
        compact.openMainRequested(page)
    }

    function showEntryMenu(entry, sceneX, sceneY) {
        entryMenu.entry = entry
        var local = compact.contentItem.mapFromItem(null, sceneX, sceneY)
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
