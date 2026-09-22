import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import RinUI

// 条目 / 分区 / 槽位图标。
//
// 配置里四种写法混用，这里统一成同一个控件：
//
//   "ic_fluent_pen_20_regular"    RinUI 的 Fluent 字体图标
//   "lawnicons:generic_shell"     随包的 Lawnicons SVG，按 tint 着成单色
//   "file:<绝对路径>"              用户自己的图标（导入的 svg/png/ico，或从程序里抽出来的）
//   ""                            没有图标 → 画一个中性的占位字形
//
// 关键点：字体字形与图片**互斥**。之前把 font 名和 source 同时写上去，字形会从
// 透明底的 SVG 后面透出来，看起来就是两层图标叠在一起。
Item {
    id: appIcon

    property string iconKey: ""
    property int iconSize: 20
    property color tint: Theme.currentTheme.colors.textColor
    // 空图标时的占位字形，可由调用方换掉（比如槽位空位用「+」）。
    property string placeholder: "ic_fluent_apps_20_regular"

    readonly property string bundlePrefix: "lawnicons:"
    readonly property string filePrefix: "file:"
    // "url:" 用来直给一个已经在 QML 里解析好的地址（比如随包的 assets/icon.png）。
    readonly property string urlPrefix: "url:"
    readonly property bool isBundled: iconKey.indexOf(bundlePrefix) === 0
    readonly property bool isFile: iconKey.indexOf(filePrefix) === 0
    readonly property bool isUrl: iconKey.indexOf(urlPrefix) === 0
    readonly property bool hasIcon: iconKey.length > 0

    readonly property string filePath: isFile ? iconKey.slice(filePrefix.length) : ""
    readonly property string fileUrl: isFile ? appIcon.toFileUrl(filePath) : ""
    readonly property string sourceUrl: isBundled
        ? Qt.resolvedUrl("../../assets/icons/lawnicons/"
                         + iconKey.slice(bundlePrefix.length) + ".svg")
        : isUrl ? iconKey.slice(urlPrefix.length) : fileUrl
    readonly property bool usesImage: isBundled || isFile || isUrl
    // 只有单色的随包图标需要着色；用户自己的图直接原样画。
    readonly property bool usesOverlay: isBundled

    implicitWidth: iconSize
    implicitHeight: iconSize

    // 把绝对路径转成 QML 认的 file:// URL（Windows 的反斜杠、盘符都要处理）。
    function toFileUrl(path) {
        var text = String(path || "").replace(/\\/g, "/")
        if (text.length === 0) {
            return ""
        }
        return "file:///" + text.replace(/^\/+/, "")
    }

    Icon {
        id: glyph
        anchors.fill: parent
        // 只在「没有图片」时画字形：两层同时画就是之前那个图标重叠。
        visible: !appIcon.usesImage
        name: appIcon.hasIcon ? appIcon.iconKey : appIcon.placeholder
        size: appIcon.iconSize
        color: appIcon.tint
    }

    Image {
        id: picture
        anchors.fill: parent
        source: appIcon.usesImage ? appIcon.sourceUrl : ""
        sourceSize.width: appIcon.iconSize * 2
        sourceSize.height: appIcon.iconSize * 2
        smooth: true
        mipmap: true
        fillMode: Image.PreserveAspectFit
        // 要走覆盖层时不直接画，交给下面的 ColorOverlay（它照样能取到源纹理）。
        visible: appIcon.usesImage && !appIcon.usesOverlay
    }

    ColorOverlay {
        anchors.fill: picture
        source: picture
        color: appIcon.tint
        // 源图没加载出来（用户删了文件之类）时，覆盖层会画成一块纯色方块。
        visible: appIcon.usesOverlay && picture.status === Image.Ready
    }
}
