import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

Column {
    id: categorySection
    width: parent.width
    spacing: 8
    property string categoryName
    property string categoryIcon
    property var actions
    signal actionClicked(var actionData)
    signal actionContextMenu(var actionData, real mouseX, real mouseY)
    
    // Category header
    SettingCard {
        width: parent.width
        title: categoryName
        description: ""
        icon.name: categoryIcon
        
        Row {
            Layout.fillWidth: true
            Repeater {
                model: actions
                delegate: ActionCard {
                    actionData: modelData
                    onClicked: categorySection.actionClicked(modelData)
                    onContextMenu: categorySection.actionContextMenu(modelData, mouseX, mouseY)
                }
            }
        }
    }
}