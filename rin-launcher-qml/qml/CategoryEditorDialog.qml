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
    height: 360
    
    property var categoryData: null
    property bool isNew: true
    signal categorySaved()
    
    FluentPage {
        anchors.fill: parent
        title: ""
        spacing: 16
        padding: 24
        
        // Name
        SettingItem {
            title: qsTr("名称")
            TextField {
                id: nameField
                width: 300
                placeholderText: qsTr("分类名称")
                text: categoryData ? categoryData.name : ""
            }
        }
        
        // Icon
        SettingItem {
            title: qsTr("图标")
            Row {
                spacing: 12
                ToolButton {
                    id: iconButton
                    icon.name: categoryData ? categoryData.icon : "\ueb8f"
                    onClicked: {
                        iconPicker.targetButton = iconButton
                        iconPicker.open()
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: categoryData ? categoryData.icon : "\ueb8f"
                    font.family: "Consolas"
                    color: Theme.currentTheme.colors.textSecondaryColor
                }
            }
        }
        
        // Order
        SettingItem {
            title: qsTr("排序")
            SpinBox {
                id: orderSpin
                width: 200
                from: -1000
                to: 1000
                value: categoryData ? categoryData.order : 0
            }
        }
        
        // Expanded by default
        SettingItem {
            title: qsTr("默认展开")
            Switch {
                checked: categoryData ? categoryData.expanded : true
            }
        }
    }
    
    // Icon Picker Dialog
    QQC2.Dialog {
        id: iconPicker
        title: qsTr("选择图标")
        modal: true
        standardButtons: QQC2.Dialog.Cancel
        width: 480
        height: 400
        
        property var targetButton: null
        
        GridView {
            anchors.fill: parent
            anchors.margins: 16
            cellWidth: 48
            cellHeight: 48
            model: [
                "ic_fluent_star_20_regular", "ic_fluent_folder_20_regular", "ic_fluent_file_20_regular",
                "ic_fluent_code_20_regular", "ic_fluent_terminal_20_regular", "ic_fluent_database_20_regular",
                "ic_fluent_server_20_regular", "ic_fluent_cloud_20_regular", "ic_fluent_globe_20_regular",
                "ic_fluent_play_20_regular", "ic_fluent_pause_20_regular", "ic_fluent_stop_20_regular",
                "ic_fluent_image_20_regular", "ic_fluent_video_20_regular", "ic_fluent_music_note_20_regular",
                "ic_fluent_game_20_regular", "ic_fluent_tv_20_regular", "ic_fluent_phone_20_regular",
                "ic_fluent_tablet_20_regular", "ic_fluent_laptop_20_regular", "ic_fluent_desktop_20_regular",
                "ic_fluent_keyboard_20_regular", "ic_fluent_mouse_20_regular", "ic_fluent_settings_20_regular",
                "ic_fluent_toolbox_20_regular", "ic_fluent_wrench_20_regular", "ic_fluent_hammer_20_regular",
                "ic_fluent_paint_brush_20_regular", "ic_fluent_palette_20_regular", "ic_fluent_rocket_20_regular"
            ]
            delegate: ToolButton {
                width: 48
                height: 48
                icon.name: modelData
                checkable: true
                checked: iconPicker.targetButton && iconPicker.targetButton.icon.name === modelData
                onClicked: {
                    if (iconPicker.targetButton) {
                        iconPicker.targetButton.icon.name = modelData
                    }
                    iconPicker.close()
                }
            }
        }
    }
    
    onAccepted: {
        saveCategory()
    }
    
    function saveCategory() {
        if (!nameField.text.trim()) {
            floatLayer.createInfoBar({ severity: Severity.Warning, position: Position.TopRight, title: qsTr("验证失败"), text: qsTr("请输入分类名称") })
            return
        }
        
        var category = {
            id: categoryData ? categoryData.id : generateId(),
            name: nameField.text.trim(),
            icon: iconButton.icon.name,
            order: orderSpin.value,
            expanded: true
        }
        
        if (isNew) {
            ConfigManager.addCategory(category)
        } else {
            ConfigManager.updateCategory(category)
        }
        categorySaved()
    }
    
    function newCategory() {
        isNew = true
        categoryData = null
        nameField.text = ""
        iconButton.icon.name = "\ueb8f"
        orderSpin.value = 0
        open()
    }
    
    function editCategory(category) {
        isNew = false
        categoryData = category
        nameField.text = category.name
        iconButton.icon.name = category.icon || "\ueb8f"
        orderSpin.value = category.order
        open()
    }
    
    function generateId() {
        return Math.random().toString(36).substr(2, 8)
    }
}