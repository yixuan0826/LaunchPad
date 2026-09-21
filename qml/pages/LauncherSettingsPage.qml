import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

import "../components"

// 启动台设置。
//
// 常驻小窗是三行固定槽位（4 个常用应用 / 6 个快捷功能 / 1 个存储位置），这一页就是
// 那三行的配置面板。槽位数量固定，只换内容，不增删。
Item {
    id: launcherSettings

    // 注意：RinUI 的 NavigationView 在 push 页面时会把 objectName 覆盖成文件名
    // 派生的名字，所以这里写 objectName 是没用的，无头脚本靠 appSlotCount 认页面。
    readonly property int appSlotCount: 4
    readonly property int toolSlotCount: 6

    property var appIds: []        // 4 个槽位当前选的条目 id，空串表示空位
    property var toolKeys: []      // 6 个槽位当前选的功能 key，空串表示空位
    property string storagePath: ""

    property var actionNames: [qsTr("未设置")]   // 下拉候选项
    property var actionIdsOfModel: [""]
    property var toolNames: [qsTr("未设置")]
    property var toolKeysOfModel: [""]

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

                // ── 第一行：常用应用 ──
                SettingsGroup {
                    iconKey: "ic_fluent_apps_20_regular"
                    title: qsTr("第一行 · 常用应用")

                    Text {
                        Layout.fillWidth: true
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("固定 4 个位置，候选项是「档案」里已有的条目。"
                                   + "条目被删掉后这一格会空着，重新选一个即可。")
                    }

                    Repeater {
                        id: appRepeater
                        // objectName 是给无头验收脚本定位用的。
                        objectName: "appSlotRepeater"
                        model: launcherSettings.appSlotCount

                        delegate: SlotPicker {
                            slotLabel: qsTr("位置 %1").arg(index + 1)
                            options: launcherSettings.actionNames
                            onPicked: launcherSettings.setAppSlot(index, slotIndex)
                        }
                    }
                }

                // ── 第二行：快捷功能 ──
                SettingsGroup {
                    iconKey: "ic_fluent_wrench_20_regular"
                    title: qsTr("第二行 · 快捷功能")

                    Text {
                        Layout.fillWidth: true
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("固定 6 个位置，候选项是小窗自带的动作。")
                    }

                    Repeater {
                        id: toolRepeater
                        // objectName 是给无头验收脚本定位用的。
                        objectName: "toolSlotRepeater"
                        model: launcherSettings.toolSlotCount

                        delegate: SlotPicker {
                            slotLabel: qsTr("位置 %1").arg(index + 1)
                            options: launcherSettings.toolNames
                            onPicked: launcherSettings.setToolSlot(index, slotIndex)
                        }
                    }
                }

                // ── 第三行：存储位置 ──
                SettingsGroup {
                    iconKey: "ic_fluent_storage_20_regular"
                    title: qsTr("第三行 · 存储位置")

                    Text {
                        Layout.fillWidth: true
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("小窗第三行左边显示的目录，点它就会打开。留空表示用户主目录。"
                                   + "右边的「U 盘」按钮会自己去打开第一个可移动磁盘。")
                    }

                    FormRow {
                        label: qsTr("目录")
                        labelWidth: 72

                        TextField {
                            id: storageField
                            Layout.fillWidth: true
                            Layout.maximumWidth: 320
                            placeholderText: qsTr("留空 = 用户主目录")
                            text: launcherSettings.storagePath
                            // 只在敲完（回车或失焦）时落盘，不用每敲一个字就写一次配置。
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
                                    : ConfigManager.getStorageInfo().path
                                ConfigManager.openPath(current)
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: reload()

    Connections {
        target: ConfigManager

        function onConfigChanged() {
            launcherSettings.reload()
        }
    }

    // ------------------------------------------------------------------
    // 数据
    // ------------------------------------------------------------------
    function reload() {
        var config = ConfigManager.getLauncherConfig()
        appIds = config.apps
        toolKeys = config.tools
        storagePath = config.storagePath

        var actions = ConfigManager.getActions()
        var names = [qsTr("未设置")]
        var ids = [""]
        for (var i = 0; i < actions.length; ++i) {
            names.push(actions[i].name)
            ids.push(actions[i].id)
        }
        actionNames = names
        actionIdsOfModel = ids

        var catalog = ConfigManager.getToolCatalog()
        var toolNameList = [qsTr("未设置")]
        var toolKeyList = [""]
        for (var k = 0; k < catalog.length; ++k) {
            toolNameList.push(catalog[k].title)
            toolKeyList.push(catalog[k].key)
        }
        launcherSettings.toolNames = toolNameList
        toolKeysOfModel = toolKeyList

        syncPickers()
    }

    // 下拉的 currentIndex 只能显式赋值（见 SlotPicker 的说明），所以重载后逐个回填。
    function syncPickers() {
        for (var i = 0; i < appSlotCount; ++i) {
            var picker = appRepeater.itemAt(i)
            if (picker) {
                picker.select(Math.max(0, actionIdsOfModel.indexOf(appIds[i] || "")))
            }
        }
        for (var t = 0; t < toolSlotCount; ++t) {
            var toolPicker = toolRepeater.itemAt(t)
            if (toolPicker) {
                toolPicker.select(Math.max(0, toolKeysOfModel.indexOf(toolKeys[t] || "")))
            }
        }
        storageField.text = storagePath
    }

    // ------------------------------------------------------------------
    // 写盘
    // ------------------------------------------------------------------
    function pushLauncher(payload) {
        ConfigManager.updateLauncherConfig(payload)
    }

    function setAppSlot(slot, optionIndex) {
        if (!appIds.slice) {
            return
        }
        var next = appIds.slice()
        next[slot] = actionIdsOfModel[optionIndex] || ""
        if (next[slot] === (appIds[slot] || "")) {
            return
        }
        pushLauncher({ "apps": next })
    }

    function setToolSlot(slot, optionIndex) {
        var next = toolKeys.slice()
        next[slot] = toolKeysOfModel[optionIndex] || ""
        if (next[slot] === (toolKeys[slot] || "")) {
            return
        }
        pushLauncher({ "tools": next })
    }

    function setStoragePath(path) {
        path = String(path || "").trim()
        if (path === storagePath) {
            return
        }
        pushLauncher({ "storagePath": path })
    }
}
