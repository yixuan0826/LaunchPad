import QtQuick 2.15
import QtQuick.Layouts 2.15
import RinUI

// 表单行：左侧定宽标签（可带一行说明），右侧放任意控件。
//
// 没有直接用 RinUI 的 SettingItem / SettingCard，是因为它们把左侧内容限制在
// 行宽的 60%，宽输入框会被挤变形；设置项与对话框表单需要的列宽规则并不一样。
RowLayout {
    id: row

    property string label: ""
    property string description: ""
    property real labelWidth: 96

    default property alias content: fields.data

    Layout.fillWidth: true
    spacing: 16

    ColumnLayout {
        Layout.preferredWidth: row.labelWidth
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.currentTheme.colors.textColor
            text: row.label
        }

        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            visible: row.description.length > 0
            typography: Typography.Caption
            color: Theme.currentTheme.colors.textSecondaryColor
            text: row.description
        }
    }

    RowLayout {
        id: fields
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 8
    }
}
