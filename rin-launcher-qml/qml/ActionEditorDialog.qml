import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import QtQuick.Controls 2.15 as QQC2
import RinUI

QQC2.Dialog {
    id: actionEditorDialog
    title: isNew ? qsTr("新建操作") : qsTr("编辑操作")
    modal: true
    standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
    width: 700
    height: 500
    
    property var actionData: null
    property bool isNew: true
    signal actionSaved()
    
    // Tab bar for sections
    TabBar {
        id: tabBar
        width: parent.width
        TabButton { text: qsTr("基本设置") }
        TabButton { text: qsTr("高级设置") }
        TabButton { text: qsTr("键鼠序列"); enabled: actionData && actionData.type === "keymouse" }
    }
    
    StackView {
        id: stackView
        anchors.top: tabBar.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        initialItem: basicSettingsComponent
    }
    
    onAccepted: {
        saveAction()
    }
    
    // Basic Settings Tab
    Component {
        id: basicSettingsComponent
        FluentPage {
            title: ""
            spacing: 16
            padding: 24
            
            // Name
            SettingItem {
                title: qsTr("名称")
                TextField {
                    id: nameField
                    width: 400
                    placeholderText: qsTr("操作名称")
                    text: actionData ? actionData.name : ""
                }
            }
            
            // Icon
            SettingItem {
                title: qsTr("图标")
                Row {
                    spacing: 12
                    ToolButton {
                        id: iconButton
                        icon.name: actionData ? actionData.icon : "\ueb95"
                        onClicked: {
                            iconPicker.targetButton = iconButton
                            iconPicker.open()
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: actionData ? actionData.icon : "\ueb95"
                        font.family: "Consolas"
                        color: Theme.currentTheme.colors.textSecondaryColor
                    }
                }
            }
            
            // Type
            SettingItem {
                title: qsTr("类型")
                ComboBox {
                    id: typeCombo
                    width: 300
                    model: [
                        qsTr("文件/程序 (file)"),
                        qsTr("命令行 (cmd)"),
                        qsTr("网址 (url)"),
                        qsTr("键鼠模拟 (keymouse)")
                    ]
                    currentIndex: actionData ? ["file", "cmd", "url", "keymouse"].indexOf(actionData.type) : 0
                    onCurrentIndexChanged: {
                        // 目标编辑区的显隐由 targetStack 的 states 声明式处理
                        tabBar.itemAt(2).enabled = (currentIndex === 3)
                    }
                }
            }
            
            // Target (varies by type)
            SettingItem {
                title: qsTr("目标")
                Item {
                    id: targetStack
                    width: parent.width
                    height: 60
                    
                    // File target
                    TextField {
                        id: fileTargetField
                        width: 400
                        placeholderText: qsTr("选择文件或程序")
                        text: actionData && actionData.type === "file" ? actionData.target : ""
                    }
                    
                    // Cmd target
                    TextField {
                        id: cmdTargetField
                        width: 400
                        placeholderText: qsTr("命令 (如: cmd.exe, powershell.exe, ping)")
                        text: actionData && actionData.type === "cmd" ? actionData.target : ""
                        visible: false
                    }
                    
                    // URL target
                    TextField {
                        id: urlTargetField
                        width: 400
                        placeholderText: qsTr("网址 (如: https://github.com)")
                        text: actionData && actionData.type === "url" ? actionData.target : ""
                        visible: false
                    }
                    
                    // Keymouse placeholder
                    Text {
                        id: keymousePlaceholder
                        text: qsTr("在「键鼠序列」标签页配置按键和鼠标操作")
                        color: Theme.currentTheme.colors.textSecondaryColor
                        visible: false
                    }
                    
                    states: [
                        State { name: "file"; when: typeCombo.currentIndex === 0; PropertyChanges { target: fileTargetField; visible: true } PropertyChanges { target: cmdTargetField; visible: false } PropertyChanges { target: urlTargetField; visible: false } PropertyChanges { target: keymousePlaceholder; visible: false } },
                        State { name: "cmd"; when: typeCombo.currentIndex === 1; PropertyChanges { target: fileTargetField; visible: false } PropertyChanges { target: cmdTargetField; visible: true } PropertyChanges { target: urlTargetField; visible: false } PropertyChanges { target: keymousePlaceholder; visible: false } },
                        State { name: "url"; when: typeCombo.currentIndex === 2; PropertyChanges { target: fileTargetField; visible: false } PropertyChanges { target: cmdTargetField; visible: false } PropertyChanges { target: urlTargetField; visible: true } PropertyChanges { target: keymousePlaceholder; visible: false } },
                        State { name: "keymouse"; when: typeCombo.currentIndex === 3; PropertyChanges { target: fileTargetField; visible: false } PropertyChanges { target: cmdTargetField; visible: false } PropertyChanges { target: urlTargetField; visible: false } PropertyChanges { target: keymousePlaceholder; visible: true } }
                    ]
                }
            }
            
            // Arguments
            SettingItem {
                title: qsTr("参数")
                TextField {
                    id: argsField
                    width: 400
                    placeholderText: qsTr("参数 (可选)")
                    text: actionData ? actionData.arguments : ""
                }
            }
            
            // Working Directory
            SettingItem {
                title: qsTr("工作目录")
                TextField {
                    id: workdirField
                    width: 400
                    placeholderText: qsTr("工作目录 (可选)")
                    text: actionData ? actionData.working_dir : ""
                }
            }
            
            // Category
            SettingItem {
                title: qsTr("分类")
                ComboBox {
                    id: categoryCombo
                    width: 300
                    model: ConfigManager.getCategoriesModel()
                    currentIndex: ConfigManager.getCategoryIndex(actionData ? actionData.category : "默认")
                }
            }
            
            // Hotkey
            SettingItem {
                title: qsTr("热键")
                TextField {
                    id: hotkeyField
                    width: 300
                    readOnly: true
                    placeholderText: qsTr("点击输入热键...")
                    text: actionData ? actionData.hotkey : ""
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // TODO: Implement hotkey recording
                        }
                    }
                }
            }
            
            // Tooltip
            SettingItem {
                title: qsTr("提示")
                TextField {
                    id: tooltipField
                    width: 400
                    placeholderText: qsTr("鼠标悬停提示 (可选)")
                    text: actionData ? actionData.tooltip : ""
                }
            }
            
            // Enabled
            SettingItem {
                title: qsTr("启用")
                Switch {
                    checked: actionData ? actionData.enabled : true
                }
            }
        }
    }
    
    // Advanced Settings Tab
    Component {
        id: advancedSettingsComponent
        FluentPage {
            title: ""
            spacing: 16
            padding: 24
            
            SettingItem {
                title: qsTr("以管理员身份运行")
                Switch {
                    checked: actionData ? (actionData.run_as === "admin") : false
                }
            }
            
            SettingItem {
                title: qsTr("排序顺序")
                SpinBox {
                    id: orderSpin
                    width: 200
                    from: -1000
                    to: 1000
                    value: actionData ? actionData.order : 0
                }
            }
        }
    }
    
    // Keymouse Sequence Tab
    Component {
        id: keymouseSettingsComponent
        FluentPage {
            title: ""
            spacing: 16
            padding: 24
            
            Row {
                spacing: 8
                Button {
                    text: qsTr("添加按键")
                    icon.name: "ic_fluent_keyboard_20_regular"
                    onClicked: addKeymouseStep("key")
                }
                Button {
                    text: qsTr("添加鼠标")
                    icon.name: "ic_fluent_mouse_20_regular"
                    onClicked: addKeymouseStep("mouse")
                }
                Button {
                    text: qsTr("添加等待")
                    icon.name: "ic_fluent_clock_20_regular"
                    onClicked: addKeymouseStep("wait")
                }
            }
            
            ListView {
                width: parent.width
                height: 300
                model: actionData ? actionData.keymouse_steps : []
                delegate: KeymouseStepDelegate {
                    width: parent.width
                    stepData: modelData
                    onStepChanged: updateKeymouseSteps()
                    onDeleteRequested: deleteKeymouseStep(index)
                }
            }
            
            Text {
                text: qsTr("提示: 拖拽调整顺序。按键支持组合键 (如 Ctrl+C)。鼠标坐标为屏幕绝对坐标，留空为当前位置。")
                color: Theme.currentTheme.colors.textSecondaryColor
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }
        }
    }
    
    // Icon Picker Dialog
    QQC2.Dialog {
        id: iconPicker
        title: qsTr("选择图标")
        modal: true
        standardButtons: QQC2.Dialog.Cancel
        width: 560
        height: 480
        
        property var targetButton: null
        
        Column {
            anchors.fill: parent
            spacing: 8
            
            // Tab bar
            Row {
                id: iconPickerTabBar
                spacing: 4
                height: 36
                
                Rectangle {
                    id: tab1
                    width: 150
                    height: 36
                    radius: 4
                    color: iconPickerTabBar.currentTab === 0 ? Theme.currentTheme.colors.primaryColor : "transparent"
                    border.color: Theme.currentTheme.colors.controlBorderColor
                    border.width: 1
                    MouseArea {
                        anchors.fill: parent
                        onClicked: iconPickerTabBar.currentTab = 0
                    }
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Fluent Icons")
                        color: iconPickerTabBar.currentTab === 0 ? Theme.currentTheme.colors.textOnAccentColor : Theme.currentTheme.colors.textColor
                        font.pixelSize: 13
                    }
                }
                
                Rectangle {
                    id: tab2
                    width: 150
                    height: 36
                    radius: 4
                    color: iconPickerTabBar.currentTab === 1 ? Theme.currentTheme.colors.primaryColor : "transparent"
                    border.color: Theme.currentTheme.colors.controlBorderColor
                    border.width: 1
                    MouseArea {
                        anchors.fill: parent
                        onClicked: iconPickerTabBar.currentTab = 1
                    }
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("More Icons")
                        color: iconPickerTabBar.currentTab === 1 ? Theme.currentTheme.colors.textOnAccentColor : Theme.currentTheme.colors.textColor
                        font.pixelSize: 13
                    }
                }
            }
            
            property int currentTab: 0
            
            onCurrentTabChanged: {
                if (currentTab === 0) {
                    stackView.push(iconGridView1)
                } else {
                    stackView.push(iconGridView2)
                }
            }
            
            // Content stack
            StackView {
                width: parent.width
                height: parent.height - iconPickerTabBar.height - parent.spacing
                initialItem: iconGridView1
                clip: true
            }
            
            Component {
                id: iconGridView1
                GridView {
                    cellWidth: 48
                    cellHeight: 48
                    model: [
                        "ic_fluent_rocket_20_regular", "ic_fluent_star_20_regular", "ic_fluent_folder_20_regular",
                        "ic_fluent_file_20_regular", "ic_fluent_code_20_regular", "ic_fluent_terminal_20_regular",
                        "ic_fluent_database_20_regular", "ic_fluent_server_20_regular", "ic_fluent_cloud_20_regular",
                        "ic_fluent_globe_20_regular", "ic_fluent_play_20_regular", "ic_fluent_pause_20_regular",
                        "ic_fluent_stop_20_regular", "ic_fluent_forward_20_regular", "ic_fluent_back_20_regular",
                        "ic_fluent_volume_2_20_regular", "ic_fluent_volume_mute_20_regular", "ic_fluent_image_20_regular",
                        "ic_fluent_video_20_regular", "ic_fluent_music_note_20_regular", "ic_fluent_game_20_regular",
                        "ic_fluent_tv_20_regular", "ic_fluent_phone_20_regular", "ic_fluent_tablet_20_regular",
                        "ic_fluent_laptop_20_regular", "ic_fluent_desktop_20_regular", "ic_fluent_keyboard_20_regular",
                        "ic_fluent_mouse_20_regular", "ic_fluent_print_20_regular", "ic_fluent_camera_20_regular",
                        "ic_fluent_settings_20_regular", "ic_fluent_toolbox_20_regular", "ic_fluent_wrench_20_regular",
                        "ic_fluent_hammer_20_regular", "ic_fluent_pen_20_regular", "ic_fluent_pencil_20_regular",
                        "ic_fluent_paint_brush_20_regular", "ic_fluent_palette_20_regular", "ic_fluent_magic_wand_20_regular",
                        "ic_fluent_fire_20_regular", "ic_fluent_bolt_20_regular", "ic_fluent_leaf_20_regular",
                        "ic_fluent_tree_20_regular", "ic_fluent_sprout_20_regular", "ic_fluent_sun_20_regular",
                        "ic_fluent_moon_20_regular", "ic_fluent_cloud_sun_20_regular", "ic_fluent_cloud_moon_20_regular",
                        "ic_fluent_drop_20_regular", "ic_fluent_wind_20_regular"
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
            
            Component {
                id: iconGridView2
                GridView {
                    cellWidth: 48
                    cellHeight: 48
                    model: [
                        "ic_fluent_shopping_cart_20_regular", "ic_fluent_cart_20_regular", "ic_fluent_bag_20_regular",
                        "ic_fluent_gift_20_regular", "ic_fluent_box_20_regular", "ic_fluent_package_20_regular",
                        "ic_fluent_tag_20_regular", "ic_fluent_barcode_20_regular", "ic_fluent_qrcode_20_regular",
                        "ic_fluent_receipt_20_regular", "ic_fluent_invoice_20_regular", "ic_fluent_credit_card_20_regular",
                        "ic_fluent_bank_20_regular", "ic_fluent_calculator_20_regular", "ic_fluent_abacus_20_regular",
                        "ic_fluent_chart_20_regular", "ic_fluent_graph_20_regular", "ic_fluent_pie_chart_20_regular",
                        "ic_fluent_bar_chart_20_regular", "ic_fluent_line_chart_20_regular", "ic_fluent_area_chart_20_regular",
                        "ic_fluent_scatter_chart_20_regular", "ic_fluent_bubble_chart_20_regular", "ic_fluent_radar_chart_20_regular",
                        "ic_fluent_funnel_chart_20_regular", "ic_fluent_gantt_chart_20_regular", "ic_fluent_org_chart_20_regular",
                        "ic_fluent_tree_map_20_regular", "ic_fluent_sunburst_20_regular", "ic_fluent_treemap_20_regular",
                        "ic_fluent_waterfall_20_regular", "ic_fluent_stock_20_regular", "ic_fluent_candlestick_20_regular"
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
        }
    }
    
    function saveAction() {
        if (!nameField.text.trim()) {
            floatLayer.createInfoBar({ severity: Severity.Warning, position: Position.TopRight, title: qsTr("验证失败"), text: qsTr("请输入操作名称") })
            return
        }
        
        var type = ["file", "cmd", "url", "keymouse"][typeCombo.currentIndex]
        if (type === "file" && !fileTargetField.text.trim()) {
            floatLayer.createInfoBar({ severity: Severity.Warning, position: Position.TopRight, title: qsTr("验证失败"), text: qsTr("请选择文件或程序") })
            return
        }
        if (type === "cmd" && !cmdTargetField.text.trim()) {
            floatLayer.createInfoBar({ severity: Severity.Warning, position: Position.TopRight, title: qsTr("验证失败"), text: qsTr("请输入命令") })
            return
        }
        if (type === "url" && !urlTargetField.text.trim()) {
            floatLayer.createInfoBar({ severity: Severity.Warning, position: Position.TopRight, title: qsTr("验证失败"), text: qsTr("请输入网址") })
            return
        }
        
        var action = {
            id: actionData ? actionData.id : generateId(),
            name: nameField.text.trim(),
            icon: iconButton.icon.name,
            type: type,
            target: type === "file" ? fileTargetField.text.trim() : (type === "cmd" ? cmdTargetField.text.trim() : (type === "url" ? urlTargetField.text.trim() : "")),
            arguments: argsField.text.trim(),
            working_dir: workdirField.text.trim(),
            run_as: actionData && actionData.run_as === "admin" ? "admin" : "user",
            keymouse_steps: actionData && actionData.type === "keymouse" ? actionData.keymouse_steps : [],
            category: categoryCombo.model[categoryCombo.currentIndex],
            enabled: actionData ? actionData.enabled : true,
            hotkey: hotkeyField.text,
            tooltip: tooltipField.text.trim(),
            order: orderSpin.value
        }
        
        if (isNew) {
            ConfigManager.addAction(action)
        } else {
            ConfigManager.updateAction(action)
        }
        actionSaved()
    }
    
    function newAction() {
        isNew = true
        actionData = null
        nameField.text = ""
        iconButton.icon.name = "\ueb95"
        typeCombo.currentIndex = 0
        fileTargetField.text = ""
        cmdTargetField.text = ""
        urlTargetField.text = ""
        argsField.text = ""
        workdirField.text = ""
        categoryCombo.currentIndex = 0
        hotkeyField.text = ""
        tooltipField.text = ""
        open()
    }
    
    function editAction(action) {
        isNew = false
        actionData = action
        nameField.text = action.name
        iconButton.icon.name = action.icon || "\ueb95"
        typeCombo.currentIndex = ["file", "cmd", "url", "keymouse"].indexOf(action.type)
        fileTargetField.text = action.target
        cmdTargetField.text = action.target
        urlTargetField.text = action.target
        argsField.text = action.arguments
        workdirField.text = action.working_dir
        categoryCombo.currentIndex = ConfigManager.getCategoryIndex(action.category)
        hotkeyField.text = action.hotkey
        tooltipField.text = action.tooltip
        orderSpin.value = action.order
        open()
    }
    
    function generateId() {
        return Math.random().toString(36).substr(2, 8)
    }
    
    function addKeymouseStep(type) {
        // TODO: Add step to keymouse sequence
    }
    
    function updateKeymouseSteps() {
        // TODO: Update keymouse steps
    }
    
    function deleteKeymouseStep(index) {
        // TODO: Delete step
    }
}