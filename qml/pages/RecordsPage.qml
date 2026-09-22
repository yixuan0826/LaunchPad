import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

import "../components"
import "../dialogs"

// 档案。
//
// 左边分区、右边条目，交互照 ClassIsland 那种「可增删排序的列表」来：
//   * 每个分区行自带 排序 / 编辑 / 删除，不必先选中再去别处找按钮；
//   * 条目行可以勾选，顶部工具条能一次性启停或删除；
//   * 点行即编辑，右侧那一排按钮是给鼠标更快的人用的。
// 启动台只读，所有写入都发生在这里。
Item {
    id: recordsPage

    property var categories: []
    property var entries: []
    property string selectedCategory: ""
    property string query: ""
    // 勾选的条目 id；检索条件变了也不会自动清空，批量操作才连得上。
    property var checked: []

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

        // ── 顶部工具条 ──
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
                    text: qsTr("管理分区与条目，启动台第一行的候选项就是这里的条目")
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
                icon.name: "ic_fluent_folder_add_20_regular"
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
                Layout.preferredWidth: 300
                Layout.minimumWidth: 220
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
                            implicitHeight: 58
                            color: recordsPage.selectedCategory === modelData.name
                                ? Theme.currentTheme.colors.subtleSecondaryColor
                                : Theme.currentTheme.colors.cardColor

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 6
                                spacing: 6

                                AppIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    iconKey: modelData.icon || ""
                                    iconSize: 20
                                    tint: Theme.currentTheme.colors.primaryColor
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    // 四个按钮是固定宽度，名字列不给个下限就会被压成
                                    // 一个字一行（RinUI 的 Text 默认是 WordWrap）。
                                    Layout.minimumWidth: 64
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        wrapMode: Text.NoWrap
                                        elide: Text.ElideRight
                                        color: Theme.currentTheme.colors.textColor
                                        text: modelData.name
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        wrapMode: Text.NoWrap
                                        elide: Text.ElideRight
                                        typography: Typography.Caption
                                        color: Theme.currentTheme.colors.textSecondaryColor
                                        text: qsTr("%1 项 · 排序 %2")
                                            .arg(modelData.entryCount)
                                            .arg(modelData.order)
                                    }
                                }

                                MiniIconButton {
                                    iconName: "ic_fluent_arrow_up_20_regular"
                                    tip: qsTr("上移")
                                    enabled: index > 0
                                    onClicked: ConfigManager.moveCategory(modelData.id, -1)
                                }
                                MiniIconButton {
                                    iconName: "ic_fluent_arrow_down_20_regular"
                                    tip: qsTr("下移")
                                    enabled: index < recordsPage.categories.length - 1
                                    onClicked: ConfigManager.moveCategory(modelData.id, 1)
                                }
                                MiniIconButton {
                                    iconName: "ic_fluent_edit_20_regular"
                                    tip: qsTr("编辑分区")
                                    onClicked: categoryEditor.editCategory(modelData)
                                }
                                MiniIconButton {
                                    iconName: "ic_fluent_delete_20_regular"
                                    tip: qsTr("删除分区")
                                    danger: true
                                    onClicked: recordsPage.confirmDeleteCategory(modelData)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.rightMargin: 140   // 让出右侧四个按钮
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

                    // 条目工具条。拆成两行：上一行是常驻的检索与全选，下一行只在
                    // 勾选了条目时冒出来 —— 一排挤七八个控件会把窄窗口撑爆。
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
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            typography: Typography.Caption
                            color: Theme.currentTheme.colors.textSecondaryColor
                            text: qsTr("%1 项").arg(recordsPage.entries.length)
                        }

                        TextField {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 240
                            placeholderText: qsTr("过滤条目…")
                            onTextChanged: recordsPage.query = text
                        }

                        Item { Layout.fillWidth: true }

                        CheckBox {
                            id: selectAllBox
                            text: qsTr("全选")
                            enabled: recordsPage.entries.length > 0
                            onClicked: recordsPage.toggleAll(checked)
                        }
                    }

                    // 批量操作条：没有勾选时就整行收起，不占高度。
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: recordsPage.checked.length > 0 ? 32 : 0
                        visible: recordsPage.checked.length > 0
                        spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            typography: Typography.Caption
                            color: Theme.currentTheme.colors.textSecondaryColor
                            text: qsTr("已选 %1 项").arg(recordsPage.checked.length)
                        }
                        Button {
                            text: qsTr("启用")
                            icon.name: "ic_fluent_checkmark_circle_20_regular"
                            onClicked: ConfigManager.setActionsEnabled(recordsPage.checked, true)
                        }
                        Button {
                            text: qsTr("停用")
                            icon.name: "ic_fluent_eye_off_20_regular"
                            onClicked: ConfigManager.setActionsEnabled(recordsPage.checked, false)
                        }
                        Button {
                            text: qsTr("删除")
                            icon.name: "ic_fluent_delete_20_regular"
                            onClicked: recordsPage.confirmDeleteChecked()
                        }
                        Item { Layout.fillWidth: true }
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

                            readonly property bool marked: recordsPage.isChecked(modelData.id)

                            width: entryList.width
                            implicitHeight: 64
                            color: marked
                                ? Theme.currentTheme.colors.subtleSecondaryColor
                                : Theme.currentTheme.colors.cardColor

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                spacing: 10

                                CheckBox {
                                    Layout.alignment: Qt.AlignVCenter
                                    checked: entryRow.marked
                                    onClicked: recordsPage.toggleChecked(modelData.id, checked)
                                }

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
                                    Layout.minimumWidth: 80
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.NoWrap
                                            elide: Text.ElideRight
                                            color: Theme.currentTheme.colors.textColor
                                            text: modelData.name
                                        }
                                        // 停用的条目在启动台上会消失，这里标出来免得找不着。
                                        Text {
                                            visible: modelData.enabled === false
                                            typography: Typography.Caption
                                            color: Theme.currentTheme.colors.textSecondaryColor
                                            text: qsTr("已停用")
                                        }
                                        Text {
                                            visible: modelData.run_as === "admin"
                                            typography: Typography.Caption
                                            color: Theme.currentTheme.colors.primaryColor
                                            text: qsTr("管理员")
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        wrapMode: Text.NoWrap
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
                                    MiniIconButton {
                                        iconName: "ic_fluent_arrow_up_20_regular"
                                        tip: qsTr("上移")
                                        onClicked: ConfigManager.moveAction(modelData.id, -1)
                                    }
                                    MiniIconButton {
                                        iconName: "ic_fluent_arrow_down_20_regular"
                                        tip: qsTr("下移")
                                        onClicked: ConfigManager.moveAction(modelData.id, 1)
                                    }
                                    MiniIconButton {
                                        iconName: "ic_fluent_edit_20_regular"
                                        tip: qsTr("编辑")
                                        onClicked: entryEditor.editEntry(modelData)
                                    }
                                    MiniIconButton {
                                        iconName: "ic_fluent_copy_20_regular"
                                        tip: qsTr("复制一份")
                                        onClicked: ConfigManager.duplicateAction(modelData)
                                    }
                                    MiniIconButton {
                                        iconName: "ic_fluent_delete_20_regular"
                                        tip: qsTr("删除")
                                        danger: true
                                        onClicked: recordsPage.confirmDeleteEntry(modelData)
                                    }
                                }
                            }

                            // 点空白处进编辑器；按钮与开关各自吃掉自己的点击。
                            MouseArea {
                                anchors.fill: parent
                                anchors.leftMargin: 40
                                anchors.rightMargin: 200
                                onClicked: entryEditor.editEntry(modelData)
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
                        text: qsTr("这里还没有条目。点右上角「新建条目」加一个，"
                                   + "它就会出现在启动台的候选列表里。")
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
        function onRecordsChanged() {
            recordsPage.reload()
        }
    }

    function reload() {
        // 每个分区带一个条目计数，免得列表里每行都去翻一遍完整条目表。
        var all = ConfigManager.getActions()
        var counts = {}
        for (var i = 0; i < all.length; ++i) {
            var name = all[i].category
            counts[name] = (counts[name] || 0) + 1
        }

        categories = ConfigManager.getCategories().sort(function (a, b) {
            return (a.order || 0) - (b.order || 0)
        }).map(function (item) {
            return {
                "id": item.id,
                "name": item.name,
                "icon": item.icon,
                "order": item.order,
                "expanded": item.expanded,
                "entryCount": counts[item.name] || 0
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
            // 名字与悬停提示都算命中，和检索框的直觉一致。
            return (item.name || "").toLowerCase().indexOf(needle) !== -1
                || (item.tooltip || "").toLowerCase().indexOf(needle) !== -1
        }).sort(function (a, b) {
            return (a.order || 0) - (b.order || 0)
        })
    }

    function describe(entry) {
        var kinds = {
            "file": qsTr("文件"),
            "cmd": qsTr("命令"),
            "url": qsTr("网址"),
            "keymouse": qsTr("键鼠")
        }
        var parts = [kinds[entry.type] || entry.type, entry.target || qsTr("(未设置)")]
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

    function isChecked(actionId) {
        return checked.indexOf(actionId) !== -1
    }

    function toggleChecked(actionId, wanted) {
        var next = checked.slice()
        var at = next.indexOf(actionId)
        if (wanted && at === -1) {
            next.push(actionId)
        } else if (!wanted && at !== -1) {
            next.splice(at, 1)
        }
        checked = next
    }

    function toggleAll(wanted) {
        if (!wanted) {
            checked = []
            return
        }
        var next = []
        for (var i = 0; i < entries.length; ++i) {
            next.push(entries[i].id)
        }
        checked = next
    }

    function confirmDeleteEntry(entry) {
        confirmDialog.ask(qsTr("确定要删除条目“%1”吗？此操作不可撤销。").arg(entry.name),
                          function () { ConfigManager.deleteAction(entry.id) })
    }

    function confirmDeleteChecked() {
        var ids = checked.slice()
        confirmDialog.ask(qsTr("确定要删除选中的 %1 个条目吗？此操作不可撤销。").arg(ids.length),
                          function () {
                              ConfigManager.deleteActions(ids)
                              recordsPage.checked = []
                          })
    }

    function confirmDeleteCategory(category) {
        confirmDialog.ask(
            qsTr("确定要删除分区“%1”吗？该分区下的条目会被移动到“默认”分区。").arg(category.name),
            function () { ConfigManager.deleteCategory(category.id) })
    }
}
