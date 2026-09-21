import QtQuick 2.15
import QtQuick.Controls 2.15
import RinUI

// 常驻小窗第一行里的一格：图标在上、单行标题在下。
//
// 没有复用 EntryTile：那个是给完整窗口 96~144px 方块用的，字号写死在 12px，
// 缩到小窗的 92px 会把两行标题挤成一团。
Item {
    id: tile

    property var entry: null
    property real tileSize: 66

    signal activated(var entry)
    signal menuRequested(var entry, real sceneX, real sceneY)

    // 槽位固定 4 个，还没配的那格也要占着位置。
    readonly property bool empty: !entry || !entry.id
    readonly property bool entryDisabled: entry ? entry.enabled === false : false

    width: tileSize
    height: tileSize
    opacity: empty ? 0.28 : (entryDisabled ? 0.45 : 1)

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: pointer.pressed || pointer.hovered
            ? Theme.currentTheme.colors.controlSecondaryColor
            : "transparent"
        border.width: pointer.hovered || tile.empty ? 1 : 0
        border.color: tile.empty
            ? Theme.currentTheme.colors.cardBorderColor
            : Theme.currentTheme.colors.primaryColor

        Behavior on color {
            ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 8
        spacing: 4

        AppIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            iconKey: tile.empty ? "ic_fluent_add_20_regular" : tile.entry.icon
            iconSize: Math.round(tile.tileSize * 0.34)
            tint: tile.empty || tile.entryDisabled
                ? Theme.currentTheme.colors.textSecondaryColor
                : Theme.currentTheme.colors.primaryColor
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            font.pixelSize: 10
            color: Theme.currentTheme.colors.textColor
            text: tile.empty ? qsTr("未设置") : tile.entry.name
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onReleased: {
            if (mouse.button === Qt.LeftButton && containsMouse) {
                tile.activated(tile.entry)
            }
        }
        onClicked: {
            if (mouse.button === Qt.RightButton) {
                // 映射到场景坐标，菜单才能在任何父级里正确定位。
                var scene = tile.mapToItem(null, mouseX, mouseY)
                tile.menuRequested(tile.entry, scene.x, scene.y)
            }
        }
    }
}
