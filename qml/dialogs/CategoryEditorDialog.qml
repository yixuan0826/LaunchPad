import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

import "../components"

// 分区编辑器：新增 / 修改启动台上的一个分区。
//
// 分区在配置里以「名字」被条目引用，因此重命名会级联更新条目 —— 这一步由
// ConfigManager.updateCategory() 在写入时完成，这里只负责校验与提交。
Dialog {
    id: editor

    property var category: null       // null 表示新建
    property bool isNew: true
    property string iconKey: "ic_fluent_folder_20_regular"

    signal saved()

    title: isNew ? qsTr("新建分区") : qsTr("编辑分区")
    modal: true
    width: 560
    closePolicy: Popup.NoAutoClose

    IconPickerDialog {
        id: iconPicker
        onPicked: editor.iconKey = iconKey
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        FormRow {
            label: qsTr("名称")
            TextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: qsTr("分区标题")
            }
        }

        FormRow {
            label: qsTr("图标")
            ToolButton {
                icon.name: "ic_fluent_apps_add_in_20_regular"
                ToolTip.text: qsTr("从图标库中选择")
                onClicked: {
                    iconPicker.current = editor.iconKey
                    iconPicker.open()
                }
            }
            AppIcon {
                Layout.alignment: Qt.AlignVCenter
                iconKey: editor.iconKey
                iconSize: 22
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                font.family: "Consolas"
                color: Theme.currentTheme.colors.textSecondaryColor
                text: editor.iconKey
            }
        }

        FormRow {
            label: qsTr("排序")
            description: qsTr("数字越小越靠前")
            SpinBox {
                id: orderSpin
                from: 0
                to: 999
            }
        }

        FormRow {
            label: qsTr("默认展开")
            description: qsTr("打开启动台时该分区是否展开")
            Switch {
                id: expandedSwitch
                checkedText: qsTr("展开")
                uncheckedText: qsTr("折叠")
            }
        }
    }

    footer: RowLayout {
        spacing: 8

        Item { Layout.fillWidth: true }

        Button {
            text: qsTr("取消")
            onClicked: editor.reject()
        }

        Button {
            text: qsTr("保存")
            highlighted: true
            onClicked: editor.commit()
        }
    }

    function newCategory() {
        isNew = true
        category = null
        iconKey = "ic_fluent_folder_20_regular"
        nameField.text = ""
        orderSpin.value = ConfigManager.getCategories().length
        expandedSwitch.checked = true
        open()
    }

    function editCategory(item) {
        if (!item) {
            return
        }
        isNew = false
        category = item
        iconKey = item.icon || "ic_fluent_folder_20_regular"
        nameField.text = item.name || ""
        orderSpin.value = item.order || 0
        expandedSwitch.checked = item.expanded !== false
        open()
    }

    function commit() {
        var name = nameField.text.trim()
        if (!name) {
            ConfigManager.notify(qsTr("请先填写分区名称"), "warning")
            return
        }

        // 分区名是条目的引用键，重名会让分组结果变得不可预期。
        var duplicated = ConfigManager.getCategories().some(function (item) {
            return item.name === name && (!category || item.id !== category.id)
        })
        if (duplicated) {
            ConfigManager.notify(qsTr("已存在同名分区：%1").arg(name), "warning")
            return
        }

        var payload = {
            id: category ? category.id : "",
            name: name,
            icon: iconKey,
            order: Math.round(orderSpin.value),
            expanded: expandedSwitch.checked
        }

        var ok = isNew ? ConfigManager.addCategory(payload) : ConfigManager.updateCategory(payload)
        if (!ok) {
            ConfigManager.notify(qsTr("保存失败，请查看日志"), "error")
            return
        }
        ConfigManager.notify(isNew
                             ? qsTr("已新建分区：%1").arg(name)
                             : qsTr("已更新分区：%1").arg(name), "success")
        saved()
        accept()
    }
}
