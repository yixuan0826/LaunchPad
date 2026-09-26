import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

// 动作参数表单：类型 / 目标 / 参数 / 工作目录 / 管理员，以及键鼠序列编辑器。
//
// 启动台格子编辑器（动作类）用这一份 —— 之前「快捷操作」和槽位两边各写一套
// 字段与校验，改一处漏一处；库那边改只读后只剩这一处消费方。
// 外部用 load() 灌入初始值、read() 取回一个动作对象。
ColumnLayout {
    id: form

    property string actionType: "file"
    property var steps: []

    readonly property var typeKeys: ["file", "cmd", "url", "keymouse"]

    Layout.fillWidth: true
    spacing: 10

    // ------------------------------------------------------------------
    // 取值
    // ------------------------------------------------------------------
    function load(data) {
        data = data || {}
        actionType = String(data.type || "file")
        steps = JSON.parse(JSON.stringify(data.keymouse_steps || []))
        typeCombo.currentIndex = Math.max(0, typeKeys.indexOf(actionType))
        targetField.text = data.target || ""
        argsField.text = data.arguments || ""
        workdirField.text = data.working_dir || ""
        adminSwitch.checked = data.run_as === "admin"
    }

    function read() {
        return {
            "type": actionType,
            "target": targetField.text.trim(),
            "arguments": argsField.text.trim(),
            "working_dir": workdirField.text.trim(),
            "run_as": adminSwitch.checked ? "admin" : "user",
            "keymouse_steps": actionType === "keymouse" ? steps : []
        }
    }

    // 保存前的校验；没问题时返回空串。
    function validate() {
        if (actionType === "keymouse") {
            // 一步都没有的键鼠动作点了也不会发生任何事，不如现在就拦住。
            return steps.length > 0 ? "" : qsTr("键鼠动作还一步都没有，先在下面添加一条步骤")
        }
        if (targetField.text.trim().length === 0) {
            return qsTr("请先填写动作目标")
        }
        return ""
    }

    function targetHint() {
        var hints = [
            qsTr("选择文件或程序，例如 notepad.exe"),
            qsTr("命令行，例如 ping"),
            qsTr("网址，例如 https://example.com"),
            qsTr("在下面的「键鼠序列」里配置")
        ]
        var index = typeKeys.indexOf(actionType)
        return index >= 0 ? hints[index] : hints[0]
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

    // ------------------------------------------------------------------
    // 表单
    // ------------------------------------------------------------------
    FormRow {
        label: qsTr("类型")
        ComboBox {
            id: typeCombo
            Layout.preferredWidth: 200
            model: [qsTr("文件 / 程序"), qsTr("命令行"), qsTr("网址"), qsTr("键鼠模拟")]
            // 只在用户真的选了才动状态：程序回填 currentIndex 会触发
            // currentIndexChanged，用 activated 才能把「读配置」和「改配置」分开。
            function onActivated(index) {
                form.actionType = form.typeKeys[index] || "file"
            }
        }
    }

    FormRow {
        label: qsTr("目标")
        TextField {
            id: targetField
            Layout.fillWidth: true
            placeholderText: form.targetHint()
            enabled: form.actionType !== "keymouse"
        }
        ToolButton {
            icon.name: "ic_fluent_folder_open_20_regular"
            visible: form.actionType === "file"
            ToolTip.text: qsTr("浏览文件")
            onClicked: {
                var picked = ConfigManager.pickFile()
                if (picked) {
                    targetField.text = picked
                }
            }
        }
    }

    FormRow {
        label: qsTr("参数")
        TextField {
            id: argsField
            Layout.fillWidth: true
            placeholderText: qsTr("启动参数（可选，含空格时整段加引号）")
        }
    }

    FormRow {
        label: qsTr("工作目录")
        TextField {
            id: workdirField
            Layout.fillWidth: true
            placeholderText: qsTr("留空则使用目标所在目录")
        }
    }

    FormRow {
        label: qsTr("管理员运行")
        description: qsTr("仅对文件 / 命令行类型有效")
        Switch {
            id: adminSwitch
            enabled: form.actionType === "file" || form.actionType === "cmd"
            checkedText: qsTr("是")
            uncheckedText: qsTr("否")
        }
    }

    // ── 键鼠序列（仅键鼠模拟需要）──
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        visible: form.actionType === "keymouse"
        spacing: 8

        Button {
            text: qsTr("添加按键")
            icon.name: "ic_fluent_keyboard_20_regular"
            onClicked: form.addStep("key")
        }
        Button {
            text: qsTr("添加鼠标")
            icon.name: "ic_fluent_cursor_20_regular"
            onClicked: form.addStep("mouse")
        }
        Button {
            text: qsTr("添加等待")
            icon.name: "ic_fluent_timer_20_regular"
            onClicked: form.addStep("wait")
        }
        Item { Layout.fillWidth: true }
        Text {
            Layout.alignment: Qt.AlignVCenter
            typography: Typography.Caption
            color: Theme.currentTheme.colors.textSecondaryColor
            text: qsTr("共 %1 步").arg(form.steps.length)
        }
    }

    Repeater {
        model: form.steps

        delegate: KeymouseStepDelegate {
            Layout.fillWidth: true
            visible: form.actionType === "keymouse"
            stepData: modelData
            onDeleteRequested: form.removeStep(index)
        }
    }

    Text {
        Layout.fillWidth: true
        visible: form.actionType === "keymouse" && form.steps.length === 0
        wrapMode: Text.Wrap
        typography: Typography.Caption
        color: Theme.currentTheme.colors.textSecondaryColor
        text: qsTr("还没有任何步骤，先用上面的按钮添加一条。")
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 4
        wrapMode: Text.Wrap
        typography: Typography.Caption
        color: Theme.currentTheme.colors.textSecondaryColor
        text: qsTr("目标支持 {configdir}、{homedir}、{desktop}、{documents}、{downloads} "
                   + "等占位符，以及 %ENV% 环境变量。")
    }
}
