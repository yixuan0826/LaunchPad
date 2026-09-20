import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

Frame {
    id: actionCard
    width: 96
    height: 96
    radius: 12
    border.color: Theme.currentTheme.colors.cardBorderColor
    border.width: 1
    clip: true
    hoverable: false  // Disable built-in hover to avoid conflict
    
    property var actionData: null
    signal clicked(var actionData)
    signal contextMenu(var actionData, real mouseX, real mouseY)
    
    property bool isHovered: false
    property bool isPressed: false
    
    // Hover/press effects
    states: [
        State {
            name: "hovered"
            when: isHovered
            PropertyChanges { target: actionCard; border.color: Theme.currentTheme.colors.primaryColor; elevation: 4 }
        },
        State {
            name: "pressed"
            when: isPressed
            PropertyChanges { target: actionCard; background: Theme.currentTheme.colors.cardSecondaryColor; elevation: 1 }
        }
    ]
    
    transitions: Transition {
        from: ""
        to: "hovered"
        ColorAnimation { target: actionCard; properties: "border.color"; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { target: actionCard; properties: "elevation"; duration: 150; easing.type: Easing.OutCubic }
    }
    
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: actionCard.isHovered = true
        onExited: actionCard.isHovered = false
        onPressed: actionCard.isPressed = true
        onReleased: {
            actionCard.isPressed = false
            if (containsMouse) {
                actionCard.clicked(actionData)
            }
        }
        onPressAndHold: {
            actionCard.contextMenu(actionData, mouseX, mouseY)
        }
    }
    
    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        
        // Icon
        IconWidget {
            id: actionIcon
            anchors.horizontalCenter: parent.horizontalCenter
            size: 32
            icon: actionData.icon || "\ueb95"
            color: Theme.currentTheme.colors.primaryColor
        }
        
        // Name
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
            text: actionData ? actionData.name : ""
        }
        
        // Hotkey hint
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 8
            font.family: "Consolas"
            color: Theme.currentTheme.colors.textSecondaryColor
            text: actionData && actionData.hotkey ? actionData.hotkey : ""
            visible: !!(actionData && actionData.hotkey && actionData.hotkey.length > 0)
        }
    }
}