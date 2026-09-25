import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

import "../components"

// 启动台槽位编辑器：加一格 / 改一格。
//
// 槽位有四种，表单里只显示与当前类型相关的那几行 —— 与其把所有字段都摆出来再
// 灰掉，不如按类型换表单，少一层判断也少一处看走眼的机会。
// 「动作」类槽位有两种来源：引用「档案」里的条目（默认），或者直接在这里把
// 动作写全（内联动作，不需要先建条目）。
AppDialog {
    id: editor

    property int row: 0
    property int index: -1          // -1 表示新增
    property var slot: ({})

    // ── 表单状态 ──
    property string kind: "action"
    property string actionSource: "archive"   // archive | custom
    property string ref: ""
    property string toolKey: ""
    property string path: ""
    property string label: ""
    property string iconKey: ""

    // 下拉的模型与后端取值
    property var actionNames: []
    property var actionIds: []
    property var toolNames: []
    property var toolKeys: []
    property var drives: []

    signal saved()

    title: index < 0 ? qsTr("添加槽位") : qsTr("编辑槽位")
    preferredWidth: 620
    preferredHeight: 560
    // 表单里有没保存的改动，点遮罩别把输入丢掉。
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
        spacing: 10

        // ── 预览 ──
        Frame {
            Layout.fillWidth: true
            Layout.preferredHeight: 92

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                AppIcon {
                    Layout.alignment: Qt.AlignVCenter
                    iconKey: editor.iconKey.length > 0 ? editor.iconKey : editor.previewIcon
                    iconSize: 40
                    tint: Theme.currentTheme.colors.primaryColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                        font.bold: true
                        color: Theme.currentTheme.colors.textColor
                        text: editor.previewName
                    }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.NoWrap
                        elide: Text.ElideMiddle
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: editor.previewDetail
                    }
                }
            }
        }

        FormRow {
            label: qsTr("类型")
            description: qsTr("决定这一格点了之后干什么")
            ComboBox {
                Layout.fillWidth: true
                Layout.maximumWidth: 300
                model: [qsTr("动作（档案条目 / 自定义）"), qsTr("内置功能"),
                        qsTr("文件 / 文件夹 / 磁盘"), qsTr("可移动磁盘（自动检测）")]
                currentIndex: editor.kindIndex
                function onActivated(index) {
                    editor.kind = editor.indexOfKind(index)
                }
            }
        }

        // ── 动作来源：档案条目 / 自定义动作 ──
        FormRow {
            visible: editor.kind === "action"
            label: qsTr("来源")
            description: qsTr("引用档案里的条目，或直接在这里把动作写全")
            ComboBox {
                Layout.fillWidth: true
                Layout.maximumWidth: 320
                model: [qsTr("档案条目"), qsTr("自定义动作")]
                currentIndex: editor.actionSource === "custom" ? 1 : 0
                function onActivated(index) {
                    editor.actionSource = index === 1 ? "custom" : "archive"
                }
            }
        }

        // ── 档案条目 ──
        FormRow {
            visible: editor.kind === "action" && editor.actionSource === "archive"
            label: qsTr("条目")
            description: qsTr("候选来自「档案」页")
            ComboBox {
                Layout.fillWidth: true
                Layout.maximumWidth: 320
                model: editor.actionNames
                currentIndex: Math.max(0, editor.actionIds.indexOf(editor.ref))
                function onActivated(index) {
                    editor.ref = editor.actionIds[index] || ""
                }
            }
        }

        // ── 自定义动作：槽位自带完整定义，不必先进「档案」──
        ActionForm {
            id: inlineAction
            visible: editor.kind === "action" && editor.actionSource === "custom"
        }

        // ── 内置功能 ──
        FormRow {
            visible: editor.kind === "tool"
            label: qsTr("功能")
            description: qsTr("小窗自带的操作")
            ComboBox {
                Layout.fillWidth: true
                Layout.maximumWidth: 320
                model: editor.toolNames
                currentIndex: Math.max(0, editor.toolKeys.indexOf(editor.toolKey))
                function onActivated(index) {
                    editor.toolKey = editor.toolKeys[index] || ""
                }
            }
        }

        // ── 文件 / 文件夹 / 磁盘 ──
        FormRow {
            visible: editor.kind === "path"
            label: qsTr("路径")
            description: qsTr("点开就打开这个位置")
            TextField {
                Layout.fillWidth: true
                placeholderText: qsTr("例如 D:\\ 或 C:\\Tools")
                text: editor.path
                onTextChanged: editor.path = text
            }
            ToolButton {
                icon.name: "ic_fluent_folder_open_20_regular"
                ToolTip.text: qsTr("选一个文件夹")
                onClicked: {
                    var picked = ConfigManager.pickFolder()
                    if (picked.length > 0) {
                        editor.path = picked
                    }
                }
            }
            ToolButton {
                icon.name: "ic_fluent_document_20_regular"
                ToolTip.text: qsTr("选一个文件")
                onClicked: {
                    var picked = ConfigManager.pickFile()
                    if (picked.length > 0) {
                        editor.path = picked
                    }
                }
            }
        }

        FormRow {
            visible: editor.kind === "path" && editor.drives.length > 0
            label: qsTr("磁盘")
            description: qsTr("一键把路径填成某个盘")
            ComboBox {
                Layout.fillWidth: true
                Layout.maximumWidth: 320
                model: editor.driveLabels
                function onActivated(index) {
                    editor.path = editor.drives[index].path
                }
            }
        }

        FormRow {
            visible: editor.kind === "usb"
            label: qsTr("可移动磁盘")
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                typography: Typography.Caption
                color: Theme.currentTheme.colors.textSecondaryColor
                text: qsTr("插上 U 盘 / 移动硬盘后自动识别第一个，不需要指定盘符。")
            }
        }

        FormRow {
            label: qsTr("显示名")
            description: qsTr("留空就用目标自己的名字")
            TextField {
                Layout.fillWidth: true
                Layout.maximumWidth: 320
                placeholderText: qsTr("（可选）")
                text: editor.label
                onTextChanged: editor.label = text
            }
        }

        FormRow {
            label: qsTr("图标")
            description: qsTr("留空就用目标自己的图标")
            ToolButton {
                icon.name: "ic_fluent_apps_add_in_20_regular"
                ToolTip.text: qsTr("从图标库中选择")
                onClicked: {
                    iconPicker.current = editor.iconKey
                    iconPicker.open()
                }
            }
            ToolButton {
                icon.name: "ic_fluent_arrow_download_20_regular"
                ToolTip.text: qsTr("从文件获取图标（程序 / 快捷方式 / 图片）")
                onClicked: {
                    iconPicker.current = editor.iconKey
                    iconPicker.openTab(3)
                }
            }
            AppIcon {
                Layout.alignment: Qt.AlignVCenter
                iconKey: editor.iconKey
                iconSize: 22
                placeholder: "ic_fluent_dismiss_20_regular"
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.NoWrap
                elide: Text.ElideMiddle
                typography: Typography.Caption
                color: Theme.currentTheme.colors.textSecondaryColor
                text: editor.iconKey
            }
            ToolButton {
                icon.name: "ic_fluent_delete_20_regular"
                ToolTip.text: qsTr("清除图标")
                enabled: editor.iconKey.length > 0
                onClicked: editor.iconKey = ""
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
    // 取值
    // ------------------------------------------------------------------
    readonly property var kindOrder: ["action", "tool", "path", "usb"]
    readonly property int kindIndex: Math.max(0, kindOrder.indexOf(kind))

    readonly property var driveLabels: drives.map(function (item) {
        return item.total.length > 0
            ? "%1（%2，剩余 %3）".arg(item.label).arg(item.kindLabel).arg(item.free)
            : "%1（%2）".arg(item.label).arg(item.kindLabel)
    })

    function indexOfKind(index) {
        return kindOrder[index] || "action"
    }

    readonly property string previewName: {
        if (label.length > 0) {
            return label
        }
        if (kind === "action") {
            if (actionSource === "custom") {
                return editor.deriveActionName()
            }
            var at = actionIds.indexOf(ref)
            return at >= 0 ? actionNames[at] : qsTr("未选择条目")
        }
        if (kind === "tool") {
            var ti = toolKeys.indexOf(toolKey)
            return ti >= 0 ? toolNames[ti] : qsTr("未选择功能")
        }
        if (kind === "usb") {
            return qsTr("可移动磁盘")
        }
        return path.length > 0 ? path : qsTr("未设置路径")
    }

    // 内联动作没有名字：按类型从目标里取一个一眼能懂的显示名（与后端一致）。
    function deriveActionName() {
        var data = inlineAction.read()
        if (data.type === "keymouse") {
            return qsTr("键鼠动作")
        }
        if (data.target.length === 0) {
            return qsTr("未配置动作")
        }
        if (data.type === "url") {
            return data.target
        }
        var parts = data.target.replace(/\\/g, "/").split("/")
        return parts[parts.length - 1] || data.target
    }

    readonly property string previewDetail: {
        if (kind === "action") {
            return actionSource === "custom"
                ? qsTr("自定义动作 · 直接写在这一格里")
                : qsTr("档案条目 · 候选来自档案页")
        }
        if (kind === "tool") {
            return qsTr("内置功能")
        }
        if (kind === "usb") {
            return qsTr("自动识别第一个可移动磁盘")
        }
        return qsTr("打开路径 · %1").arg(path.length > 0 ? path : qsTr("未设置"))
    }

    readonly property string previewIcon: {
        if (kind === "action") {
            return "ic_fluent_apps_20_regular"
        }
        if (kind === "tool") {
            return "ic_fluent_wrench_20_regular"
        }
        if (kind === "usb") {
            return "ic_fluent_usb_plug_20_regular"
        }
        return "ic_fluent_folder_open_20_regular"
    }

    // ------------------------------------------------------------------
    // 打开与提交
    // ------------------------------------------------------------------
    function openFor(targetRow, targetIndex, existing) {
        row = targetRow
        index = targetIndex
        slot = existing || {}

        kind = slot.kind || "action"
        ref = slot.ref || ""
        toolKey = slot.key || ""
        path = slot.path || ""
        label = slot.label || ""
        iconKey = slot.icon || ""
        // 内联动作与条目引用二选一；两者都写过时按后端的口径以 ref 为准。
        actionSource = (slot.action && !slot.ref) ? "custom" : "archive"
        inlineAction.load(slot.action || {})

        // 候选每次都重取：档案可能刚改过。
        var actions = ConfigManager.getActions()
        actionNames = actions.map(function (item) { return item.name })
        actionIds = actions.map(function (item) { return item.id })

        var tools = ConfigManager.getToolCatalog()
        toolNames = tools.map(function (item) { return item.title })
        toolKeys = tools.map(function (item) { return item.key })

        drives = ConfigManager.getDrives()
        open()
    }

    function commit() {
        var customAction = kind === "action" && actionSource === "custom"
        if (customAction) {
            var invalid = inlineAction.validate()
            if (invalid.length > 0) {
                ConfigManager.notify(invalid, "warning")
                return
            }
        } else if (kind === "action" && ref.length === 0) {
            ConfigManager.notify(qsTr("请先选一个档案条目"), "warning")
            return
        }
        if (kind === "path" && path.trim().length === 0) {
            ConfigManager.notify(qsTr("请先填一个路径"), "warning")
            return
        }

        var payload = {
            "kind": kind,
            "label": label.trim(),
            "icon": iconKey,
            "ref": (kind === "action" && !customAction) ? ref : "",
            "key": kind === "tool" ? toolKey : "",
            "path": kind === "path" ? path.trim() : "",
            "action": customAction ? inlineAction.read() : null
        }
        var ok = index < 0
            ? ConfigManager.addLauncherSlot(row, payload)
            : ConfigManager.updateLauncherSlot(row, index, payload)
        if (!ok) {
            ConfigManager.notify(qsTr("保存失败，可以看看日志"), "error")
            return
        }
        saved()
        accept()
    }
}
