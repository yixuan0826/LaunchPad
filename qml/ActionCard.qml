import QtQuick 2.15
import QtQuick.Controls 2.15
import RinUI

// A single launchable action: icon, name and optional hotkey hint.
Frame {
    id: actionCard
    width: 96
    height: 96
    radius: 12
    hoverable: false // the MouseArea below owns the hover/press look

    property var actionData: null

    signal clicked(var actionData)
    signal contextMenu(var actionData, real mouseX, real mouseY)

    border.color: mouseArea.containsMouse
        ? Theme.currentTheme.colors.primaryColor
        : Theme.currentTheme.colors.cardBorderColor
    color: mouseArea.pressed
        ? Theme.currentTheme.colors.controlSecondaryColor
        : Theme.currentTheme.colors.cardColor
    opacity: mouseArea.pressed ? 0.7 : 1

    Behavior on border.color {
        ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onReleased: {
            if (containsMouse) {
                actionCard.clicked(actionCard.actionData)
            }
        }
        onPressAndHold: actionCard.contextMenu(actionCard.actionData, mouseX, mouseY)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        IconWidget {
            anchors.horizontalCenter: parent.horizontalCenter
            size: 32
            icon: actionCard.actionData ? actionCard.actionData.icon : ""
            color: Theme.currentTheme.colors.primaryColor
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: 2
            font.pixelSize: 12
            font.bold: true
            color: Theme.currentTheme.colors.textColor
            text: actionCard.actionData ? actionCard.actionData.name : ""
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 8
            font.family: "Consolas"
            color: Theme.currentTheme.colors.textSecondaryColor
            text: actionCard.actionData && actionCard.actionData.hotkey ? actionCard.actionData.hotkey : ""
            visible: text.length > 0
        }
    }
}
