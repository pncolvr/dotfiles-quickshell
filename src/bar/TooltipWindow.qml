import QtQuick
import QtQuick.Window
import Quickshell.Wayland
import "../theme"
import "../services"

TopPanelTooltip {
    id: root
    readonly property bool onTooltipScreen: !TooltipService.screen || TooltipService.screen === screen
    readonly property bool shouldShow: TooltipService.visible && onTooltipScreen && !TooltipService.ownsTooltipWindow
    readonly property var loadedContent: loader.item
    readonly property var nativeWindow: root.contentItem.Window.window
    property bool requestingKeyboardFocus: false
    visible: shouldShow
    WlrLayershell.keyboardFocus: requestingKeyboardFocus && TooltipService.keyboardActive && shouldShow
        ? WlrKeyboardFocus.Exclusive
        : TooltipService.source?.tooltipKeyboardFocus
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    onShouldShowChanged: if (!shouldShow) requestingKeyboardFocus = false

    function releaseFocusRequest() {
        if (nativeWindow?.active) requestingKeyboardFocus = false
    }

    Connections {
        target: root.nativeWindow
        function onActiveChanged() {
            if (root.nativeWindow?.active) Qt.callLater(root.releaseFocusRequest)
        }
    }

    Timer {
        id: focusTimer
        interval: 0
        onTriggered: {
            if (!root.shouldShow || !TooltipService.keyboardActive) return
            root.requestingKeyboardFocus = !root.nativeWindow?.active
            const panel = root.loadedContent
            if (panel && typeof panel.focusSearch === "function") panel.focusSearch(true)
            Qt.callLater(root.releaseFocusRequest)
        }
    }
    Connections {
        target: TooltipService
        function onFocusRequested() { if (root.shouldShow) focusTimer.restart() }
        function onKeyboardActiveChanged() { if (!TooltipService.keyboardActive) root.requestingKeyboardFocus = false }
    }

    contentWidth: loader.implicitWidth + Theme.tooltipPaddingWidth * 2
    contentHeight: loader.implicitHeight + Theme.tooltipPaddingHeight * 2
    contentX: {
        const ideal = TooltipService.centered
            ? (width - contentWidth) / 2
            : TooltipService.x - (screen?.x ?? 0) - contentWidth / 2
        return Math.max(0, Math.min(width - contentWidth, ideal))
    }

    Loader {
        id: loader
        active: root.shouldShow
        anchors.centerIn: parent
        sourceComponent: TooltipService.content
        onLoaded: if (TooltipService.keyboardActive) focusTimer.restart()
    }

    HoverHandler {
        onPointChanged: if (hovered) {
            const pos = parent.mapToGlobal(point.position.x, point.position.y)
            TooltipService.observePointer(pos.x, pos.y, true)
        }
        onHoveredChanged: if (root.visible) TooltipService.setPanelHovered(hovered)
    }
}
