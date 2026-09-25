import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

import "../components"

// 条目编辑器：新建 / 修改启动台里的一个条目。
//
// 动作字段（类型 / 目标 / 参数 / 工作目录 / 管理员 / 键鼠序列）交给共享的
// ActionForm，这里只留「档案」特有的信息：名称、图标、分类、热键、悬停提示、
// 启用。只有点「保存」才写回配置，取消则原样丢弃临时状态。
AppDialog {
    id: editor

    property var entry: null            // null 表示新建
    property bool isNew: true
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

        Flickable {
            id: basicScroller
            Layout.fillWidth: true
            Layout.fillHeight: true
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

                    // 动作字段（类型 / 目标 / 参数 / 工作目录 / 管理员 / 键鼠序列）
                    // 与槽位编辑器共用同一份表单。
                    ActionForm {
                        id: actionForm
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
    function newEntry(presetCategory) {
        isNew = true
        entry = null
        iconKey = "ic_fluent_apps_20_regular"
        entryHotkey = ""
        categories = ConfigManager.getCategoriesModel()

        nameField.text = ""
        actionForm.load({})
        tooltipField.text = ""
        enabledSwitch.checked = true
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
        iconKey = item.icon || "ic_fluent_apps_20_regular"
        entryHotkey = item.hotkey || ""
        categories = ConfigManager.getCategoriesModel()

        nameField.text = item.name || ""
        // ActionForm 自己会复制一份键鼠序列，取消编辑不会影响配置里的原数组。
        actionForm.load(item)
        tooltipField.text = item.tooltip || ""
        enabledSwitch.checked = item.enabled !== false
        hotkeyField.value = entryHotkey
        categoryCombo.currentIndex = ConfigManager.getCategoryIndex(item.category)
        open()
    }

    function commit() {
        var name = nameField.text.trim()
        if (!name) {
            ConfigManager.notify(qsTr("请先填写条目名称"), "warning")
            return
        }
        var invalid = actionForm.validate()
        if (invalid.length > 0) {
            ConfigManager.notify(invalid, "warning")
            return
        }
        var action = actionForm.read()
        var category = categories.length > 0 ? categories[categoryCombo.currentIndex] : ""

        var payload = {
            id: entry ? entry.id : "",
            name: name,
            icon: iconKey,
            type: action.type,
            target: action.target,
            arguments: action.arguments,
            working_dir: action.working_dir,
            run_as: action.run_as,
            keymouse_steps: action.keymouse_steps,
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
