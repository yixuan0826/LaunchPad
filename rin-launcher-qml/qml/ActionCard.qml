import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

Frame {
    id: actionCard
    width: 96
    height: 96
    radius: 12
    border.color: Theme.currentTheme.colors.borderColor
    border.width: 1
    clip: true
    
    property var actionData: null
    signal clicked(var actionData)
    signal contextMenu(var actionData, real mouseX, real mouseY)
    
    property bool hovered: false
    property bool pressed: false
    
    // Hover/press effects
    states: [
        State {
            name: "hovered"
            when: hovered
            PropertyChanges { target: actionCard; border.color: Theme.currentTheme.colors.primaryColor; elevation: 4 }
        },
        State {
            name: "pressed"
            when: pressed
            PropertyChanges { target: actionCard; background: Theme.currentTheme.colors.secondaryContainerColor; elevation: 1 }
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
        onEntered: actionCard.hovered = true
        onExited: actionCard.hovered = false
        onPressed: actionCard.pressed = true
        onReleased: {
            actionCard.pressed = false
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
            color: Theme.currentTheme.colors.textPrimaryColor
            text: actionData.name
        }
        
        // Hotkey hint
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 8
            font.family: "Consolas"
            color: Theme.currentTheme.colors.textSecondaryColor
            text: actionData.hotkey || ""
            visible: actionData.hotkey && actionData.hotkey.length > 0
        }
    }
}