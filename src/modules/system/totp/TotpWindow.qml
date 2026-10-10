import QtQuick
import Quickshell.Wayland
import "../../../bar"
import "../../../theme"
import "../../../services"

PrivateTooltipWindow {
    id: root
    visible: TooltipService.visible && TooltipService.source?.totpModule === true && !!targetScreen
    contentWidth: loader.implicitWidth + Theme.tooltipPaddingWidth * 2
    contentHeight: loader.implicitHeight + Theme.tooltipPaddingHeight * 2
    readonly property var loadedContent: loader.item
    readonly property var nativeWindow: focusHandler.nativeWindow
    readonly property bool requestingKeyboardFocus: focusHandler.requestingKeyboardFocus
    WlrLayershell.keyboardFocus: requestingKeyboardFocus && TooltipService.keyboardActive && visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    TooltipFocusHandler { id: focusHandler; tooltipWindow: root; panel: loader.item }

    Loader {
        id: loader
        active: root.visible
        anchors.centerIn: parent
        sourceComponent: TooltipService.content
        onLoaded: if (TooltipService.keyboardActive) focusHandler.requestFocus()
    }
}
