pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls as QC
import QtQml.Models
import "../../services"

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
    readonly property bool interactive: tooltipWindow.requestedVisible ?? tooltipWindow.visible
    readonly property bool hovered: panelHover.hovered || popupHovered
    visible: false
    onHoveredChanged: syncHover()

    function syncHover() {
        if (interactive && (!TooltipService.screen || tooltipWindow.screen === TooltipService.screen))
            TooltipService.setPanelHovered(hovered)
    }
    // show() resets hover ownership when the source changes. The pointer can
    // remain inside the same surface, so no new hover event is guaranteed.
    Connections {
        target: TooltipService
        function onSourceChanged() { Qt.callLater(root.syncHover) }
        function onScreenChanged() { Qt.callLater(root.syncHover) }
    }
    Connections {
        target: root.tooltipWindow
        ignoreUnknownSignals: true
        function onVisibleChanged() { Qt.callLater(root.syncHover) }
        function onRequestedVisibleChanged() { Qt.callLater(root.syncHover) }
    }

    HoverHandler {
        id: panelHover
        parent: root.tooltipWindow.surfaceComponent.popupContentBounds
        enabled: root.interactive
    }
    // Observe actual popup areas. A handler covering the whole overlay steals
    // frame-sync hover from underlying buttons whenever their hints appear.
    // Popup items and the overlay are recreated as the native window is hidden.
    Instantiator {
        id: popupMonitors
        model: root.interactive && root.overlayItem ? Array.from(root.overlayItem.children).filter(item => item.visible) : []
        delegate: HoverHandler {
            id: handler
            required property var modelData
            parent: modelData
            enabled: root.interactive && modelData.visible
        }
    }
}
