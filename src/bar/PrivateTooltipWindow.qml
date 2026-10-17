import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

PrivateTopPanelTooltip {
    id: root
    capturePanel: focusPanel
    onCaptureHideRequested: TooltipService.dismiss()
    readonly property var targetScreen: Quickshell.screens.includes(TooltipService.screen)
        ? TooltipService.screen : Quickshell.screens[0] ?? null
    requestedScreen: targetScreen
    property var focusPanel: null
    readonly property var nativeWindow: focusHandler.nativeWindow
    readonly property bool requestingKeyboardFocus: focusHandler.requestingKeyboardFocus
    requestedVisible: false
    contentX: {
        const ideal = TooltipService.centered ? (width - contentWidth) / 2
            : TooltipService.x - (geometryScreen?.x ?? 0) - contentWidth / 2
        return Math.max(0, Math.min(width - contentWidth, ideal))
    }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: focusHandler.keyboardFocusMode
    TooltipFocusHandler { id: focusHandler; tooltipWindow: root; panel: root.focusPanel }
    function requestPanelFocus() { if (requestedVisible && TooltipService.keyboardActive) focusHandler.requestFocus() }
    TooltipPointerHandler { objectName: "tooltipPointerHandler"; tooltipWindow: root }
}
