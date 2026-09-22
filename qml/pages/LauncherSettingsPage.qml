import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

import "../components"
import "../dialogs"

// 启动台设置。
//
// 小窗就是三行槽位，「可自定义程度」对齐档案编辑：每一行都是一个可以增删、前后
// 移动、逐格编辑的列表 —— 槽位数量不写死，放不下时小窗会横向滚动。
Item {
    id: launcherSettings

    readonly property int rowApps: 0
    readonly property int rowTools: 1
    readonly property int rowStorage: 2

    // 三行的解析结果（含名称/图标/目标），小窗拿的是同一份数据。
    property var appSlots: []
    property var toolSlots: []
    property var storageSlots: []
    property string storagePath: ""
    property var storage: ({})

    SlotEditorDialog {
        id: slotEditor
        onSaved: launcherSettings.reload()
    }

    // ------------------------------------------------------------------
    // 界面
    // ------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 8

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    font.bold: true
                    font.pixelSize: Theme.currentTheme.typography.bodySize + 4
                    color: Theme.currentTheme.colors.textColor
                    text: qsTr("启动台")
                }

                Text {
                    typography: Typography.Caption
                    color: Theme.currentTheme.colors.textSecondaryColor
                    text: qsTr("桌面右下角那块小窗的三行内容，改完立即生效")
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                text: qsTr("预览小窗")
                icon.name: "ic_fluent_window_20_regular"
                onClicked: ConfigManager.previewCompact()
            }
            Button {
                text: qsTr("重载配置")
                icon.name: "ic_fluent_arrow_sync_20_regular"
                onClicked: ConfigManager.reloadConfig()
            }
        }

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
                spacing: 16

                // ── 第一行 ──
                SettingsGroup {
                    iconKey: "ic_fluent_apps_20_regular"
                    title: qsTr("第一行 · 常用应用")

                    Text {
                        Layout.fillWidth: true
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("大格子，适合放常开的程序。候选项来自「档案」页里的条目，"
                                   + "也可以在槽位里直接指定一个文件夹或磁盘。")
                    }

                    SlotListEditor {
                        objectName: "appSlotList"
                        row: launcherSettings.rowApps
                        slots: launcherSettings.appSlots
                        emptyHint: qsTr("这一行还是空的，点「添加」放一个应用进来。")
                        unit: qsTr("个应用")
                        onAddRequested: slotEditor.openFor(launcherSettings.rowApps, -1, null)
                        onEditRequested: launcherSettings.editSlot(launcherSettings.rowApps, index)
                        onRemoveRequested: launcherSettings.removeSlot(launcherSettings.rowApps, index)
                        onMoveRequested: ConfigManager.moveLauncherSlot(
                                             launcherSettings.rowApps, index, delta)
                    }
                }

                // ── 第二行 ──
                SettingsGroup {
                    iconKey: "ic_fluent_wrench_20_regular"
                    title: qsTr("第二行 · 快捷功能")

                    Text {
                        Layout.fillWidth: true
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("小格子，适合放打开设置、重载配置这类动作。"
                                   + "内置功能之外，也能塞条目或文件夹。")
                    }

                    SlotListEditor {
                        objectName: "toolSlotList"
                        row: launcherSettings.rowTools
                        slots: launcherSettings.toolSlots
                        emptyHint: qsTr("这一行还是空的，点「添加」放一个功能进来。")
                        unit: qsTr("个功能")
                        onAddRequested: slotEditor.openFor(launcherSettings.rowTools, -1, null)
                        onEditRequested: launcherSettings.editSlot(launcherSettings.rowTools, index)
                        onRemoveRequested: launcherSettings.removeSlot(launcherSettings.rowTools, index)
                        onMoveRequested: ConfigManager.moveLauncherSlot(
                                             launcherSettings.rowTools, index, delta)
                    }
                }

                // ── 第三行 ──
                SettingsGroup {
                    iconKey: "ic_fluent_hard_drive_20_regular"
                    title: qsTr("第三行 · 存储与磁盘")

                    Text {
                        Layout.fillWidth: true
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("左边固定的那张卡是小窗的存储位置；后面跟着的是磁盘入口 —— "
                                   + "「可移动磁盘」自动认第一个 U 盘，「文件 / 文件夹 / 磁盘」"
                                   + "可以钉死某个盘符。两个是各自独立的槽位，随便加减。")
                    }

                    FormRow {
                        label: qsTr("存储位置")
                        labelWidth: 88

                        TextField {
                            id: storageField
                            objectName: "storagePathField"
                            Layout.fillWidth: true
                            Layout.maximumWidth: 320
                            placeholderText: qsTr("留空 = 用户主目录")
                            text: launcherSettings.storagePath
                            // 敲完（回车或失焦）才落盘，不用每敲一个字写一次。
                            onEditingFinished: launcherSettings.setStoragePath(text)
                        }
                        Button {
                            text: qsTr("浏览…")
                            icon.name: "ic_fluent_folder_open_20_regular"
                            onClicked: {
                                var picked = ConfigManager.pickFolder()
                                if (picked.length > 0) {
                                    launcherSettings.setStoragePath(picked)
                                }
                            }
                        }
                        ToolButton {
                            icon.name: "ic_fluent_open_20_regular"
                            ToolTip.text: qsTr("打开这个目录")
                            onClicked: {
                                var current = storageField.text.length > 0
                                    ? storageField.text
                                    : launcherSettings.storage.path
                                ConfigManager.openPath(current)
                            }
                        }
                    }

                    SlotListEditor {
                        objectName: "storageSlotList"
                        row: launcherSettings.rowStorage
                        slots: launcherSettings.storageSlots
                        emptyHint: qsTr("还没有磁盘入口，点「添加」放一个 U 盘或某个盘进去。")
                        unit: qsTr("个入口")
                        onAddRequested: slotEditor.openFor(launcherSettings.rowStorage, -1, null)
                        onEditRequested: launcherSettings.editSlot(launcherSettings.rowStorage, index)
                        onRemoveRequested: launcherSettings.removeSlot(launcherSettings.rowStorage, index)
                        onMoveRequested: ConfigManager.moveLauncherSlot(
                                             launcherSettings.rowStorage, index, delta)
                    }
                }
            }
        }
    }

    Component.onCompleted: reload()

    Connections {
        target: ConfigManager
        function onLauncherChanged() {
            launcherSettings.reload()
        }
    }

    // ------------------------------------------------------------------
    // 数据
    // ------------------------------------------------------------------
    function reload() {
        // 一次取全，再按行分好 —— 比每行各调一次少三倍的解析。
        var slots = ConfigManager.getLauncherSlots()
        appSlots = filterRow(slots, rowApps)
        toolSlots = filterRow(slots, rowTools)
        storageSlots = filterRow(slots, rowStorage)
        storagePath = ConfigManager.getLauncherStoragePath()
        storage = ConfigManager.getStorageInfo()
        syncStorageField()
    }

    function filterRow(slots, row) {
        return slots.filter(function (item) { return item.row === row })
    }

    // 输入框只在值真的变了时回填，免得把用户正在敲的内容顶掉。
    function syncStorageField() {
        if (storageField.text !== storagePath) {
            storageField.text = storagePath
        }
    }

    // ------------------------------------------------------------------
    // 交互
    // ------------------------------------------------------------------
    function editSlot(row, index) {
        var raw = filterRaw(row)[index]
        if (raw) {
            slotEditor.openFor(row, index, raw)
        }
    }

    function filterRaw(row) {
        return ConfigManager.getRawLauncherSlots().filter(function (item) {
            return item.row === row
        })
    }

    function removeSlot(row, index) {
        var raw = filterRaw(row)[index]
        var name = raw ? (raw.label || raw.path || raw.ref || "") : ""
        confirmRemove.message = name.length > 0
            ? qsTr("确定要从小窗上移除「%1」这一格吗？只会移除这一格，条目本身还在档案里。").arg(name)
            : qsTr("确定要移除这一格吗？")
        confirmRemove.callback = function () {
            ConfigManager.deleteLauncherSlot(row, index)
        }
        confirmRemove.open()
    }

    function setStoragePath(path) {
        path = String(path || "").trim()
        if (path === storagePath) {
            return
        }
        ConfigManager.setLauncherStoragePath(path)
    }

    ConfirmDialog {
        id: confirmRemove
        // 默认的 420px 在窄窗口下会被裁掉一截。
        width: 360
    }
}
