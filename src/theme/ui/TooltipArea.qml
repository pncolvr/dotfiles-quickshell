import QtQuick
import Quickshell
import "../../services"
import "../"
import "./components"

WrapperMouseArea {
    id: root
    hoverEnabled: true
    property Component tooltip: null
    property var tooltipSource: moduleName ? root : null
    property string moduleName: ""
    property bool moduleFocusSearch: false
    property bool pointerHovered: false
    readonly property bool tooltipHovered: triggerHover.hovered || pointerHovered
    Component.onCompleted: if (moduleName) BarModuleService.register(root)
    Component.onDestruction: if (moduleName) BarModuleService.unregister(root)
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
    onTooltipHoveredChanged: {
        if (tooltipHovered) {
            const pos = root.mapToGlobal(root.width / 2, 0)
            TooltipService.show(pos.x, root.tooltip, root.tooltipSource, root.centerTooltip, root.tooltipScreen)
            TooltipService.setTriggerHovered(root.tooltipSource, true)
        } else TooltipService.setTriggerHovered(root.tooltipSource, false)
    }

    HoverHandler {
        id: triggerHover
        parent: root
        target: root
        enabled: root.enabled && root.hoverEnabled && !!root.tooltip
        // Enter within the target; tolerate small edge movements after entry.
        margin: hovered ? Theme.tooltipHoverTolerance : 0
        onPointChanged: if (hovered) {
            const pos = root.mapToGlobal(point.position.x, point.position.y)
            TooltipService.observePointer(pos.x, pos.y, true)
        }
        onHoveredChanged: if (hovered) BarModuleService.releasePointerHover(root)
    }
}
