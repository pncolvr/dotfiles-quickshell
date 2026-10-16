pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Quickshell.Wayland
import Quickshell.Hyprland

// Shared activation and native-child handoff for public and private surfaces.
Item {
    id: root
    required property var host
    property var panel: null
    property var focusSession: panel
    property int activationGeneration: 0
    property bool ready: true
    property bool autoFocus: true
    property bool passive: false
    property bool dismissOnOutside: true
    property bool blocked: false
    property bool childDialogOpen: false
    property var interactionWindows: [host]
    property Item interactionTarget: host.surfaceComponent?.popupContentBounds ?? host.contentItem
    readonly property var nativeWindow: host.contentItem.Window.window
    property bool windowActive: nativeWindow?.active ?? false
    property bool keyboardEnabled: !passive
    property bool focusPanelPending: false
    readonly property bool hostRequestedVisible: host.requestedVisible ?? host.visible
    readonly property bool nativeDialogOpen: childDialogOpen || panel?.nativeDialogOpen === true
    readonly property int keyboardFocusMode: {
        switch (true) {
        case !hostRequestedVisible || !ready || blocked || nativeDialogOpen || !keyboardEnabled:
            return WlrKeyboardFocus.None
        case requestingKeyboardFocus:
            return WlrKeyboardFocus.Exclusive
        default:
            return WlrKeyboardFocus.OnDemand
        }
    }
    property bool requestingKeyboardFocus: false
    property bool restoringDialogFocus: false
    signal dismissRequested()
    visible: false

    function release() {
        activationGeneration++
        focusPanelPending = false
        requestingKeyboardFocus = false
        keyboardEnabled = !passive
        grab.active = false
    }
    function focusPanel() {
        if (!focusPanelPending || !panel) return
        if (typeof panel.focusSearch === "function") panel.focusSearch()
        else panel.forceActiveFocus()
        focusPanelPending = false
    }
    function requestFocus() {
        if (!hostRequestedVisible || !ready || blocked || nativeDialogOpen || !panel) return
        keyboardEnabled = true
        focusPanelPending = true
        // Subview changes need field focus, not another layer-shell activation.
        // Re-requesting Exclusive focus cancels an established native focus grab.
        if (windowActive && grab.active) {
            focusPanel()
            return
        }
        // A newly mapped native window may briefly report active before the
        // compositor sends its keyboard enter. Keep this request until activation.
        requestingKeyboardFocus = true
        const generation = ++activationGeneration
        Qt.callLater(() => {
            if (generation !== root.activationGeneration || !root.hostRequestedVisible || !root.ready
                || root.blocked || root.nativeDialogOpen || !root.panel) return
            root.focusPanel()
            root.settleFocus()
        })
    }
    function requestInteraction() {
        if (!hostRequestedVisible || !ready || blocked || nativeDialogOpen) return
        keyboardEnabled = true
        focusPanelPending = false // Preserve the clicked control, rather than refocusing Search.
        requestingKeyboardFocus = true
        if (windowActive) Qt.callLater(root.settleFocus)
    }
    function settleFocus() {
        if (!windowActive || !hostRequestedVisible || !ready || blocked || nativeDialogOpen || !keyboardEnabled) return
        focusPanel()
        if (restoringDialogFocus) {
            nativeWindow?.update()
            return
        }
        // Retain keyboard focus while the pointer is elsewhere. Outside clicks
        // release this grab even for persistent managers and secret prompts;
        // dismissOnOutside controls closure, not whether they can keep focus.
        grab.active = true
        requestingKeyboardFocus = false
    }
    function finishDialogFocus() {
        if (!restoringDialogFocus || nativeDialogOpen || !windowActive || !hostRequestedVisible || blocked) return
        restoringDialogFocus = false
        grab.active = true
        requestingKeyboardFocus = false
    }
    Connections {
        target: root.nativeWindow
        function onFrameSwapped() {
            if (root.restoringDialogFocus && !root.nativeDialogOpen && root.windowActive)
                Qt.callLater(root.finishDialogFocus)
        }
    }
    // Avoid reading a host visibility binding reentrantly while its Loader is
    // constructing a new panel (notably Vault opening its unlock prompt).
    function activate() { if (autoFocus) Qt.callLater(root.requestFocus) }
    function syncVisibility() {
        if (hostRequestedVisible) activate()
        else { restoringDialogFocus = false; release() }
    }
    onFocusSessionChanged: { release(); activate() }
    onReadyChanged: { if (ready) activate(); else { restoringDialogFocus = false; release() } }
    onBlockedChanged: if (blocked) release()

    onWindowActiveChanged: {
        if (windowActive) Qt.callLater(root.settleFocus)
        else {
            // Initial map/deactivation must not cancel a pending explicit open.
            // After activation, blur releases focus without taking it back.
            if (!requestingKeyboardFocus) { activationGeneration++; focusPanelPending = false }
            if (!dismissOnOutside) grab.active = false
        }
    }
    onNativeDialogOpenChanged: {
        if (nativeDialogOpen) { restoringDialogFocus = hostRequestedVisible; release() }
        else if (restoringDialogFocus && hostRequestedVisible) requestFocus()
    }
    Connections {
        target: root.host
        ignoreUnknownSignals: true
        function onRequestedVisibleChanged() { root.syncVisibility() }
        function onVisibleChanged() { root.syncVisibility() }
    }
    TapHandler {
        // Passive observation does not consume the control's press or move it.
        parent: root.interactionTarget
        target: null
        enabled: root.passive && root.hostRequestedVisible
        acceptedButtons: Qt.AllButtons
        gesturePolicy: TapHandler.DragThreshold
        onPressedChanged: if (pressed) root.requestInteraction()
    }
    HyprlandFocusGrab {
        id: grab
        windows: root.interactionWindows
        onCleared: if (root.hostRequestedVisible && root.ready && root.dismissOnOutside
            && !root.blocked && !root.nativeDialogOpen && !root.restoringDialogFocus)
            root.dismissRequested()
    }
}
