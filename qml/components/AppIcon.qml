import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import RinUI

// 条目 / 分区图标。
//
// 配置里两种写法混用，这里统一成同一个控件：
//
//   "ic_fluent_pen_20_regular"    RinUI 的 Fluent 字体图标
//   "lawnicons:generic_shell"     随包的 Lawnicons SVG，按 `color` 着色
Icon {
    id: appIcon

    property string iconKey: ""
    property int iconSize: 20
    property color tint: Theme.currentTheme.colors.textColor

    readonly property string bundlePrefix: "lawnicons:"
    readonly property bool isBundled: iconKey.indexOf(bundlePrefix) === 0
    // 选中随包图标时，字体那条路径仍需要一个合法字形名，否则会报警告。
    readonly property string fallbackGlyph: "ic_fluent_apps_20_regular"

    size: iconSize
    name: isBundled ? fallbackGlyph : iconKey
    color: tint
    source: isBundled
        ? Qt.resolvedUrl("../../assets/icons/lawnicons/"
                         + iconKey.slice(bundlePrefix.length) + ".svg")
        : ""
    // Lawnicons 是透明底 + 纯黑描边，靠颜色覆盖层套上主题色。
    enableColorOverlay: isBundled
}
