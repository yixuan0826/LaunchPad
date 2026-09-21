import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import RinUI

// 主窗口。
//
// 用 FluentWindow + NavigationView 而不是把内容直接塞进 FluentWindowBase：
// FluentWindowBase 的内容区是一个普通 Item（不是 Layout），窗口的直属子项用
// Layout.fillWidth/fillHeight 完全不起作用，页面会变成 0×0 的空白。
// NavigationView 自带侧边导航，骨架正好对上希沃桌面助手「侧边栏 + 面板」的形态。
FluentWindow {
    id: launcherWindow

    width: 1120
    height: 720
    minimumWidth: 880
    minimumHeight: 560
    title: qsTr("Rin Launcher")
    titleEnabled: false

    // 托盘菜单和设置页都通过这个属性切页：setProperty("requestedPage", "settings")。
    property string requestedPage: ""

    // 关闭按钮不直接退出，交给 Python 判断该隐藏（有托盘）还是真退出。
    signal closeRequested()

    // 启动台本身已经是桌面右下角那块小窗了，这里的「启动台」页是它的设置面板。
    readonly property var pageKeys: ({ "launcher": 0, "records": 1, "settings": 2 })

    navigationItems: [
        {
            "title": qsTr("启动台"),
            "icon": "ic_fluent_apps_20_regular",
            "page": Qt.resolvedUrl("pages/LauncherSettingsPage.qml")
        },
        {
            "title": qsTr("档案"),
            "icon": "ic_fluent_book_20_regular",
            "page": Qt.resolvedUrl("pages/RecordsPage.qml")
        },
        {
            "title": qsTr("设置"),
            "icon": "ic_fluent_settings_20_regular",
            "page": Qt.resolvedUrl("pages/SettingsPage.qml")
        }
    ]

    onRequestedPageChanged: {
        if (requestedPage.length === 0) {
            return
        }
        var index = pageKeys[requestedPage]
        requestedPage = ""
        if (index === undefined) {
            return
        }
        navigationView.safePush(navigationItems[index].page, false, false)
    }

    onClosing: function (close) {
        close.accepted = false
        launcherWindow.closeRequested()
    }

    // 后端所有提示都走同一条链路，UI 不必自己维护信息条。
    Connections {
        target: ConfigManager

        function onShowToast(message, severity) {
            launcherWindow.floatLayer.createInfoBar({
                "severity": severity === "success" ? Severity.Success
                    : severity === "warning" ? Severity.Warning
                    : severity === "error" ? Severity.Error
                    : Severity.Info,
                "position": Position.BottomRight,
                "timeout": 3200,
                "closable": true,
                "title": qsTr("提示"),
                "text": message
            })
        }
    }
}
