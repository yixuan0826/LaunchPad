import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

// 键鼠序列里的一条可编辑步骤。
//
// 三种步骤（按键 / 鼠标 / 等待）共用同一套控件：`fields` 描述了每种步骤需要
// 哪些编辑器，因此不存在按类型复制的分支。编辑结果直接写入 `stepData`，它由
// 所属编辑器的步骤数组持有。
Frame {
    id: stepDelegate

    property var stepData: null
    property string stepKind: "key"

    signal deleteRequested(int index)

    readonly property var stepKinds: ["key", "mouse", "wait"]

    readonly property var fields: ({
        "key": [
            { "kind": "text", "label": qsTr("按键"), "key": "key", "placeholder": qsTr("如 Ctrl+C") },
            { "kind": "choice", "label": qsTr("动作"), "key": "action",
              "values": ["press", "release", "click"],
              "labels": [qsTr("按下"), qsTr("释放"), qsTr("点击")] },
            { "kind": "number", "label": qsTr("延迟(ms)"), "key": "duration", "scale": 1000,
              "min": 0, "max": 10000 }
        ],
        "mouse": [
            { "kind": "choice", "label": qsTr("动作"), "key": "action",
              "values": ["click", "move", "scroll"],
              "labels": [qsTr("点击"), qsTr("移动"), qsTr("滚动")] },
            { "kind": "choice", "label": qsTr("按钮"), "key": "button",
              "values": ["left", "right", "middle"],
              "labels": [qsTr("左键"), qsTr("右键"), qsTr("中键")] },
            { "kind": "number", "label": "X", "key": "x", "scale": 1, "min": -10000, "max": 10000 },
            { "kind": "number", "label": "Y", "key": "y", "scale": 1, "min": -10000, "max": 10000 },
            { "kind": "number", "label": "ΔX", "key": "dx", "scale": 1, "min": -10000, "max": 10000 },
            { "kind": "number", "label": "ΔY", "key": "dy", "scale": 1, "min": -10000, "max": 10000 },
            { "kind": "number", "label": qsTr("延迟(ms)"), "key": "duration", "scale": 1000,
              "min": 0, "max": 10000 }
        ],
        "wait": [
            { "kind": "number", "label": qsTr("等待(ms)"), "key": "duration", "scale": 1000,
              "min": 0, "max": 60000 }
        ]
    })

    radius: 8
    hoverable: false
    implicitHeight: fieldFlow.implicitHeight + 24

    Component.onCompleted: stepKind = stepData ? stepData.type : "key"

    Flow {
        id: fieldFlow
        anchors.left: parent.left
        anchors.right: deleteButton.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 12

        ComboBox {
            width: 110
            model: [qsTr("按键"), qsTr("鼠标"), qsTr("等待")]
            currentIndex: stepDelegate.stepKinds.indexOf(stepDelegate.stepKind)
            onCurrentIndexChanged: {
                stepDelegate.stepKind = stepDelegate.stepKinds[currentIndex]
                stepDelegate.assign({ "key": "type" }, stepDelegate.stepKind)
            }
        }

        Repeater {
            model: stepDelegate.fields[stepDelegate.stepKind] || []

            delegate: Row {
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                }

                // 只实例化与字段类型匹配的编辑器，避免控件绑定到它并不携带的字段上。
                Loader {
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: modelData.kind === "text" ? textEditor
                        : modelData.kind === "choice" ? choiceEditor
                        : numberEditor
                }

                Component {
                    id: textEditor
                    TextField {
                        width: 150
                        placeholderText: modelData.placeholder || ""
                        text: stepDelegate.textValue(modelData)
                        onTextChanged: stepDelegate.assign(modelData, text)
                    }
                }

                Component {
                    id: choiceEditor
                    ComboBox {
                        width: 110
                        model: modelData.labels
                        currentIndex: Math.max(0, modelData.values.indexOf(stepDelegate.rawValue(modelData)))
                        onCurrentIndexChanged: stepDelegate.assign(modelData, modelData.values[currentIndex])
                    }
                }

                Component {
                    id: numberEditor
                    SpinBox {
                        width: 100
                        from: modelData.min
                        to: modelData.max
                        value: stepDelegate.scaledValue(modelData)
                        onValueChanged: stepDelegate.assign(modelData, value / modelData.scale)
                    }
                }
            }
        }
    }

    ToolButton {
        id: deleteButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 8
        icon.name: "ic_fluent_delete_20_regular"
        ToolTip.text: qsTr("删除该步骤")
        onClicked: stepDelegate.deleteRequested(index)
    }

    function rawValue(field) {
        return stepData ? stepData[field.key] : undefined
    }

    function textValue(field) {
        var raw = rawValue(field)
        return raw === undefined || raw === null ? "" : String(raw)
    }

    function scaledValue(field) {
        return Math.round((rawValue(field) || 0) * field.scale)
    }

    function assign(field, value) {
        if (stepData) {
            stepData[field.key] = value
        }
    }
}
