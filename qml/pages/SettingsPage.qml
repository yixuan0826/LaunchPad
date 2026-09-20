import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 2.15
import RinUI

import "../components"
import "../dialogs"

// 设置。
//
// 所有改动都是即时生效的：控件先写进 pending，再由一个 350ms 的定时器合并写盘。
// 这样拖动滑杆或在输入框里连续打字都不会把配置文件刷爆；离开本页时会强制冲刷。
Item {
    id: settingsPage

    property var model: ({})
    property var pending: ({})

    ConfirmDialog {
        id: confirmDialog
    }

    Timer {
        id: applyTimer
        interval: 350
        repeat: false
        onTriggered: settingsPage.flush()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 8

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                Text {
                    font.bold: true
                    font.pixelSize: Theme.currentTheme.typography.bodySize + 4
                    color: Theme.currentTheme.colors.textColor
                    text: qsTr("设置")
                }
                Text {
                    typography: Typography.Caption
                    color: Theme.currentTheme.colors.textSecondaryColor
                    text: qsTr("改动会立即写入配置并生效")
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                text: qsTr("打开配置目录")
                icon.name: "ic_fluent_folder_open_20_regular"
                onClicked: ConfigManager.openConfigFolder()
            }
        }

        Flickable {
            id: scroller
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: contentColumn.implicitHeight + 28
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: contentColumn
                x: 16
                width: scroller.width - 32
                spacing: 16

                // ── 常规 ──
                SettingsGroup {
                    title: qsTr("常规")
                    iconKey: "ic_fluent_home_20_regular"

                    FormRow {
                        label: qsTr("开机自动启动")
                        description: qsTr("写入注册表 HKCU\\...\\Run")
                        Switch {
                            id: autoStartSwitch
                            checkedText: qsTr("开")
                            uncheckedText: qsTr("关")
                            onCheckedChanged: settingsPage.apply("autoStart", checked)
                        }
                    }

                    FormRow {
                        label: qsTr("启动时最小化")
                        description: qsTr("只驻留托盘，不主动弹出窗口")
                        Switch {
                            id: startMinimizedSwitch
                            checkedText: qsTr("开")
                            uncheckedText: qsTr("关")
                            onCheckedChanged: settingsPage.apply("startMinimized", checked)
                        }
                    }

                    FormRow {
                        label: qsTr("系统托盘图标")
                        description: qsTr("关闭后只能靠全局热键唤出启动台")
                        Switch {
                            id: traySwitch
                            checkedText: qsTr("开")
                            uncheckedText: qsTr("关")
                            onCheckedChanged: settingsPage.apply("showTray", checked)
                        }
                    }

                    FormRow {
                        label: qsTr("窗口置顶")
                        description: qsTr("启动台始终显示在其他窗口之上")
                        Switch {
                            id: topSwitch
                            checkedText: qsTr("开")
                            uncheckedText: qsTr("关")
                            onCheckedChanged: settingsPage.apply("alwaysOnTop", checked)
                        }
                    }
                }

                // ── 外观 ──
                SettingsGroup {
                    title: qsTr("外观")
                    iconKey: "lawnicons:generic_gallery"

                    FormRow {
                        label: qsTr("主题模式")
                        ComboBox {
                            id: themeCombo
                            Layout.preferredWidth: 160
                            model: [qsTr("跟随系统"), qsTr("浅色"), qsTr("深色")]
                            // Connections 而非 onCurrentIndexChanged：不覆盖 RinUI
                            // ComboBox 内部同步下拉高亮用的同名处理函数。
                            Connections {
                                target: themeCombo
                                function onCurrentIndexChanged() {
                                    if (themeCombo.currentIndex >= 0) {
                                        settingsPage.apply(
                                            "theme",
                                            ["system", "light", "dark"][themeCombo.currentIndex])
                                    }
                                }
                            }
                        }
                    }

                    FormRow {
                        label: qsTr("强调色")
                        DropDownColorPicker {
                            id: accentPicker
                            Layout.preferredWidth: 160
                            onColorChanged: settingsPage.apply("accentColor", color.toString())
                        }
                        ToolButton {
                            icon.name: "ic_fluent_arrow_reset_20_regular"
                            ToolTip.text: qsTr("恢复默认强调色")
                            onClicked: {
                                accentPicker.color = "#0078d4"
                                settingsPage.apply("accentColor", "#0078d4")
                            }
                        }
                    }

                    FormRow {
                        label: qsTr("背景模糊")
                        description: qsTr("仅 Windows 11 生效，依赖系统亚克力材质")
                        Switch {
                            id: blurSwitch
                            checkedText: qsTr("开")
                            uncheckedText: qsTr("关")
                            onCheckedChanged: settingsPage.apply("blurBackground", checked)
                        }
                    }

                    FormRow {
                        label: qsTr("条目尺寸")
                        description: qsTr("启动台网格里每个图标卡片的边长")
                        SpinBox {
                            id: tileSpin
                            from: 72
                            to: 144
                            stepSize: 8
                            onValueModified: settingsPage.apply("itemSize", value)
                        }
                    }

                    FormRow {
                        label: qsTr("网格列数")
                        description: qsTr("搜索框之外的条目按此列数换行")
                        SpinBox {
                            id: columnsSpin
                            from: 3
                            to: 12
                            onValueModified: settingsPage.apply("gridColumns", value)
                        }
                    }

                    FormRow {
                        label: qsTr("动画效果")
                        description: qsTr("关闭后分区折叠等过渡会立刻完成")
                        Switch {
                            id: animationSwitch
                            checkedText: qsTr("开")
                            uncheckedText: qsTr("关")
                            onCheckedChanged: settingsPage.apply("animationEnabled", checked)
                        }
                    }
                }

                // ── 搜索 ──
                SettingsGroup {
                    title: qsTr("搜索")
                    iconKey: "lawnicons:generic_search"

                    FormRow {
                        label: qsTr("搜索引擎")
                        description: qsTr("用 {query} 作为关键词占位符")
                        TextField {
                            id: searchEngineField
                            Layout.fillWidth: true
                            placeholderText: "https://www.bing.com/search?q={query}"
                            onTextChanged: settingsPage.apply("searchEngine", text)
                        }
                    }
                }

                // ── 热键 ──
                SettingsGroup {
                    title: qsTr("热键")
                    iconKey: "lawnicons:generic_keyboard"

                    FormRow {
                        label: qsTr("显示 / 隐藏")
                        description: qsTr("全局热键，在任何程序里都能唤出启动台")
                        HotkeyField {
                            id: hotkeyField
                            Layout.preferredWidth: 260
                            onEdited: settingsPage.apply("globalHotkey", sequence)
                        }
                        ToolButton {
                            icon.name: "ic_fluent_arrow_reset_20_regular"
                            ToolTip.text: qsTr("恢复默认热键")
                            onClicked: {
                                hotkeyField.value = "Ctrl+Space"
                                settingsPage.apply("globalHotkey", "Ctrl+Space")
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("必须包含至少一个修饰键（Ctrl / Alt / Shift / Win），单独一个普通键会拦截系统里的正常输入。留空即关闭全局热键。")
                    }
                }

                // ── 高级 ──
                SettingsGroup {
                    title: qsTr("高级")
                    iconKey: "ic_fluent_toolbox_20_regular"

                    FormRow {
                        label: qsTr("自动提权")
                        description: qsTr("执行标记为管理员的条目时直接弹 UAC")
                        Switch {
                            id: elevateSwitch
                            checkedText: qsTr("开")
                            uncheckedText: qsTr("关")
                            onCheckedChanged: settingsPage.apply("adminAutoElevate", checked)
                        }
                    }

                    FormRow {
                        label: qsTr("提权前确认")
                        description: qsTr("执行管理员条目之前先弹一次确认")
                        Switch {
                            id: confirmAdminSwitch
                            checkedText: qsTr("开")
                            uncheckedText: qsTr("关")
                            onCheckedChanged: settingsPage.apply("confirmAdminActions", checked)
                        }
                    }

                    FormRow {
                        label: qsTr("日志级别")
                        description: qsTr("重启后生效，日志写在配置目录的 launcher.log")
                        ComboBox {
                            id: logCombo
                            Layout.preferredWidth: 160
                            model: ["DEBUG", "INFO", "WARNING", "ERROR"]
                            Connections {
                                target: logCombo
                                function onCurrentIndexChanged() {
                                    if (logCombo.currentIndex >= 0) {
                                        settingsPage.apply(
                                            "logLevel",
                                            ["DEBUG", "INFO", "WARNING", "ERROR"][logCombo.currentIndex])
                                    }
                                }
                            }
                        }
                    }

                    FormRow {
                        label: qsTr("配置文件")
                        RowLayout {
                            spacing: 8
                            Button {
                                text: qsTr("打开目录")
                                icon.name: "ic_fluent_folder_open_20_regular"
                                onClicked: ConfigManager.openConfigFolder()
                            }
                            Button {
                                text: qsTr("打开文件")
                                icon.name: "ic_fluent_document_20_regular"
                                onClicked: ConfigManager.openConfigFile()
                            }
                        }
                    }

                    FormRow {
                        label: qsTr("导入 / 导出")
                        RowLayout {
                            spacing: 8
                            Button {
                                text: qsTr("导入")
                                icon.name: "ic_fluent_arrow_import_20_regular"
                                onClicked: ConfigManager.importConfig()
                            }
                            Button {
                                text: qsTr("导出")
                                icon.name: "ic_fluent_arrow_export_20_regular"
                                onClicked: ConfigManager.exportConfig()
                            }
                        }
                    }

                    FormRow {
                        label: qsTr("以管理员重启")
                        description: qsTr("重启后会失去托盘，除非托盘进程也在管理员会话里")
                        Button {
                            text: qsTr("立即重启")
                            icon.name: "ic_fluent_shield_20_regular"
                            onClicked: ConfigManager.restartAsAdmin()
                        }
                    }

                    FormRow {
                        label: qsTr("恢复默认")
                        description: qsTr("重置全部分区、条目与设置，且不可撤销")
                        Button {
                            text: qsTr("重置")
                            icon.name: "ic_fluent_arrow_reset_20_regular"
                            onClicked: confirmDialog.ask(
                                qsTr("这会清空当前的全部分区、条目与设置，并恢复出厂默认值。确定继续吗？"),
                                function () { ConfigManager.resetToDefaults() })
                        }
                    }
                }

                // ── 关于 ──
                SettingsGroup {
                    title: qsTr("关于")
                    iconKey: "ic_fluent_info_20_regular"

                    FormRow {
                        label: qsTr("Rin Launcher")
                        description: qsTr("版本 1.0.0 · 仿希沃桌面助手的启动台，基于 RinUI（PySide6 + QML）")
                        RowLayout {
                            spacing: 8
                            Hyperlink {
                                text: qsTr("项目仓库")
                                openUrl: "https://github.com/yixuan0826/RinLauncher"
                            }
                            Hyperlink {
                                text: qsTr("RinUI")
                                openUrl: "https://ui.rinlit.cn"
                            }
                        }
                    }

                    FormRow {
                        label: qsTr("许可证")
                        description: qsTr("本项目以 GPL-3.0-or-later 发布")
                        RowLayout {
                            spacing: 8
                            Hyperlink {
                                text: qsTr("GPL-3.0")
                                openUrl: "https://www.gnu.org/licenses/gpl-3.0.html"
                            }
                            Hyperlink {
                                text: qsTr("Apache-2.0（Lawnicons）")
                                openUrl: "https://www.apache.org/licenses/LICENSE-2.0"
                            }
                            Hyperlink {
                                text: qsTr("MIT（RinUI）")
                                openUrl: "https://github.com/RinLit-233-shiroko/Rin-UI/blob/main/LICENSE"
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        typography: Typography.Caption
                        color: Theme.currentTheme.colors.textSecondaryColor
                        text: qsTr("图标来自 Lawnicons（Apache-2.0），已随程序附带 LICENSE 与 NOTICE；界面组件来自 RinUI（MIT），已内联到本仓库。")
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // 读写
    // ------------------------------------------------------------------
    Component.onCompleted: reloadSettings()

    // 离开本页时把还没落盘的改动冲掉。
    Component.onDestruction: {
        applyTimer.stop()
        flush()
    }

    Connections {
        target: ConfigManager

        function onConfigChanged() {
            if (Object.keys(settingsPage.pending).length === 0) {
                settingsPage.reloadSettings()
            }
        }
    }

    function reloadSettings() {
        model = ConfigManager.getSettings()

        autoStartSwitch.checked = model.autoStart === true
        startMinimizedSwitch.checked = model.startMinimized === true
        traySwitch.checked = model.showTray !== false
        topSwitch.checked = model.alwaysOnTop !== false

        themeCombo.currentIndex = Math.max(0, ["system", "light", "dark"].indexOf(model.theme))
        accentPicker.color = model.accentColor || "#0078d4"
        blurSwitch.checked = model.blurBackground !== false
        tileSpin.value = model.itemSize || 96
        columnsSpin.value = model.gridColumns || 6
        animationSwitch.checked = model.animationEnabled !== false

        searchEngineField.text = model.searchEngine || ""
        hotkeyField.value = model.globalHotkey || ""

        elevateSwitch.checked = model.adminAutoElevate !== false
        confirmAdminSwitch.checked = model.confirmAdminActions !== false
        logCombo.currentIndex = Math.max(0,
            ["DEBUG", "INFO", "WARNING", "ERROR"].indexOf(model.logLevel || "INFO"))
    }

    // 先攒进 pending，再由定时器合并写盘；主题这类要立刻看到效果的顺手就应用。
    function apply(key, value) {
        pending[key] = value
        applyTimer.restart()
        applyLive(key, value)
    }

    function flush() {
        if (Object.keys(pending).length === 0) {
            return
        }
        var payload = pending
        pending = ({})
        ConfigManager.updateSettings(payload)
    }

    function applyLive(key, value) {
        switch (key) {
        case "theme":
            Theme.setTheme(value === "light" ? Theme.mode.Light
                          : value === "dark" ? Theme.mode.Dark
                          : Theme.mode.Auto)
            break
        case "accentColor":
            Theme.setThemeColor(value)
            break
        case "blurBackground":
            // 亚克力只在 Windows 上有实现，其他平台直接跳过。
            if (Qt.platform.os === "windows") {
                Theme.setBackdropEffect(value ? Theme.effect.Acrylic : Theme.effect.None)
            }
            break
        }
    }
}
