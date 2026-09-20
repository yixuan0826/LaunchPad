import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

// 一个分类的标题栏 + 该分类下条目的网格。
ColumnLayout {
    id: section

    property string categoryName: ""
    property string categoryIcon: ""
    property var entries: []
    property real tileSize: 104
    // >0 时把网格宽度夹到「每行正好这么多格」，0 表示按可用宽度自由换行。
    property int columns: 0
    property bool collapsed: false

    signal entryActivated(var entry)
    signal entryMenuRequested(var entry, real sceneX, real sceneY)

    // 把整个分区（标题栏 + 网格）夹到「每行正好 N 格」的宽度，两者才对得齐。
    readonly property real maxGridWidth: columns > 0
        ? columns * tileSize + (columns - 1) * grid.spacing
        : Number.POSITIVE_INFINITY

    spacing: 10

    Frame {
        Layout.fillWidth: true
        implicitHeight: 52
        radius: 8

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            AppIcon {
                anchors.verticalCenter: parent.verticalCenter
                iconKey: section.categoryIcon
                iconSize: 20
                tint: Theme.currentTheme.colors.primaryColor
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.bold: true
                color: Theme.currentTheme.colors.textColor
                text: section.categoryName
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.currentTheme.colors.textSecondaryColor
                text: qsTr("%1 项").arg(section.entries.length)
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: section.collapsed = !section.collapsed
        }

        ToolButton {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            icon.name: "ic_fluent_chevron_down_20_regular"
            rotation: section.collapsed ? -90 : 0
            ToolTip.text: section.collapsed ? qsTr("展开") : qsTr("折叠")
            onClicked: section.collapsed = !section.collapsed

            Behavior on rotation {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }
    }

    Flow {
        id: grid

        Layout.fillWidth: true
        Layout.preferredHeight: visible ? childrenRect.height : 0
        visible: !section.collapsed
        spacing: 12

        Repeater {
            model: section.entries

            delegate: EntryTile {
                entry: modelData
                tileSize: section.tileSize
                onActivated: section.entryActivated(modelData)
                onMenuRequested: section.entryMenuRequested(modelData, sceneX, sceneY)
            }
        }
    }
}
