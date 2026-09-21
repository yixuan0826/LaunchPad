import QtQuick 2.15
import QtQuick.Controls 2.15
import RinUI

// 常驻小窗网格里的一个条目卡片。
//
// 没有复用 EntryTile：那个是给大窗口 96~144px 方块用的，字号写死在 12px，
// 缩到小窗的 66px 会把两行标题挤成一团。这里改成图标在上、单行标题在下。
Item {
    id: tile

    property var entry: null
    property real tileSize: 66

    signal activated(var entry)
    signal menuRequested(var entry, real sceneX, real sceneY)

    readonly property bool entryDisabled: entry ? entry.enabled === false : false

    width: tileSize
    height: tileSize
    opacity: entryDisabled ? 0.45 : 1

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: pointer.pressed || pointer.hovered
            ? Theme.currentTheme.colors.controlSecondaryColor
            : "transparent"
        border.width: pointer.hovered ? 1 : 0
        border.color: Theme.currentTheme.colors.primaryColor

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
            iconKey: tile.entry ? tile.entry.icon : ""
            iconSize: Math.round(tile.tileSize * 0.34)
            tint: tile.entryDisabled
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
            text: tile.entry ? tile.entry.name : ""
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
