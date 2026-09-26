import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

// 一行的槽位列表编辑器。
//
// 交互照 ClassIsland 那套「可增删排序的分组列表」来：每一项占一行，右侧一排
// 上移 / 下移 / 编辑 / 删除，底下（这里是工具条上）一个「添加」。比拖拽好实现、
// 好验收，键盘和触控板也都点得动。
ColumnLayout {
    id: list

    property int row: 0
    property var slots: []
    property string emptyHint: ""
    // 数字序号从 1 开始显示。
    property string unit: qsTr("项")
    // 上限；0 表示不限。满了以后「添加」会置灰。
    property int capacity: 0

    signal addRequested()
    signal editRequested(int index)
    signal removeRequested(int index)
    signal moveRequested(int index, int delta)

    readonly property bool full: capacity > 0 && slots.length >= capacity

    Layout.fillWidth: true
    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.alignment: Qt.AlignVCenter
            typography: Typography.Caption
            color: list.full
                ? Theme.currentTheme.colors.systemCautionColor
                : Theme.currentTheme.colors.textSecondaryColor
            text: {
                var base = list.capacity > 0
                    ? qsTr("共 %1 / %2 %3").arg(list.slots.length).arg(list.capacity).arg(list.unit)
                    : qsTr("共 %1 %2").arg(list.slots.length).arg(list.unit)
                // 禁用状态的按钮收不到 hover，提示只能写在文字里。
                return list.full ? base + qsTr("（已满）") : base
            }
        }

        Item { Layout.fillWidth: true }

        Button {
            text: qsTr("添加")
            icon.name: "ic_fluent_add_20_regular"
            enabled: !list.full
            onClicked: list.addRequested()
        }
    }

    Text {
        Layout.fillWidth: true
        visible: list.slots.length === 0
        wrapMode: Text.Wrap
        typography: Typography.Caption
        color: Theme.currentTheme.colors.textSecondaryColor
        text: list.emptyHint
    }

    Repeater {
        model: list.slots

        delegate: Frame {
            id: slotRow

            Layout.fillWidth: true
            implicitHeight: 56

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 10

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 20
                    horizontalAlignment: Text.AlignRight
                    typography: Typography.Caption
                    color: Theme.currentTheme.colors.textSecondaryColor
                    text: (index + 1)
                }

                AppIcon {
                    Layout.alignment: Qt.AlignVCenter
                    iconKey: modelData.icon || ""
                    iconSize: 24
                    tint: Theme.currentTheme.colors.primaryColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 80
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        // RinUI 的 Text 默认 WordWrap，不关掉的话窄列里会一个字一行。
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                        color: Theme.currentTheme.colors.textColor
                        text: modelData.name || qsTr("未命名")
                    }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.NoWrap
                        elide: Text.ElideMiddle
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: list.describe(modelData)
                    }
                }

                MiniIconButton {
                    iconName: "ic_fluent_arrow_up_20_regular"
                    tip: qsTr("前移")
                    enabled: index > 0
                    onClicked: list.moveRequested(index, -1)
                }
                MiniIconButton {
                    iconName: "ic_fluent_arrow_down_20_regular"
                    tip: qsTr("后移")
                    enabled: index < list.slots.length - 1
                    onClicked: list.moveRequested(index, 1)
                }
                MiniIconButton {
                    iconName: "ic_fluent_edit_20_regular"
                    tip: qsTr("编辑这一格")
                    onClicked: list.editRequested(index)
                }
                MiniIconButton {
                    iconName: "ic_fluent_delete_20_regular"
                    tip: qsTr("移除这一格")
                    danger: true
                    onClicked: list.removeRequested(index)
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: 124   // 让出右边那四个按钮
                onClicked: list.editRequested(index)
            }
        }
    }

    // 副标题：类型 + 目标，一眼看出这一格会打开什么。
    function describe(slot) {
        var kind = (slot && slot.kindLabel) || ""
        if (!slot) {
            return kind
        }
        if (slot.kind === "usb") {
            return kind + " · " + (slot.available ? slot.path : qsTr("当前没有检测到"))
        }
        if (slot.kind === "path") {
            return kind + " · " + (slot.exists ? slot.path : qsTr("%1（路径不存在）").arg(slot.path))
        }
        if (slot.kind === "action") {
            return kind + " · " + (slot.target || qsTr("未设置目标"))
        }
        return kind
    }
}
