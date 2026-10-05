import QtQuick
import Quickshell
import "../../services"
import "../"
import "./components"

WrapperMouseArea {
    id: root
    hoverEnabled: true
    property Component tooltip: null
    property var tooltipSource: null
    property bool centerTooltip: false
    property bool ownsTooltipWindow: false
    readonly property var tooltipWindow: root.QsWindow.window
    property var tooltipScreen: tooltipWindow?.screen

    // Pad bar triggers while keeping their visual content at its natural size.
    leftMargin: tooltip ? Theme.tooltipHoverPaddingWidth : 0
    rightMargin: tooltip ? Theme.tooltipHoverPaddingWidth : 0
    implicitHeight: tooltip ? Math.max(Theme.barHeight, child?.implicitHeight ?? 0) : undefined
    resizeChild: !tooltip

    onExited: {
        if (!tooltip) TooltipService.hide()
    }

    HoverHandler {
        enabled: root.enabled && root.hoverEnabled && !!root.tooltip
        // Enter within the target; tolerate small edge movements after entry.
        margin: hovered ? Theme.tooltipHoverTolerance : 0
        onHoveredChanged: {
            if (hovered) {
                const pos = root.mapToGlobal(root.width / 2, 0)
                TooltipService.show(pos.x, root.tooltip, root.tooltipSource, root.centerTooltip, root.tooltipScreen)
            } else {
                TooltipService.hide()
            }
        }
    }
}
