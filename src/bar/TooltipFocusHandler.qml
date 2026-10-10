import QtQuick
import QtQuick.Window
import "../services"

Item {
    id: root
    required property var tooltipWindow
    property var panel: null
    readonly property var nativeWindow: tooltipWindow.contentItem.Window.window
    property bool requestingKeyboardFocus: false
    property bool pointerPending: false
    visible: false

    function releaseFocusRequest() {
        if (nativeWindow?.active) requestingKeyboardFocus = false
    }
    function requestFocus() { focusTimer.restart() }

    Connections {
        target: root.tooltipWindow
        function onVisibleChanged() {
            if (!root.tooltipWindow.visible) {
                root.requestingKeyboardFocus = false
                root.pointerPending = false
            }
        }
    }
    Connections {
        target: root.nativeWindow
        function onActiveChanged() {
            if (root.nativeWindow?.active) Qt.callLater(root.releaseFocusRequest)
        }
        function onFrameSwapped() {
            if (!root.pointerPending) return
            root.pointerPending = false
            if (root.tooltipWindow.visible && TooltipService.keyboardActive)
                BarModuleService.movePointer(TooltipService.source)
        }
    }
    Timer {
        id: focusTimer
        interval: 0
        onTriggered: {
            if (!root.tooltipWindow.visible || !TooltipService.keyboardActive) return
            root.requestingKeyboardFocus = !root.nativeWindow?.active
            if (root.panel && typeof root.panel.focusSearch === "function") {
                root.panel.focusSearch()
                root.pointerPending = true
                root.nativeWindow?.update()
            }
            Qt.callLater(root.releaseFocusRequest)
        }
    }
    Connections {
        target: TooltipService
        function onFocusRequested() { if (root.tooltipWindow.visible) root.requestFocus() }
        function onKeyboardActiveChanged() {
            if (!TooltipService.keyboardActive) {
                root.requestingKeyboardFocus = false
                root.pointerPending = false
            }
        }
    }
}
