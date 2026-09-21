import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

// 启动台设置里的一个槽位选择行：左边是「位置 N」，右边是一个下拉。
//
// 下拉的候选项由调用方给（常用应用给条目名，快捷功能给内置功能名），用户选中后发
// picked(index)。这里用 activated 而不是 currentIndexChanged：后者在模型变化和程序
// 回填时也会发，会把刚读出来的值当成用户改动再写回去；activated 只在用户真的选了
// 某一项时才发（RinUI 的 ComboBox 内部只覆写了 onCurrentIndexChanged，没动它）。
FormRow {
    id: picker

    property string slotLabel: ""
    property var options: []
    signal picked(int index)

    readonly property int chosenIndex: combo.currentIndex

    label: picker.slotLabel
    labelWidth: 72

    ComboBox {
        id: combo
        Layout.fillWidth: true
        Layout.maximumWidth: 320
        model: picker.options

        function onActivated(index) {
            picker.picked(index)
        }
    }

    function select(index) {
        combo.currentIndex = Math.max(0, index)
    }
}
