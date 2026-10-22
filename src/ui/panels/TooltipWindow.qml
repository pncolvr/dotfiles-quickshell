import QtQuick
import Quickshell.Wayland
import "../../theme"
import "../../services"

TopPanelTooltip {
    id: root
    capturePanel: loadedContent
    onCaptureHideRequested: TooltipService.dismiss()
    readonly property bool onTooltipScreen: !TooltipService.screen || TooltipService.screen === screen
    readonly property bool shouldShow: TooltipService.visible && onTooltipScreen && !TooltipService.ownsTooltipWindow
    readonly property var loadedContent: keys.loadedContent
    readonly property var nativeWindow: focusHandler.nativeWindow
    readonly property bool requestingKeyboardFocus: focusHandler.requestingKeyboardFocus
    requestedVisible: shouldShow
    WlrLayershell.keyboardFocus: focusHandler.keyboardFocusMode
    TooltipFocusHandler { id: focusHandler; tooltipWindow: root; panel: keys }
    TooltipPointerHandler { objectName: "tooltipPointerHandler"; tooltipWindow: root }

    contentWidth: keys.implicitWidth + Theme.tooltipPaddingWidth * 2
    contentHeight: keys.implicitHeight + Theme.tooltipPaddingHeight * 2
    contentX: {
        const ideal = TooltipService.centered
            ? (width - contentWidth) / 2
            : TooltipService.x - (geometryScreen?.x ?? 0) - contentWidth / 2
        return Math.max(0, Math.min(width - contentWidth, ideal))
    }

    TooltipContent { id: keys; host: root; anchors.fill: parent }
}
