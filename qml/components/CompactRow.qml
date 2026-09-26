import QtQuick 2.15
import QtQuick.Controls 2.15
import RinUI

// 小窗里的一行：横向铺开若干 CompactTile。
//
// 面板把两排都交给它渲染（尺寸由面板统一指定）；格子放不下时横向滑，
// 与其把格子越压越小，滚动更能保住图标的可读性。
Item {
    id: row

    property var slots: []
    property string style: "big"     // big | mini
    property int maxTileSize: 76
    // 面板给两排指定统一个头；0 = 按格子数自己算。
    property real tileSizeOverride: 0

    signal activated(var slot)
    signal menuRequested(var slot, real sceneX, real sceneY)

    readonly property bool mini: style === "mini"
    readonly property int gap: mini ? 6 : 10
    // 大格子边长跟着宽度走，但有上下限：太少不至于撑成巨块，太多也不会缩成点。
    readonly property real tileSize: {
        if (tileSizeOverride > 0) {
            return tileSizeOverride
        }
        if (slots.length === 0) {
            return maxTileSize
        }
        var available = width - (slots.length - 1) * gap
        return Math.max(48, Math.min(maxTileSize, Math.floor(available / slots.length)))
    }
    readonly property real cellWidth: mini
        ? Math.max(48, Math.min(72, Math.floor((width - (slots.length - 1) * gap)
                                               / Math.max(1, slots.length))))
        : tileSize
    readonly property real cellHeight: mini ? 58 : tileSize

    Flickable {
        id: flick

        anchors.fill: parent
        clip: true
        contentWidth: content.implicitWidth
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        // 只有真的放不下时才允许拖动，否则会误吞鼠标事件。
        interactive: contentWidth > width + 1

        Row {
            id: content

            // 放得下居中、放不下靠左，滚动内容不会从中间开始。
            x: Math.max(0, (flick.width - content.implicitWidth) / 2)
            y: Math.max(0, (flick.height - content.implicitHeight) / 2)
            spacing: row.gap

            Repeater {
                model: row.slots

                delegate: CompactTile {
                    width: row.cellWidth
                    height: row.cellHeight
                    style: row.mini ? "mini" : "big"
                    slot: modelData
                    onActivated: row.activated(slot)
                    onMenuRequested: row.menuRequested(slot, sceneX, sceneY)
                }
            }
        }
    }
}
