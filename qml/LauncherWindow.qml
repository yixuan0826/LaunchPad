import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

FluentWindow {
    id: launcherWindow
    width: 800
    height: 600
    minimumWidth: 600
    minimumHeight: 400
    visible: true
    title: qsTr("Rin Launcher")
    titleEnabled: false

    // Grouped sections: [{categoryName, categoryIcon, actions}].  Browsing and
    // searching both produce this one shape, so the grid needs a single delegate.
    property var sections: []
    // Flat action list, for the search box's suggestion dropdown.
    property var allActions: []
    property bool isSearchMode: false

    titleBarArea: Rectangle {
        height: 56
        color: "transparent"

        AutoSuggestBox {
            id: searchField
            width: parent.width - 64
            height: 40
            anchors.centerIn: parent
            placeholderText: qsTr("搜索应用、文件、命令... (Ctrl+Space)")
            model: launcherWindow.allActions
            textRole: "name"

            onTextChanged: launcherWindow.applyFilter(text)
            onAccepted: launcherWindow.runTopMatch()
            onSuggestionChosen: launcherWindow.runTopMatch(suggestion)
        }

        ToolButton {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            icon.name: "ic_fluent_settings_20_regular"
            ToolTip.text: qsTr("设置")
            onClicked: settingsDialog.open()
        }
    }

    FluentPage {
        title: ""
        spacing: 16
        padding: 20
        Layout.fillWidth: true
        Layout.fillHeight: true

        Repeater {
            model: launcherWindow.sections

            delegate: CategorySection {
                Layout.fillWidth: true
                categoryName: modelData.categoryName
                categoryIcon: modelData.categoryIcon
                actions: modelData.actions
                onActionClicked: launcherWindow.runAction(actionData)
                onActionContextMenu: launcherWindow.showContextMenu(actionData, mouseX, mouseY)
            }
        }
    }

    SettingsDialog {
        id: settingsDialog
        onNewActionRequested: actionEditorDialog.newAction()
        onEditActionRequested: actionEditorDialog.editAction(action)
        onNewCategoryRequested: categoryEditorDialog.newCategory()
        onEditCategoryRequested: categoryEditorDialog.editCategory(category)
    }

    ActionEditorDialog {
        id: actionEditorDialog
    }

    CategoryEditorDialog {
        id: categoryEditorDialog
    }

    ConfirmDialog {
        id: confirmDialog
    }

    Menu {
        id: actionContextMenu
        property var actionData: null

        MenuItem {
            text: qsTr("编辑")
            onTriggered: actionEditorDialog.editAction(actionContextMenu.actionData)
        }
        MenuItem {
            text: qsTr("复制")
            onTriggered: ConfigManager.duplicateAction(actionContextMenu.actionData)
        }
        MenuItem {
            text: qsTr("删除")
            onTriggered: launcherWindow.confirmDelete(actionContextMenu.actionData)
        }
    }

    // ConfigManager emits configChanged after every successful write, so the grid
    // stays in sync without each dialog having to poke us.
    Connections {
        target: ConfigManager

        function onConfigChanged() {
            launcherWindow.reload()
        }

        function onShowToast(message, severity) {
            floatLayer.createInfoBar({
                severity: severity === "success" ? Severity.Success
                    : severity === "warning" ? Severity.Warning
                    : severity === "error" ? Severity.Error
                    : Severity.Info,
                position: Position.BottomRight,
                timeout: 3000,
                closable: true,
                title: qsTr("提示"),
                text: message
            })
        }
    }

    Component.onCompleted: reload()

    function reload() {
        allActions = ConfigManager.getActions()
        sections = isSearchMode
            ? ConfigManager.searchActions(searchField.text)
            : ConfigManager.getCategorizedActions()
    }

    function applyFilter(text) {
        isSearchMode = text.length > 0
        sections = ConfigManager.searchActions(text)
    }

    function runAction(action) {
        if (!action) {
            return
        }
        ConfigManager.executeAction(action)
        if (isSearchMode) {
            searchField.text = ""
            isSearchMode = false
            reload()
        }
    }

    // Enter / a picked suggestion runs the first match, or an exact name match.
    function runTopMatch(name) {
        var candidate = null
        for (var s = 0; s < sections.length && !candidate; ++s) {
            var actions = sections[s].actions
            for (var i = 0; i < actions.length; ++i) {
                if (!name || actions[i].name === name) {
                    candidate = actions[i]
                    break
                }
            }
        }
        runAction(candidate)
    }

    function showContextMenu(action, x, y) {
        actionContextMenu.actionData = action
        actionContextMenu.popup(Qt.point(x, y))
    }

    function confirmDelete(action) {
        if (!action) {
            return
        }
        confirmDialog.ask(qsTr("确定要删除操作“%1”吗？").arg(action.name), function() {
            ConfigManager.deleteAction(action.id)
        })
    }
}
