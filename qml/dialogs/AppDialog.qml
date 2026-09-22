import QtQuick 2.15
import QtQuick.Controls 2.15
import RinUI

// 全项目的弹窗基类。
//
// RinUI 的 Dialog 把「尺寸」和「居中」都挂在 QQC2.Overlay 上：主窗是自绘窗口
// （不是 ApplicationWindow）时拿不到 overlay，于是弹窗会贴在页面左上角，读
// overlay.height 还会算出 NaN 让内容塌成一团。这里把这两件事改成相对所在页面
// 计算，在任何窗口实现下表现一致。
Dialog {
    // 期望尺寸。超过页面时自动收缩，preferredHeight 为 0 表示按内容撑高。
    property real preferredWidth: 520
    property real preferredHeight: 0

    anchors.centerIn: parent
    width: Math.min(preferredWidth,
                    Math.max(240, (parent ? parent.width : preferredWidth) - 32))
    height: {
        var limit = Math.max(200, (parent ? parent.height : 600) - 32)
        if (preferredHeight > 0) {
            return Math.min(preferredHeight, limit)
        }
        var body = contentItem ? contentItem.implicitHeight : 0
        var bar = footer ? footer.implicitHeight : 0
        return Math.min(body + topPadding + bottomPadding + bar, limit)
    }

    // 把基类那两个「读 overlay 尺寸」的绑定顶掉：overlay 为空时它们会一次性刷出
    // 一屏 TypeError（不影响功能，但没必要留着）。
    implicitWidth: width
    implicitHeight: height
}
