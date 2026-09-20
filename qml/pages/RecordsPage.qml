import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

import "../components"
import "../dialogs"

// 档案。
//
// 这是整个启动台的「档案编辑器」：左边是分区清单（可增删改与排序），右边是
// 选中分区里的条目（可启停、改顺序、复制、删除）。启动台只读，所有写入都发生
// 在这里。
Item {
    id: recordsPage

    property var categories: []
    property var entries: []
    property string selectedCategory: ""
    property string query: ""

    CategoryEditorDialog {
        id: categoryEditor
    }

    EntryEditorDialog {
        id: entryEditor
    }

    ConfirmDialog {
        id: confirmDialog
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── 顶部 ──
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
                    text: qsTr("档案")
                }
                Text {
                    typography: Typography.Caption
                    color: Theme.currentTheme.colors.textSecondaryColor
                    text: qsTr("管理启动台上的分区与条目")
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                text: qsTr("导入")
                icon.name: "ic_fluent_arrow_import_20_regular"
                onClicked: ConfigManager.importConfig()
            }
            Button {
                text: qsTr("导出")
                icon.name: "ic_fluent_arrow_export_20_regular"
                onClicked: ConfigManager.exportConfig()
            }
            Button {
                text: qsTr("新建分区")
                icon.name: "ic_fluent_folder_20_regular"
                onClicked: categoryEditor.newCategory()
            }
            Button {
                text: qsTr("新建条目")
                icon.name: "ic_fluent_add_20_regular"
                highlighted: true
                onClicked: entryEditor.newEntry(recordsPage.selectedCategory)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 16
            spacing: 16

            // ── 左：分区 ──
            Frame {
                Layout.preferredWidth: 280
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 8
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            font.bold: true
                            color: Theme.currentTheme.colors.textColor
                            text: qsTr("分区")
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            typography: Typography.Caption
                            color: Theme.currentTheme.colors.textSecondaryColor
                            text: qsTr("%1 个").arg(recordsPage.categories.length)
                        }
                    }

                    ListView {
                        id: categoryList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        model: recordsPage.categories

                        delegate: Frame {
                            id: categoryRow
                            width: categoryList.width
                            implicitHeight: 56
                            color: recordsPage.selectedCategory === modelData.name
                                ? Theme.currentTheme.colors.subtleSecondaryColor
                                : Theme.currentTheme.colors.cardColor

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 8

                                AppIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    iconKey: modelData.icon || ""
                                    iconSize: 20
                                    tint: Theme.currentTheme.colors.primaryColor
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        color: Theme.currentTheme.colors.textColor
                                        text: modelData.name
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        typography: Typography.Caption
                                        color: Theme.currentTheme.colors.textSecondaryColor
                                        text: qsTr("%1 项 · 排序 %2")
                                            .arg(modelData.entryCount)
                                            .arg(modelData.order)
                                    }
                                }

                                ToolButton {
                                    icon.name: "ic_fluent_edit_20_regular"
                                    ToolTip.text: qsTr("编辑分区")
                                    onClicked: categoryEditor.editCategory(modelData)
                                }
                                ToolButton {
                                    icon.name: "ic_fluent_delete_20_regular"
                                    ToolTip.text: qsTr("删除分区")
                                    onClicked: recordsPage.confirmDeleteCategory(modelData)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.rightMargin: 96  // 让出右侧两个按钮
                                onClicked: recordsPage.selectCategory(modelData.name)
                            }
                        }
                    }
                }
            }

            // ── 右：条目 ──
            Frame {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            font.bold: true
                            color: Theme.currentTheme.colors.textColor
                            text: recordsPage.selectedCategory.length > 0
                                ? recordsPage.selectedCategory
                                : qsTr("全部条目")
                        }

                        TextField {
                            Layout.preferredWidth: 240
                            placeholderText: qsTr("过滤条目…")
                            onTextChanged: recordsPage.query = text
                        }

                        Item { Layout.fillWidth: true }

                        ToolButton {
                            icon.name: "ic_fluent_arrow_up_20_regular"
                            ToolTip.text: qsTr("分区上移")
                            enabled: recordsPage.selectedCategory.length > 0
                            onClicked: recordsPage.moveSelectedCategory(-1)
                        }
                        ToolButton {
                            icon.name: "ic_fluent_arrow_down_20_regular"
                            ToolTip.text: qsTr("分区下移")
                            enabled: recordsPage.selectedCategory.length > 0
                            onClicked: recordsPage.moveSelectedCategory(1)
                        }
                    }

                    ListView {
                        id: entryList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: recordsPage.entries

                        delegate: Frame {
                            id: entryRow
                            width: entryList.width
                            implicitHeight: 64

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 12
                                spacing: 12

                                AppIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    iconKey: modelData.icon || ""
                                    iconSize: 24
                                    tint: modelData.enabled === false
                                        ? Theme.currentTheme.colors.textSecondaryColor
                                        : Theme.currentTheme.colors.primaryColor
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        color: Theme.currentTheme.colors.textColor
                                        text: modelData.name
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideMiddle
                                        typography: Typography.Caption
                                        color: Theme.currentTheme.colors.textSecondaryColor
                                        text: recordsPage.describe(modelData)
                                    }
                                }

                                RowLayout {
                                    spacing: 4

                                    Switch {
                                        id: enableSwitch
                                        // 建卡时的首次赋值不该写盘，只有用户拨动才算修改。
                                        property bool ready: false
                                        checked: modelData.enabled !== false
                                        checkedText: ""
                                        uncheckedText: ""
                                        onCheckedChanged: {
                                            if (ready) {
                                                ConfigManager.toggleAction(modelData.id, checked)
                                            }
                                        }
                                        Component.onCompleted: ready = true
                                    }
                                    ToolButton {
                                        icon.name: "ic_fluent_arrow_up_20_regular"
                                        ToolTip.text: qsTr("上移")
                                        onClicked: ConfigManager.moveAction(modelData.id, -1)
                                    }
                                    ToolButton {
                                        icon.name: "ic_fluent_arrow_down_20_regular"
                                        ToolTip.text: qsTr("下移")
                                        onClicked: ConfigManager.moveAction(modelData.id, 1)
                                    }
                                    ToolButton {
                                        icon.name: "ic_fluent_edit_20_regular"
                                        ToolTip.text: qsTr("编辑")
                                        onClicked: entryEditor.editEntry(modelData)
                                    }
                                    ToolButton {
                                        icon.name: "ic_fluent_copy_20_regular"
                                        ToolTip.text: qsTr("复制一份")
                                        onClicked: ConfigManager.duplicateAction(modelData)
                                    }
                                    ToolButton {
                                        icon.name: "ic_fluent_delete_20_regular"
                                        ToolTip.text: qsTr("删除")
                                        onClicked: recordsPage.confirmDeleteEntry(modelData)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: recordsPage.entries.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.Wrap
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("这个分区下还没有条目，点右上角「新建条目」添加一个。")
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

        function onConfigChanged() {
            recordsPage.reload()
        }
    }

    function reload() {
        // 每个分区带一个条目计数，避免列表里每行都去翻一遍完整条目表。
        categories = ConfigManager.getCategories().sort(function (a, b) {
            return (a.order || 0) - (b.order || 0)
        }).map(function (item) {
            return {
                "id": item.id,
                "name": item.name,
                "icon": item.icon,
                "order": item.order,
                "expanded": item.expanded,
                "entryCount": recordsPage.countIn(item.name)
            }
        })
        if (selectedCategory.length > 0 && !categories.some(function (item) {
            return item.name === recordsPage.selectedCategory
        })) {
            // 选中的分区被删掉或改名了，退回到第一项。
            selectedCategory = categories.length > 0 ? categories[0].name : ""
        }
        refreshEntries()
    }

    function refreshEntries() {
        var needle = query.trim().toLowerCase()
        entries = ConfigManager.getActions().filter(function (item) {
            if (recordsPage.selectedCategory.length > 0
                    && item.category !== recordsPage.selectedCategory) {
                return false
            }
            if (needle.length === 0) {
                return true
            }
            return (item.name || "").toLowerCase().indexOf(needle) !== -1
        }).sort(function (a, b) {
            return (a.order || 0) - (b.order || 0)
        })
    }

    function countIn(categoryName) {
        return ConfigManager.getActions().filter(function (item) {
            return item.category === categoryName
        }).length
    }

    function describe(entry) {
        var kinds = {
            "file": qsTr("文件"),
            "cmd": qsTr("命令"),
            "url": qsTr("网址"),
            "keymouse": qsTr("键鼠")
        }
        var parts = [kinds[entry.type] || entry.type, entry.target || qsTr("(未设置)")]
        if (entry.run_as === "admin") {
            parts.push(qsTr("管理员"))
        }
        if (entry.hotkey) {
            parts.push(entry.hotkey)
        }
        return parts.join(" · ")
    }

    // ------------------------------------------------------------------
    // 交互
    // ------------------------------------------------------------------
    function selectCategory(name) {
        selectedCategory = name
        refreshEntries()
    }

    function moveSelectedCategory(delta) {
        var current = categories.find(function (item) {
            return item.name === recordsPage.selectedCategory
        })
        if (current) {
            ConfigManager.moveCategory(current.id, delta)
        }
    }

    function confirmDeleteEntry(entry) {
        confirmDialog.ask(qsTr("确定要删除条目“%1”吗？此操作不可撤销。").arg(entry.name),
                          function () { ConfigManager.deleteAction(entry.id) })
    }

    function confirmDeleteCategory(category) {
        confirmDialog.ask(
            qsTr("确定要删除分区“%1”吗？该分区下的条目会被移动到“默认”分区。").arg(category.name),
            function () { ConfigManager.deleteCategory(category.id) })
    }
}
