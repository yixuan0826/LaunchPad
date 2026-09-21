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

// 常驻桌面右下角的启动台小窗。
//
// 只有三行固定槽位，对齐希沃桌面助手那类桌面挂件的形态：
//   第一行 4 个常用应用，第二行 6 个快捷功能，第三行 1 个存储位置 + 打开 U 盘。
// 槽位内容由完整窗口的「启动台」页配置，存在 config.yaml 的 launcher 段里。
// 高度固定为桌面可用高度的一半。
Window {
    id: compact

    // ── 形态 ──
    // 投影要落在卡片外面，所以窗口比卡片大一圈，四周留出 shadowMargin 的透明边。
    readonly property int shadowMargin: 10
    readonly property int edgeMargin: 16      // 贴边时与桌面边缘的距离
    readonly property int contentMargin: 14

    width: 400
    height: Math.max(400, Math.round(Screen.desktopAvailableHeight / 2))
    visible: false
    color: "transparent"
    title: qsTr("Rin Launcher")
    // 无边框 + 工具窗口（不占任务栏）是桌面挂件的标准形态。置顶不在这里写死：
    // 它跟着 settings.alwaysOnTop 走，由 Python 侧统一加/减 WindowStaysOnTopHint，
    // 两边都写会互相打架。
    flags: Qt.FramelessWindowHint | Qt.Tool

    // ── 尺寸 ──
    readonly property real cardWidth: width - shadowMargin * 2
    readonly property real innerWidth: cardWidth - contentMargin * 2
    readonly property int appSlotsCount: 4
    readonly property int toolSlotsCount: 6
    readonly property int appGap: 10
    readonly property int toolGap: 8
    // 第一行每格边长：按可用宽度四等分，再夹住上下限，免得太小或撑爆。
    readonly property real appTileSize: Math.max(56, Math.min(92,
        Math.floor((innerWidth - (appSlotsCount - 1) * appGap) / appSlotsCount)))
    readonly property real toolCellWidth: Math.floor(
        (innerWidth - (toolSlotsCount - 1) * toolGap) / toolSlotsCount)

    // ── 状态 ──
    property var apps: []
    property var tools: []
    property var storage: ({})
    property date now: new Date()
    property bool cornerPinned: true
    // 从 settings 同步过来的一份镜像：直接写 ConfigManager.getSettings() 既不会随
    // 配置变化刷新，销毁时会因为上下文属性已置空而报 TypeError。
    property bool alwaysOnTop: true

    // 小窗只发信号，窗口切换/退出这类跨窗口的活儿统一交给 Python 决定。
    signal openMainRequested(string page)
    signal hideRequested()
    signal quitRequested()

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
    // 界面
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
            spacing: 12

            // ── 状态条（也是拖拽区）──
            Item {
                id: statusBar
                Layout.fillWidth: true
                Layout.preferredHeight: 52

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Text {
                        font.pixelSize: 28
                        font.bold: true
                        color: Theme.currentTheme.colors.textColor
                        text: Qt.formatDateTime(compact.now, "HH:mm")
                    }

                    Text {
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 5
                        font.pixelSize: 11
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: Qt.formatDateTime(compact.now, "M月d日")
                            + " " + compact.weekdayName(compact.now)
                    }

                    Item { Layout.fillWidth: true }

                    AppIcon {
                        Layout.alignment: Qt.AlignVCenter
                        iconKey: "ic_fluent_pin_20_regular"
                        iconSize: 14
                        tint: Theme.currentTheme.colors.primaryColor
                        visible: compact.alwaysOnTop
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

            // ── 第一行：4 个常用应用 ──
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 86

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: compact.appGap

                    Repeater {
                        objectName: "appSlotsRepeater"
                        model: compact.apps

                        delegate: CompactTile {
                            entry: modelData && modelData.id ? modelData : null
                            tileSize: compact.appTileSize
                            onActivated: compact.runEntry(modelData)
                            onMenuRequested: compact.showEntryMenu(modelData, sceneX, sceneY)
                        }
                    }
                }
            }

            // ── 第二行：6 个快捷功能 ──
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 62

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: compact.toolGap

                    Repeater {
                        objectName: "toolSlotsRepeater"
                        model: compact.tools

                        delegate: Item {
                            width: compact.toolCellWidth
                            height: 58
                            opacity: modelData && modelData.key ? 1 : 0.35

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: pointer.pressed || pointer.hovered
                                    ? Theme.currentTheme.colors.controlSecondaryColor
                                    : "transparent"

                                Behavior on color {
                                    ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                width: parent.width
                                spacing: 3

                                AppIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    iconKey: modelData && modelData.icon
                                        ? modelData.icon : "ic_fluent_dismiss_20_regular"
                                    iconSize: 22
                                    tint: Theme.currentTheme.colors.primaryColor
                                }

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    // 每格只有 ~57px，标题四五个字就装不下，允许折成两行，
                                    // 不然会变成「打开配置…」这种读不出意思的省略号。
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    lineHeight: 0.95
                                    font.pixelSize: 10
                                    color: Theme.currentTheme.colors.textColor
                                    text: modelData && modelData.title ? modelData.title : ""
                                }
                            }

                            MouseArea {
                                id: pointer
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !!(modelData && modelData.key)
                                onClicked: compact.runTool(modelData.key)
                            }
                        }
                    }
                }
            }

            // ── 第三行：存储位置 + 打开 U 盘 ──
            Frame {
                Layout.fillWidth: true
                Layout.preferredHeight: 74

                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: 104   // 右侧留给 U 盘按钮
                    cursorShape: Qt.PointingHandCursor
                    onClicked: compact.openStorage()
                    ToolTip.text: compact.storage.available
                        ? qsTr("%1\n剩余 %2 / 共 %3")
                            .arg(compact.storage.path)
                            .arg(compact.storage.free)
                            .arg(compact.storage.total)
                        : String(compact.storage.path || "")
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 10

                    AppIcon {
                        Layout.alignment: Qt.AlignVCenter
                        iconKey: "ic_fluent_storage_20_regular"
                        iconSize: 24
                        tint: Theme.currentTheme.colors.primaryColor
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.pixelSize: 12
                                font.bold: true
                                color: Theme.currentTheme.colors.textColor
                                text: compact.storage.label || qsTr("存储位置")
                            }

                            Text {
                                font.pixelSize: 10
                                color: Theme.currentTheme.colors.textSecondaryColor
                                // 这一行宽度很紧：带上总量会把左边的目录名挤成「w...e」，
                                // 总量挪到提示气泡里，进度条本身也表达了占比。
                                text: compact.storage.available
                                    ? qsTr("剩余 %1").arg(compact.storage.free)
                                    : qsTr("容量未知")
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 4
                            radius: 2
                            color: Theme.currentTheme.colors.controlSecondaryColor

                            Rectangle {
                                height: parent.height
                                radius: parent.radius
                                width: parent.width * Math.min(100,
                                    Math.max(0, compact.storage.percent || 0)) / 100
                                color: Theme.currentTheme.colors.primaryColor
                            }
                        }
                    }

                    Button {
                        Layout.alignment: Qt.AlignVCenter
                        text: qsTr("U 盘")
                        icon.name: "ic_fluent_hard_drive_20_regular"
                        ToolTip.text: compact.storage.drive
                            ? qsTr("打开 %1").arg(compact.storage.drive)
                            : qsTr("未检测到可移动磁盘")
                        onClicked: ConfigManager.openRemovableDrive()
                    }
                }
            }

            // ── 底部操作条 ──
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
            text: qsTr("换一个应用…")
            icon.name: "ic_fluent_edit_20_regular"
            onTriggered: compact.openMain("launcher")
        }
    }

    Menu {
        id: moreMenu
        position: Position.None

        MenuItem {
            text: qsTr("启动台设置…")
            icon.name: "ic_fluent_apps_20_regular"
            onTriggered: compact.openMain("launcher")
        }
        MenuItem {
            text: qsTr("打开完整窗口")
            icon.name: "ic_fluent_window_20_regular"
            onTriggered: compact.openMain("records")
        }
        MenuItem {
            text: qsTr("回到右下角")
            icon.name: "ic_fluent_pin_20_regular"
            onTriggered: compact.snapToCorner()
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

        // 配置每次成功写入都会发这个信号，小窗据此重取三行槽位。
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
        apps = ConfigManager.getLauncherApps()
        tools = ConfigManager.getLauncherTools()
        storage = ConfigManager.getStorageInfo()
    }

    function syncSettings() {
        alwaysOnTop = ConfigManager.getSettings().alwaysOnTop !== false
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
        if (!entry || !entry.id) {
            return
        }
        ConfigManager.executeAction(entry)
    }

    function runEntryAsAdmin(entry) {
        if (!entry || !entry.id) {
            return
        }
        var elevated = JSON.parse(JSON.stringify(entry))
        elevated.run_as = "admin"
        ConfigManager.executeAction(elevated)
    }

    function runTool(key) {
        switch (key) {
        case "configFolder":
            ConfigManager.openConfigFolder()
            break
        case "reload":
            ConfigManager.reloadConfig()
            break
        case "elevate":
            ConfigManager.restartAsAdmin()
            break
        case "usb":
            ConfigManager.openRemovableDrive()
            break
        case "hide":
            compact.hideRequested()
            break
        case "records":
            compact.openMain("records")
            break
        case "settings":
            compact.openMain("settings")
            break
        case "main":
            compact.openMain("records")
            break
        }
    }

    function openStorage() {
        ConfigManager.openPath(compact.storage.path || "")
    }

    // 小窗是独立的 QML 根，够不到完整窗口，跨窗口的请求统一走信号交给 Python。
    function openMain(page) {
        compact.openMainRequested(page)
    }

    function showEntryMenu(entry, sceneX, sceneY) {
        if (!entry || !entry.id) {
            return
        }
        entryMenu.entry = entry
        var local = compact.contentItem.mapFromItem(null, sceneX, sceneY)
        entryMenu.popup(Qt.point(local.x, local.y))
    }
}
