import QtQuick
import Quickshell.Wayland
import "../theme"
import "../services"

TopPanelTooltip {
    id: root
    readonly property bool onTooltipScreen: !TooltipService.screen || TooltipService.screen === screen
    readonly property bool shouldShow: TooltipService.visible && onTooltipScreen && !TooltipService.ownsTooltipWindow
    readonly property var loadedContent: loader.item
    readonly property var nativeWindow: focusHandler.nativeWindow
    readonly property bool requestingKeyboardFocus: focusHandler.requestingKeyboardFocus
    visible: shouldShow
    WlrLayershell.keyboardFocus: requestingKeyboardFocus && TooltipService.keyboardActive && shouldShow
        ? WlrKeyboardFocus.Exclusive
        : TooltipService.source?.tooltipKeyboardFocus
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    TooltipFocusHandler { id: focusHandler; tooltipWindow: root; panel: loader.item }
    TooltipPointerHandler { objectName: "tooltipPointerHandler"; tooltipWindow: root }

    contentWidth: loader.implicitWidth + Theme.tooltipPaddingWidth * 2
    contentHeight: loader.implicitHeight + Theme.tooltipPaddingHeight * 2
    contentX: {
        const ideal = TooltipService.centered
            ? (width - contentWidth) / 2
            : TooltipService.x - (geometryScreen?.x ?? 0) - contentWidth / 2
        return Math.max(0, Math.min(width - contentWidth, ideal))
    }

    Loader {
        id: loader
        active: root.shouldShow
        anchors.centerIn: parent
        sourceComponent: TooltipService.content
        onLoaded: if (TooltipService.keyboardActive) focusHandler.requestFocus()
    }
}
