import QtQuick 2.15
import QtQuick.Controls 2.15
import RinUI

// 启动台网格里的一个可启动条目。
Frame {
    id: tile

    property var entry: null
    property real tileSize: 104

    // 激活 / 请求右键菜单；菜单信号带的是场景坐标，调用方再换算到自己的坐标系。
    signal activated(var entry)
    signal menuRequested(var entry, real sceneX, real sceneY)

    readonly property bool entryDisabled: entry ? entry.enabled === false : false

    width: tileSize
    height: tileSize
    radius: 12
    hoverable: false  // 悬停/按下的视觉交给下面的 MouseArea

    border.color: pointer.hovered
        ? Theme.currentTheme.colors.primaryColor
        : Theme.currentTheme.colors.cardBorderColor
    color: pointer.pressed
        ? Theme.currentTheme.colors.controlSecondaryColor
        : Theme.currentTheme.colors.cardColor
    opacity: entryDisabled ? 0.45 : 1

    Behavior on border.color {
        ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
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

    Column {
        anchors.centerIn: parent
        width: parent.width - 16
        spacing: 6

        AppIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            iconKey: tile.entry ? tile.entry.icon : ""
            iconSize: Math.round(tile.tileSize * 0.32)
            tint: tile.entryDisabled
                ? Theme.currentTheme.colors.textSecondaryColor
                : Theme.currentTheme.colors.primaryColor
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: 2
            font.pixelSize: 12
            font.bold: true
            color: Theme.currentTheme.colors.textColor
            text: tile.entry ? tile.entry.name : ""
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 9
            font.family: "Consolas"
            color: Theme.currentTheme.colors.textSecondaryColor
            text: tile.entry && tile.entry.hotkey ? tile.entry.hotkey : ""
            visible: text.length > 0
        }
    }
}
