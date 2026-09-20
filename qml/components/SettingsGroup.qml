import QtQuick 2.15
import QtQuick.Layouts 2.15
import RinUI

// 设置分组：一个小标题 + 一张承载若干 FormRow 的卡片。
ColumnLayout {
    id: group

    property string title: ""
    property string iconKey: ""

    default property alias content: inner.data

    Layout.fillWidth: true
    spacing: 10

    ZoneHeader {
        Layout.fillWidth: true
        iconKey: group.iconKey
        title: group.title
    }

    Frame {
        Layout.fillWidth: true

        ColumnLayout {
            id: inner
            anchors.fill: parent
            spacing: 10
        }
    }
}
