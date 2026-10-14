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
    readonly property bool popupHovered: {
        for (let index = 0; index < popupMonitors.count; index++)
            if ((popupMonitors.objectAt(index) as HoverHandler)?.hovered) return true
        return false
    }
    readonly property bool hovered: panelHover.hovered || popupHovered
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
    // Observe actual popup areas. A handler covering the whole overlay steals
    // frame-sync hover from underlying buttons whenever their hints appear.
    // Popup items and the overlay are recreated as the native window is hidden.
    Instantiator {
        id: popupMonitors
        model: root.tooltipWindow.visible && root.overlayItem ? Array.from(root.overlayItem.children).filter(item => item.visible) : []
        delegate: HoverHandler {
            id: handler
            required property var modelData
            parent: modelData
            enabled: root.tooltipWindow.visible && modelData.visible
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
