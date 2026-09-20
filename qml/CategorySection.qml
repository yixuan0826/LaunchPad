import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

// One category header with its row of action cards.
Column {
    id: categorySection
    Layout.fillWidth: true
    spacing: 8

    property string categoryName
    property string categoryIcon
    property var actions: []

    signal actionClicked(var actionData)
    signal actionContextMenu(var actionData, real mouseX, real mouseY)

    SettingCard {
        width: parent.width
        title: categorySection.categoryName
        description: ""
        icon.name: categorySection.categoryIcon

        Row {
            spacing: 8

            Repeater {
                model: categorySection.actions

                delegate: ActionCard {
                    actionData: modelData
                    onClicked: categorySection.actionClicked(modelData)
                    onContextMenu: categorySection.actionContextMenu(modelData, mouseX, mouseY)
                }
            }
        }
    }
}
