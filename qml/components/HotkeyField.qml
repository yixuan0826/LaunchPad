import QtQuick 2.15
import QtQuick.Controls 2.15
import RinUI

// 全局热键录入框。
//
// 点击后直接按下组合键即可录入，输出 "Ctrl+Space" 形式的字符串（与
// rin_launcher.hotkey.to_pynput_spec 的解析格式一致）。单独按下修饰键不会
// 产生结果，只按一个普通键也不会被接受 —— 裸键会吞掉系统里的正常输入。
Item {
    id: field

    property string value: ""
    property string placeholder: qsTr("点击后按下组合键")
    readonly property bool capturing: activeFocus

    signal edited(string sequence)

    implicitWidth: 240
    implicitHeight: 32
    activeFocusOnTab: true

    readonly property var specialKeys: {
        var map = {}
        map[Qt.Key_Space] = "Space"
        map[Qt.Key_Return] = "Enter"
        map[Qt.Key_Enter] = "Enter"
        map[Qt.Key_Tab] = "Tab"
        map[Qt.Key_Escape] = "Esc"
        map[Qt.Key_Backspace] = "Backspace"
        map[Qt.Key_Delete] = "Delete"
        map[Qt.Key_Insert] = "Insert"
        map[Qt.Key_Home] = "Home"
        map[Qt.Key_End] = "End"
        map[Qt.Key_PageUp] = "PageUp"
        map[Qt.Key_PageDown] = "PageDown"
        map[Qt.Key_Up] = "Up"
        map[Qt.Key_Down] = "Down"
        map[Qt.Key_Left] = "Left"
        map[Qt.Key_Right] = "Right"
        map[Qt.Key_Print] = "PrintScreen"
        map[Qt.Key_Pause] = "Pause"
        return map
    }

    // 纯修饰键 / 锁定键不参与组合，按下它们时返回空串。
    readonly property var ignoredKeys: [
        Qt.Key_Control, Qt.Key_Alt, Qt.Key_Shift, Qt.Key_Meta, Qt.Key_AltGr,
        Qt.Key_CapsLock, Qt.Key_NumLock, Qt.Key_ScrollLock, Qt.Key_Super_L,
        Qt.Key_Super_R, Qt.Key_Menu
    ]

    function keyName(key) {
        if (ignoredKeys.indexOf(key) !== -1) {
            return ""
        }
        if (key >= Qt.Key_A && key <= Qt.Key_Z) {
            return String.fromCharCode(key)
        }
        if (key >= Qt.Key_0 && key <= Qt.Key_9) {
            return String.fromCharCode(key)
        }
        if (key >= Qt.Key_F1 && key <= Qt.Key_F24) {
            return "F" + (key - Qt.Key_F1 + 1)
        }
        return specialKeys[key] || ""
    }

    // 把一次按键事件翻译成配置里的热键写法；无法翻译或缺少修饰键时返回 ""。
    function sequenceFromEvent(event) {
        var name = keyName(event.key)
        if (!name) {
            return ""
        }
        var parts = []
        if (event.modifiers & Qt.ControlModifier) {
            parts.push("Ctrl")
        }
        if (event.modifiers & Qt.AltModifier) {
            parts.push("Alt")
        }
        if (event.modifiers & Qt.ShiftModifier) {
            parts.push("Shift")
        }
        if (event.modifiers & Qt.MetaModifier) {
            parts.push("Win")
        }
        if (parts.length === 0) {
            return ""
        }
        parts.push(name)
        return parts.join("+")
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.currentTheme.appearance.buttonRadius
        color: Theme.currentTheme.colors.controlColor
        border.width: Theme.currentTheme.appearance.borderWidth
        border.color: field.activeFocus
            ? Theme.currentTheme.colors.primaryColor
            : Theme.currentTheme.colors.controlBorderColor

        Behavior on border.color {
            ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: clearButton.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        font.family: "Consolas"
        color: field.value
            ? Theme.currentTheme.colors.textColor
            : Theme.currentTheme.colors.textSecondaryColor
        text: field.value
            ? field.value
            : field.capturing ? qsTr("请按下组合键…") : field.placeholder
    }

    ToolButton {
        id: clearButton
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 24
        icon.name: "ic_fluent_dismiss_20_regular"
        ToolTip.text: qsTr("清除热键")
        visible: field.value.length > 0
        onClicked: {
            field.value = ""
            field.edited("")
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: clearButton.visible ? clearButton.width : 0
        cursorShape: Qt.IBeamCursor
        onClicked: field.forceActiveFocus()
    }

    Keys.onPressed: function (event) {
        event.accepted = true
        if (event.key === Qt.Key_Escape) {
            field.focus = false
            return
        }
        var sequence = field.sequenceFromEvent(event)
        if (!sequence) {
            return
        }
        field.value = sequence
        field.edited(sequence)
    }
}
