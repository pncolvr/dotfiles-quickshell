pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls as QC
import QtQml.Models
import "../services"

Item {
    id: root
    required property var tooltipWindow
    readonly property Item windowContent: tooltipWindow.contentItem
    readonly property var nativeWindow: windowContent.Window.window
    readonly property Item overlayItem: nativeWindow ? windowContent.QC.Overlay.overlay : null
    readonly property HoverHandler popupHover: popupMonitors.count ? popupMonitors.objectAt(0) as HoverHandler : null
    readonly property bool hovered: panelHover.hovered || (popupHover?.hovered ?? false)
    readonly property bool pending: BarModuleService.pointerReady && tooltipWindow.visible
        && BarModuleService.pointerItem === TooltipService.source
        && tooltipWindow.screen === TooltipService.screen
    visible: false
    onPendingChanged: if (pending) nativeWindow?.update()
    onHoveredChanged: if (tooltipWindow.visible) TooltipService.setPanelHovered(hovered)

    function observePointer(handler: HoverHandler) {
        if (!handler.hovered) return
        const pos = handler.parent.mapToGlobal(handler.point.position.x, handler.point.position.y)
        TooltipService.observePointer(pos.x, pos.y, true)
    }
    HoverHandler {
        id: panelHover
        parent: root.tooltipWindow.surfaceComponent.popupContentBounds
        enabled: root.tooltipWindow.visible
        onPointChanged: root.observePointer(panelHover)
    }
    // The native overlay is recreated when a Quickshell window is hidden. Keep
    // its observer tied to that lifetime, while the panel observer stays alive.
    Instantiator {
        id: popupMonitors
        model: root.tooltipWindow.visible && root.overlayItem ? [root.overlayItem] : []
        delegate: HoverHandler {
            id: handler
            required property var modelData
            parent: modelData
            onPointChanged: root.observePointer(handler)
        }
    }
    Connections {
        target: root.nativeWindow
        function onFrameSwapped() {
            if (root.pending) BarModuleService.finishPointerMove()
        }
    }
}
