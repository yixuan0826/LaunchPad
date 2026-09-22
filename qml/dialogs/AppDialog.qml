import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

// 弹窗基类：整页遮罩 + 居中卡片。
//
// 刻意不用 Qt 的 Popup / RinUI 的 Dialog：主窗是自绘窗口，Popup 的尺寸与定位会
// 绕到 QQC2.Overlay 上，拿不到 overlay 时位置和高度都是错的（弹窗贴到页面角上、
// 还可能算出 NaN）。这里就是个普通 Item —— 铺满所在页面、居中放一张卡片，不依赖
// 任何窗口层特性，换窗口实现也不会变。
//
// 派生文件照旧写「title + 子项 + footer」：子项进 body，footer 被挪到卡片底部。
Item {
    id: root

    // 期望尺寸；超出页面时收缩。preferredHeight = 0 表示按内容撑高。
    property real preferredWidth: 520
    property real preferredHeight: 0
    property string title: ""
    // 点遮罩是否关掉（含未保存的编辑器时由派生文件关掉）。
    property bool closeOnScrim: true
    // 派生文件里的 footer: RowLayout { ... }
    property Item footer: null

    default property alias content: body.data

    signal aboutToShow()
    signal accepted()
    signal rejected()

    anchors.fill: parent
    visible: false
    z: 2000

    function open() {
        root.visible = true
        root.aboutToShow()
    }

    function close() {
        root.visible = false
    }

    function accept() {
        root.visible = false
        root.accepted()
    }

    function reject() {
        root.visible = false
        root.rejected()
    }

    // footer 是通过属性接进来的子项，得手动挪到卡片底部并铺满宽度。
    function adoptFooter(item) {
        if (!item) {
            return
        }
        item.parent = footerSlot
        item.width = Qt.binding(function () { return footerSlot.width })
    }

    onFooterChanged: adoptFooter(footer)
    Component.onCompleted: adoptFooter(root.footer)

    // 遮罩：吃掉点击，顺便当「点外面关掉」。
    Rectangle {
        anchors.fill: parent
        color: Theme.currentTheme.colors.backgroundSmokeColor

        MouseArea {
            anchors.fill: parent
            onClicked: if (root.closeOnScrim) root.reject()
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(root.preferredWidth, Math.max(240, root.width - 32))
        height: {
            var limit = Math.max(200, root.height - 32)
            if (root.preferredHeight > 0) {
                return Math.min(root.preferredHeight, limit)
            }
            return Math.min(Math.max(180, contentColumn.implicitHeight), limit)
        }
        color: Theme.currentTheme.colors.backgroundAcrylicColor
        border.width: 1
        border.color: Theme.currentTheme.colors.windowBorderColor
        radius: Theme.currentTheme.appearance.windowRadius

        ColumnLayout {
            id: contentColumn

            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                typography: Typography.Subtitle
                text: root.title
            }

            ColumnLayout {
                id: body

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
            }

            ColumnLayout {
                id: footerSlot

                Layout.fillWidth: true
                spacing: 8
            }
        }
    }
}
