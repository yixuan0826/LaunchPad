import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

import "../components"

// 条目编辑器：新建 / 修改启动台里的一个条目。
//
// 类型决定目标字段的含义；键鼠类型会额外启用「键鼠序列」分页。只有点「保存」
// 才写回配置，取消则原样丢弃临时状态。
AppDialog {
    id: editor

    readonly property var entryTypes: ["file", "cmd", "url", "keymouse"]

    property var entry: null            // null 表示新建
    property bool isNew: true
    property string entryType: "file"
    property var steps: []              // 键鼠序列（编辑期的副本）
    property string iconKey: "ic_fluent_apps_20_regular"
    property var categories: []
    // 热键只在编辑期缓存，保存时才落到条目上。
    property string entryHotkey: ""

    signal saved()

    title: isNew ? qsTr("新建条目") : qsTr("编辑条目")
    preferredWidth: 720
    preferredHeight: 620
    closeOnScrim: false

    // parent 显式指到弹窗根上：默认内容会被 body 那个 Layout 接管，嵌套弹窗
    // 要铺满整页就不能待在布局里。
    IconPickerDialog {
        id: iconPicker
        parent: editor
        onPicked: editor.iconKey = iconKey
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12

        TabBar {
            id: tabBar
            Layout.fillWidth: true
            TabButton { text: qsTr("基本") }
            TabButton {
                text: qsTr("键鼠序列")
                enabled: editor.entryType === "keymouse"
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: editor.entryType === "keymouse" ? tabBar.currentIndex : 0

            // ── 基本 ──
            Flickable {
                id: basicScroller
                clip: true
                contentWidth: width
                contentHeight: basicColumn.implicitHeight + 8
                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: basicColumn
                    width: basicScroller.width
                    spacing: 10

                    FormRow {
                        label: qsTr("名称")
                        TextField {
                            id: nameField
                            Layout.fillWidth: true
                            placeholderText: qsTr("显示在启动台上的名字")
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
                            wrapMode: Text.NoWrap
                            elide: Text.ElideMiddle
                            font.family: "Consolas"
                            color: Theme.currentTheme.colors.textSecondaryColor
                            text: editor.iconKey
                        }
                    }

                    FormRow {
                        label: qsTr("类型")
                        ComboBox {
                            id: typeCombo
                            Layout.preferredWidth: 200
                            model: [qsTr("文件 / 程序"), qsTr("命令行"), qsTr("网址"), qsTr("键鼠模拟")]
                            onCurrentIndexChanged: {
                                if (typeReady) {
                                    editor.entryType = editor.entryTypes[currentIndex]
                                }
                            }
                            property bool typeReady: false
                            Component.onCompleted: typeReady = true
                        }
                    }

                    FormRow {
                        label: qsTr("目标")
                        TextField {
                            id: targetField
                            Layout.fillWidth: true
                            placeholderText: editor.targetHint()
                            enabled: editor.entryType !== "keymouse"
                        }
                        ToolButton {
                            icon.name: "ic_fluent_folder_open_20_regular"
                            visible: editor.entryType === "file"
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
                            placeholderText: qsTr("启动参数（可选）")
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
                        label: qsTr("分类")
                        ComboBox {
                            id: categoryCombo
                            Layout.preferredWidth: 200
                            model: editor.categories
                        }
                    }

                    FormRow {
                        label: qsTr("热键")
                        HotkeyField {
                            id: hotkeyField
                            Layout.fillWidth: true
                            onEdited: editor.entryHotkey = sequence
                        }
                    }

                    FormRow {
                        label: qsTr("悬停提示")
                        TextField {
                            id: tooltipField
                            Layout.fillWidth: true
                            placeholderText: qsTr("鼠标悬停时显示（可选）")
                        }
                    }

                    FormRow {
                        label: qsTr("启用")
                        description: qsTr("停用后条目仍保留在档案里")
                        Switch {
                            id: enabledSwitch
                            checkedText: qsTr("已启用")
                            uncheckedText: qsTr("已停用")
                        }
                    }

                    FormRow {
                        label: qsTr("管理员运行")
                        description: qsTr("仅对文件 / 命令行类型有效")
                        Switch {
                            id: adminSwitch
                            enabled: editor.entryType === "file" || editor.entryType === "cmd"
                            checkedText: qsTr("是")
                            uncheckedText: qsTr("否")
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        wrapMode: Text.Wrap
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("目标支持 {configdir}、{homedir}、{desktop}、{documents}、{downloads} 等占位符，以及 %ENV% 环境变量。")
                    }
                }
            }

            // ── 键鼠序列 ──
            ColumnLayout {
                spacing: 8

                RowLayout {
                    spacing: 8
                    Button {
                        text: qsTr("添加按键")
                        icon.name: "ic_fluent_keyboard_20_regular"
                        onClicked: editor.addStep("key")
                    }
                    Button {
                        text: qsTr("添加鼠标")
                        icon.name: "ic_fluent_cursor_20_regular"
                        onClicked: editor.addStep("mouse")
                    }
                    Button {
                        text: qsTr("添加等待")
                        icon.name: "ic_fluent_timer_20_regular"
                        onClicked: editor.addStep("wait")
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("共 %1 步").arg(editor.steps.length)
                    }
                }

                ListView {
                    id: stepList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: editor.steps
                    visible: editor.steps.length > 0

                    delegate: KeymouseStepDelegate {
                        width: stepList.width
                        stepData: modelData
                        onDeleteRequested: editor.removeStep(index)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: editor.steps.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.Wrap
                    color: Theme.currentTheme.colors.textSecondaryColor
                    text: qsTr("还没有任何步骤，先用上面的按钮添加一条。")
                }
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

    // ------------------------------------------------------------------
    // 行为
    // ------------------------------------------------------------------
    function targetHint() {
        var hints = [
            qsTr("选择文件或程序，例如 notepad.exe"),
            qsTr("命令行，例如 ping"),
            qsTr("网址，例如 https://example.com"),
            qsTr("在「键鼠序列」分页里配置")
        ]
        var index = entryTypes.indexOf(entryType)
        return index >= 0 ? hints[index] : hints[0]
    }

    function newEntry(presetCategory) {
        isNew = true
        entry = null
        entryType = "file"
        steps = []
        iconKey = "ic_fluent_apps_20_regular"
        entryHotkey = ""
        categories = ConfigManager.getCategoriesModel()
        tabBar.currentIndex = 0

        nameField.text = ""
        typeCombo.currentIndex = 0
        targetField.text = ""
        argsField.text = ""
        workdirField.text = ""
        tooltipField.text = ""
        enabledSwitch.checked = true
        adminSwitch.checked = false
        hotkeyField.value = ""

        var preset = presetCategory || ""
        var index = categories.indexOf(preset)
        categoryCombo.currentIndex = index >= 0 ? index : 0
        open()
    }

    function editEntry(item) {
        if (!item) {
            return
        }
        isNew = false
        entry = item
        entryType = item.type || "file"
        // 编辑副本，取消时不影响配置里的原数组。
        steps = JSON.parse(JSON.stringify(item.keymouse_steps || []))
        iconKey = item.icon || "ic_fluent_apps_20_regular"
        entryHotkey = item.hotkey || ""
        categories = ConfigManager.getCategoriesModel()
        tabBar.currentIndex = 0

        nameField.text = item.name || ""
        typeCombo.currentIndex = Math.max(0, entryTypes.indexOf(entryType))
        targetField.text = item.target || ""
        argsField.text = item.arguments || ""
        workdirField.text = item.working_dir || ""
        tooltipField.text = item.tooltip || ""
        enabledSwitch.checked = item.enabled !== false
        adminSwitch.checked = item.run_as === "admin"
        hotkeyField.value = entryHotkey
        categoryCombo.currentIndex = ConfigManager.getCategoryIndex(item.category)
        open()
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

    function commit() {
        var name = nameField.text.trim()
        if (!name) {
            ConfigManager.notify(qsTr("请先填写条目名称"), "warning")
            return
        }
        var target = targetField.text.trim()
        if (entryType !== "keymouse" && !target) {
            ConfigManager.notify(qsTr("请先填写条目目标"), "warning")
            return
        }
        var category = categories.length > 0 ? categories[categoryCombo.currentIndex] : ""

        var payload = {
            id: entry ? entry.id : "",
            name: name,
            icon: iconKey,
            type: entryType,
            target: target,
            arguments: argsField.text.trim(),
            working_dir: workdirField.text.trim(),
            run_as: adminSwitch.checked ? "admin" : "user",
            keymouse_steps: entryType === "keymouse" ? steps : [],
            category: category,
            enabled: enabledSwitch.checked,
            hotkey: entryHotkey,
            tooltip: tooltipField.text.trim(),
            order: entry ? (entry.order || 0) : 0
        }

        var ok = isNew ? ConfigManager.addAction(payload) : ConfigManager.updateAction(payload)
        if (!ok) {
            ConfigManager.notify(qsTr("保存失败，请查看日志"), "error")
            return
        }
        ConfigManager.notify(isNew
                             ? qsTr("已新建条目：%1").arg(name)
                             : qsTr("已更新条目：%1").arg(name), "success")
        saved()
        accept()
    }
}
