import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import QtQuick.Controls 2.15 as QQC2
import RinUI

QQC2.Dialog {
    id: categoryEditorDialog
    title: isNew ? qsTr("新建分类") : qsTr("编辑分类")
    modal: true
    standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
    width: 480
    height: 400

    property var categoryData: null
    property bool isNew: true

    onAccepted: saveCategory()

    IconPicker {
        id: iconPicker
    }

    FluentPage {
        anchors.fill: parent
        title: ""
        spacing: 16
        padding: 24

        SettingItem {
            title: qsTr("名称")
            TextField {
                id: nameField
                width: 300
                placeholderText: qsTr("分类名称")
            }
        }

        SettingItem {
            title: qsTr("图标")
            ToolButton {
                id: iconButton
                icon.name: "ic_fluent_folder_20_regular"
                onClicked: {
                    iconPicker.targetButton = iconButton
                    iconPicker.open()
                }
            }
            Text {
                font.family: "Consolas"
                color: Theme.currentTheme.colors.textSecondaryColor
                text: iconButton.icon.name
            }
        }

        SettingItem {
            title: qsTr("排序")
            SpinBox {
                id: orderSpin
                width: 200
                from: -1000
                to: 1000
                value: 0
            }
        }

        SettingItem {
            title: qsTr("默认展开")
            Switch {
                id: expandedSwitch
                checked: true
            }
        }
    }

    function saveCategory() {
        if (!nameField.text.trim()) {
            ConfigManager.notify(qsTr("请输入分类名称"), "warning")
            return
        }

        var category = {
            id: categoryData ? categoryData.id : "",
            name: nameField.text.trim(),
            icon: iconButton.icon.name,
            order: orderSpin.value,
            expanded: expandedSwitch.checked
        }

        if (isNew) {
            ConfigManager.addCategory(category)
        } else {
            ConfigManager.updateCategory(category)
        }
    }

    function newCategory() {
        isNew = true
        categoryData = null
        nameField.text = ""
        iconButton.icon.name = "ic_fluent_folder_20_regular"
        orderSpin.value = 0
        expandedSwitch.checked = true
        open()
    }

    function editCategory(category) {
        isNew = false
        categoryData = category
        nameField.text = category.name || ""
        iconButton.icon.name = category.icon || "ic_fluent_folder_20_regular"
        orderSpin.value = category.order || 0
        expandedSwitch.checked = category.expanded !== false
        open()
    }
}
