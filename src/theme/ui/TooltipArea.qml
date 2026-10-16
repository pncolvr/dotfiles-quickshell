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
    readonly property bool tooltipHovered: triggerHover.hovered
    readonly property bool pinned: TooltipService.pinned && TooltipService.source === tooltipSource
    property color normalIconColor: Theme.text
    readonly property color moduleIconColor: pinned ? Theme.accent : normalIconColor
    signal alternateClicked(var mouse)
    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton && moduleName && tooltip) {
            const pos = root.mapToGlobal(root.width / 2, 0)
            TooltipService.togglePin(pos.x, tooltip, tooltipSource, centerTooltip, tooltipScreen)
        } else alternateClicked(mouse)
    }
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
        cursorShape: root.cursorShape
        enabled: root.enabled && root.hoverEnabled && !!root.tooltip
        // Enter within the target; tolerate small edge movements after entry.
        margin: hovered ? Theme.tooltipHoverTolerance : 0
    }
}
