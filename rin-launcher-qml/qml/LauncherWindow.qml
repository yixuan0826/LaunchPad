import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import QtQuick.Window 2.15
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
    
    property var actionsModel: []
    property var categoriesModel: []
    property var filteredActions: []
    property string searchText: ""
    property bool isSearchMode: false
    
    // Custom title bar with search
    titleBarArea: Rectangle {
        height: 56
        color: "transparent"
        
        AutoSuggestBox {
            id: searchField
            width: parent.width - 64
            height: 40
            anchors.centerIn: parent
            placeholderText: qsTr("搜索应用、文件、命令... (Ctrl+Space)")
            text: launcherWindow.searchText
            model: launcherWindow.filteredActions
            textRole: "name"
            
            onTextChanged: {
                launcherWindow.searchText = text
                launcherWindow.filterActions(text)
            }
            
            onAccepted: {
                if (launcherWindow.filteredActions.length > 0) {
                    launcherWindow.executeAction(launcherWindow.filteredActions[0])
                }
            }
            
            onSuggestionChosen: {
                launcherWindow.executeAction(launcherWindow.filteredActions.find(a => a.name === suggestion))
            }
        }
        
        // Settings button
        ToolButton {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            icon.name: "ic_fluent_settings_20_regular"
            onClicked: settingsDialog.open()
            ToolTip.text: qsTr("设置")
        }
    }
    
    // Main content
    FluentPage {
        id: mainPage
        title: ""
        spacing: 16
        Layout.fillWidth: true
        Layout.fillHeight: true
        padding: 20
        
        // Search results or categorized actions
        Column {
            width: parent.width
            spacing: 16
            
            Repeater {
                model: launcherWindow.isSearchMode ? launcherWindow.filteredActions : launcherWindow.getCategorizedActions()
                delegate: CategorySection {
                    categoryName: modelData.categoryName
                    categoryIcon: modelData.categoryIcon
                    actions: modelData.actions
                    onActionClicked: launcherWindow.executeAction(actionData)
                    onActionContextMenu: launcherWindow.showActionContextMenu(actionData, mouseX, mouseY)
                }
            }
        }
    }
    
    // Settings Dialog
    SettingsDialog {
        id: settingsDialog
        onSettingsChanged: {
            ConfigManager.saveConfig()
            launcherWindow.refreshData()
        }
    }
    
    // Action Context Menu
    Menu {
        id: actionContextMenu
        MenuItem {
            text: qsTr("编辑")
            onTriggered: {
                actionEditorDialog.editAction(actionContextMenu.actionData)
            }
        }
        MenuItem {
            text: qsTr("复制")
            onTriggered: {
                launcherWindow.duplicateAction(actionContextMenu.actionData)
            }
        }
        MenuItem {
            text: qsTr("删除")
            onTriggered: {
                launcherWindow.deleteAction(actionContextMenu.actionData)
            }
        }
    }
    
    // Action Editor Dialog
    ActionEditorDialog {
        id: actionEditorDialog
        onActionSaved: {
            ConfigManager.saveConfig()
            launcherWindow.refreshData()
        }
    }
    
    // Category Editor Dialog
    CategoryEditorDialog {
        id: categoryEditorDialog
        onCategorySaved: {
            ConfigManager.saveConfig()
            launcherWindow.refreshData()
        }
    }
    
    // Toast/InfoBar for notifications
    Connections {
        target: ConfigManager
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
    
    function filterActions(text) {
        isSearchMode = (text.length > 0)
        if (isSearchMode) {
            filteredActions = ConfigManager.searchActions(text)
        }
    }
    
    function getCategorizedActions() {
        return ConfigManager.getCategorizedActions()
    }
    
    function executeAction(action) {
        ConfigManager.executeAction(action)
        if (isSearchMode) {
            searchField.text = ""
            searchText = ""
            isSearchMode = false
        }
    }
    
    function showActionContextMenu(action, x, y) {
        actionContextMenu.actionData = action
        actionContextMenu.popup(Qt.point(x, y))
    }
    
    function duplicateAction(action) {
        ConfigManager.duplicateAction(action)
        refreshData()
    }
    
    function deleteAction(action) {
        var confirmDialog = Qt.createQmlObject('import QtQuick.Controls 2.15; MessageDialog { title: "确认删除"; text: "确定要删除操作 \\"" + action.name + qsTr("\\" 吗？"); standardButtons: MessageDialog.Yes | MessageDialog.No; onAccepted: ConfigManager.deleteAction(action.id); }', launcherWindow)
        confirmDialog.open()
    }
    
    function refreshData() {
        actionsModel = ConfigManager.getActions()
        categoriesModel = ConfigManager.getCategories()
    }
    
    Component.onCompleted: {
        refreshData()
    }
}