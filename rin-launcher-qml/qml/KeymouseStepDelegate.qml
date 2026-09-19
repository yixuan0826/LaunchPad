import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

Frame {
    id: stepDelegate
    width: parent.width
    height: 60
    radius: 8
    border.color: Theme.currentTheme.colors.borderColor
    border.width: 1
    
    property var stepData: null
    signal stepChanged()
    signal deleteRequested(int index)
    
    property string stepType: stepData ? stepData.type : "key"
    
    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8
        
        // Type selector
        Row {
            spacing: 8
            Text { text: qsTr("类型:"); font.bold: true }
            ComboBox {
                width: 100
                model: [qsTr("按键"), qsTr("鼠标"), qsTr("等待")]
                currentIndex: ["key", "mouse", "wait"].indexOf(stepType)
                onCurrentIndexChanged: {
                    stepType = ["key", "mouse", "wait"][currentIndex]
                    stepData.type = stepType
                    stepChanged()
                }
            }
        }
        
        // Key step
        Item {
            visible: stepType === "key"
            Row {
                spacing: 8
                Text { text: qsTr("按键:") }
                TextField {
                    id: keyField
                    width: 180
                    readOnly: true
                    placeholderText: "点击录制热键..."
                    text: stepData.key || ""
                    MouseArea {
                        anchors.fill: parent
                        onClicked: startKeyRecording()
                    }
                }
                Text { text: qsTr("动作:") }
                ComboBox {
                    width: 100
                    model: [qsTr("按下"), qsTr("释放"), qsTr("点击")]
                    currentIndex: ["press", "release", "click"].indexOf(stepData.action || "press")
                    onCurrentIndexChanged: {
                        stepData.action = ["press", "release", "click"][currentIndex]
                        stepChanged()
                    }
                }
                Text { text: qsTr("延迟(ms):") }
                SpinBox {
                    width: 80
                    from: 0
                    to: 10000
                    value: stepData.duration ? stepData.duration * 1000 : 0
                    onValueChanged: {
                        stepData.duration = value / 1000
                        stepChanged()
                    }
                }
            }
        }
        
        // Mouse step
        Item {
            visible: stepType === "mouse"
            Column {
                spacing: 8
                Row {
                    spacing: 8
                    Text { text: qsTr("动作:") }
                    ComboBox {
                        width: 100
                        model: [qsTr("点击"), qsTr("移动"), qsTr("滚动")]
                        currentIndex: ["click", "move", "scroll"].indexOf(stepData.action || "click")
                        onCurrentIndexChanged: {
                            stepData.action = ["click", "move", "scroll"][currentIndex]
                            stepChanged()
                        }
                    }
                    Text { text: qsTr("按钮:") }
                    ComboBox {
                        width: 100
                        model: [qsTr("左键"), qsTr("右键"), qsTr("中键")]
                        currentIndex: ["left", "right", "middle"].indexOf(stepData.button || "left")
                        onCurrentIndexChanged: {
                            stepData.button = ["left", "right", "middle"][currentIndex]
                            stepChanged()
                        }
                    }
                }
                Row {
                    spacing: 8
                    Text { text: qsTr("X:") }
                    SpinBox { id: mouseX; width: 80; from: -10000; to: 10000; value: stepData.x || 0; onValueChanged: { stepData.x = value; stepChanged() } }
                    Text { text: qsTr("Y:") }
                    SpinBox { id: mouseY; width: 80; from: -10000; to: 10000; value: stepData.y || 0; onValueChanged: { stepData.y = value; stepChanged() } }
                    Text { text: qsTr("ΔX:") }
                    SpinBox { id: mouseDx; width: 80; from: -10000; to: 10000; value: stepData.dx || 0; onValueChanged: { stepData.dx = value; stepChanged() } }
                    Text { text: qsTr("ΔY:") }
                    SpinBox { id: mouseDy; width: 80; from: -10000; to: 10000; value: stepData.dy || 0; onValueChanged: { stepData.dy = value; stepChanged() } }
                }
                Row {
                    spacing: 8
                    Text { text: qsTr("延迟(ms):") }
                    SpinBox { width: 100; from: 0; to: 10000; value: stepData.duration ? stepData.duration * 1000 : 0; onValueChanged: { stepData.duration = value / 1000; stepChanged() } }
                }
            }
        }
        
        // Wait step
        Item {
            visible: stepType === "wait"
            Row {
                spacing: 8
                Text { text: qsTr("等待时间(ms):") }
                SpinBox {
                    width: 150
                    from: 0
                    to: 60000
                    value: stepData.duration ? stepData.duration * 1000 : 0
                    onValueChanged: {
                        stepData.duration = value / 1000
                        stepChanged()
                    }
                }
            }
        }
    }
    
    // Delete button
    ToolButton {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 4
        icon.name: "ic_fluent_delete_20_regular"
        onClicked: deleteRequested(index)
    }
    
    function startKeyRecording() {
        keyField.text = "按下热键组合..."
        // TODO: Implement actual key recording
    }
}