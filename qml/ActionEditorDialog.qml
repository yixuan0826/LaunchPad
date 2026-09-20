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
    height: 520

    readonly property var actionTypes: ["file", "cmd", "url", "keymouse"]

    property var actionData: null
    property bool isNew: true
    property string actionType: "file"
    property var steps: []

    onAccepted: saveAction()

    // Keep the keymouse tab out of reach, and fall back when the type changes.
    onActionTypeChanged: {
        if (actionType !== "keymouse" && tabBar.currentIndex === 2) {
            tabBar.currentIndex = 0
        }
    }

    IconPicker {
        id: iconPicker
    }

    TabBar {
        id: tabBar
        width: parent.width
        TabButton { text: qsTr("基本设置") }
        TabButton { text: qsTr("高级设置") }
        TabButton {
            text: qsTr("键鼠序列")
            enabled: actionEditorDialog.actionType === "keymouse"
        }
    }

    // StackLayout (not a Loader) so switching tabs never discards edits.
    StackLayout {
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        currentIndex: tabBar.currentIndex

        FluentPage {
            title: ""
            spacing: 16
            padding: 24

            SettingItem {
                title: qsTr("名称")
                TextField {
                    id: nameField
                    width: 400
                    placeholderText: qsTr("操作名称")
                }
            }

            SettingItem {
                title: qsTr("图标")
                ToolButton {
                    id: iconButton
                    icon.name: "ic_fluent_apps_20_regular"
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
                title: qsTr("类型")
                ComboBox {
                    id: typeCombo
                    width: 300
                    currentIndex: 0
                    model: [qsTr("文件 / 程序"), qsTr("命令行"), qsTr("网址"), qsTr("键鼠模拟")]
                    onCurrentIndexChanged: actionEditorDialog.actionType =
                        actionEditorDialog.actionTypes[currentIndex]
                }
            }

            SettingItem {
                title: qsTr("目标")
                TextField {
                    id: targetField
                    width: 400
                    enabled: actionEditorDialog.actionType !== "keymouse"
                    placeholderText: actionEditorDialog.targetHint()
                }
            }

            SettingItem {
                title: qsTr("参数")
                TextField {
                    id: argsField
                    width: 400
                    placeholderText: qsTr("参数 (可选)")
                }
            }

            SettingItem {
                title: qsTr("工作目录")
                TextField {
                    id: workdirField
                    width: 400
                    placeholderText: qsTr("工作目录 (可选)")
                }
            }

            SettingItem {
                title: qsTr("分类")
                ComboBox {
                    id: categoryCombo
                    width: 300
                    currentIndex: 0
                    model: ConfigManager.getCategoriesModel()
                }
            }

            SettingItem {
                title: qsTr("热键")
                TextField {
                    id: hotkeyField
                    width: 300
                    readOnly: true
                    placeholderText: qsTr("点击输入热键...")
                }
            }

            SettingItem {
                title: qsTr("提示")
                TextField {
                    id: tooltipField
                    width: 400
                    placeholderText: qsTr("鼠标悬停提示 (可选)")
                }
            }

            SettingItem {
                title: qsTr("启用")
                Switch {
                    id: enabledSwitch
                    checked: true
                }
            }
        }

        FluentPage {
            title: ""
            spacing: 16
            padding: 24

            SettingItem {
                title: qsTr("以管理员身份运行")
                Switch {
                    id: adminSwitch
                    checked: false
                }
            }

            SettingItem {
                title: qsTr("排序顺序")
                SpinBox {
                    id: orderSpin
                    width: 200
                    from: -1000
                    to: 1000
                    value: 0
                }
            }
        }

        FluentPage {
            title: ""
            spacing: 16
            padding: 24

            Row {
                spacing: 8
                Button {
                    text: qsTr("添加按键")
                    icon.name: "ic_fluent_keyboard_20_regular"
                    onClicked: actionEditorDialog.addStep("key")
                }
                Button {
                    text: qsTr("添加鼠标")
                    icon.name: "ic_fluent_mouse_20_regular"
                    onClicked: actionEditorDialog.addStep("mouse")
                }
                Button {
                    text: qsTr("添加等待")
                    icon.name: "ic_fluent_clock_20_regular"
                    onClicked: actionEditorDialog.addStep("wait")
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: actionEditorDialog.steps

                delegate: KeymouseStepDelegate {
                    width: ListView.view.width
                    stepData: modelData
                    onDeleteRequested: actionEditorDialog.removeStep(index)
                }
            }

            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: 11
                color: Theme.currentTheme.colors.textSecondaryColor
                text: qsTr("提示: 按键支持组合键（如 Ctrl+C）。鼠标坐标为屏幕绝对坐标，留空表示当前位置。")
            }
        }
    }

    function targetHint() {
        return [
            qsTr("选择文件或程序"),
            qsTr("命令 (如: ping)"),
            qsTr("网址 (如: https://example.com)"),
            qsTr("在「键鼠序列」中配置")
        ][actionTypes.indexOf(actionType)]
    }

    function addStep(kind) {
        var next = steps.slice()
        if (kind === "key") {
            next.push({ "type": "key", "key": "", "action": "press", "duration": 0 })
        } else if (kind === "mouse") {
            next.push({ "type": "mouse", "action": "click", "button": "left", "duration": 0 })
        } else {
            next.push({ "type": "wait", "duration": 0.5 })
        }
        steps = next
    }

    function removeStep(index) {
        var next = steps.slice()
        next.splice(index, 1)
        steps = next
    }

    function saveAction() {
        if (!nameField.text.trim()) {
            ConfigManager.notify(qsTr("请输入操作名称"), "warning")
            return
        }
        var target = targetField.text.trim()
        if (actionType !== "keymouse" && !target) {
            ConfigManager.notify(qsTr("请填写操作目标"), "warning")
            return
        }

        var action = {
            id: actionData ? actionData.id : "",
            name: nameField.text.trim(),
            icon: iconButton.icon.name,
            type: actionType,
            target: target,
            arguments: argsField.text.trim(),
            working_dir: workdirField.text.trim(),
            run_as: adminSwitch.checked ? "admin" : "user",
            keymouse_steps: actionType === "keymouse" ? steps : [],
            category: categoryCombo.model[categoryCombo.currentIndex],
            enabled: enabledSwitch.checked,
            hotkey: hotkeyField.text,
            tooltip: tooltipField.text.trim(),
            order: orderSpin.value
        }

        if (isNew) {
            ConfigManager.addAction(action)
        } else {
            ConfigManager.updateAction(action)
        }
    }

    function newAction() {
        isNew = true
        actionData = null
        actionType = "file"
        steps = []
        tabBar.currentIndex = 0
        nameField.text = ""
        iconButton.icon.name = "ic_fluent_apps_20_regular"
        typeCombo.currentIndex = 0
        targetField.text = ""
        argsField.text = ""
        workdirField.text = ""
        categoryCombo.currentIndex = 0
        hotkeyField.text = ""
        tooltipField.text = ""
        enabledSwitch.checked = true
        adminSwitch.checked = false
        orderSpin.value = 0
        open()
    }

    function editAction(action) {
        isNew = false
        actionData = action
        actionType = action.type || "file"
        // A detached copy, so cancelling the dialog leaves the config untouched.
        steps = JSON.parse(JSON.stringify(action.keymouse_steps || []))
        tabBar.currentIndex = 0
        nameField.text = action.name || ""
        iconButton.icon.name = action.icon || "ic_fluent_apps_20_regular"
        typeCombo.currentIndex = Math.max(0, actionTypes.indexOf(actionType))
        targetField.text = action.target || ""
        argsField.text = action.arguments || ""
        workdirField.text = action.working_dir || ""
        categoryCombo.currentIndex = ConfigManager.getCategoryIndex(action.category)
        hotkeyField.text = action.hotkey || ""
        tooltipField.text = action.tooltip || ""
        enabledSwitch.checked = action.enabled !== false
        adminSwitch.checked = action.run_as === "admin"
        orderSpin.value = action.order || 0
        open()
    }
}
