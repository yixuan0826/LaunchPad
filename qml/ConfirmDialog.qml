import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import RinUI

// Reusable confirmation prompt.
//
// Replaces the `Qt.createQmlObject()` dialogs the app used before, which
// re-parsed QML at runtime and leaked one object per invocation:
//
//     confirmDialog.ask("确定要删除吗？", function() { ... })
QQC2.Dialog {
    id: confirmDialog

    property string message: ""
    property var callback: null

    title: qsTr("确认")
    modal: true
    standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.No
    width: 380

    function ask(text, action) {
        message = text
        callback = action
        open()
    }

    onAccepted: {
        if (callback) {
            callback()
        }
    }

    Text {
        id: messageLabel
        width: parent.width
        wrapMode: Text.Wrap
        color: Theme.currentTheme.colors.textColor
        text: confirmDialog.message
    }
}
