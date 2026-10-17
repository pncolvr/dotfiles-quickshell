pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQml.Models
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../services" as Services

// Shared activation and native-child handoff for public and private surfaces.
Item {
    id: root
    required property var host
    property var panel: null
    property var focusSession: panel
    property int activationGeneration: 0
    property bool ready: true
    property bool autoFocus: true
    property bool eagerActivation: false
    property bool activationSettled: false
    readonly property bool openingFocus: eagerActivation && autoFocus && !passive && !activationSettled
    property bool passive: false
    property bool dismissOnOutside: true
    property bool blocked: false
    property var handoffOwner: host.picker ?? null
    readonly property bool handoffHeld: Services.PanelFocusService.held(root)
    property bool childDialogOpen: false
    property var interactionWindows: [host]
    property Item interactionTarget: host.surfaceComponent?.popupContentBounds ?? host.contentItem
    readonly property var nativeWindow: host.contentItem.Window.window
    property bool windowActive: nativeWindow?.active ?? false
    readonly property bool retainingNativeFocus: hostRequestedVisible && windowActive && grab.active
        && !blocked && !handoffHeld && !nativeDialogOpen
    property bool keyboardEnabled: !passive
    property bool focusPanelPending: false
    readonly property bool hostRequestedVisible: host.requestedVisible ?? host.visible
    readonly property bool nativeDialogOpen: childDialogOpen || panel?.nativeDialogOpen === true
    readonly property int keyboardFocusMode: {
        switch (true) {
        case !hostRequestedVisible || blocked || handoffHeld || nativeDialogOpen || !keyboardEnabled:
            return WlrKeyboardFocus.None
        case openingFocus:
            return WlrKeyboardFocus.Exclusive
        case !ready && !retainingNativeFocus:
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
    Component.onCompleted: Services.PanelFocusService.register(root)
    Component.onDestruction: Services.PanelFocusService.unregister(root)

    function restoreFocus(item) {
        if (!hostRequestedVisible || blocked || handoffHeld || nativeDialogOpen) return false
        if (item?.visible && item.enabled) {
            item.forceActiveFocus(Qt.OtherFocusReason)
            requestInteraction()
            return true
        }
        requestFocus()
        return false
    }

    function release() {
        activationGeneration++
        activationSettled = false
        focusPanelPending = false
        requestingKeyboardFocus = false
        keyboardEnabled = !passive
        grab.active = false
    }
    function focusPanel() {
        if (!ready || !focusPanelPending || !panel) return
        if (typeof panel.focusSearch === "function") panel.focusSearch()
        else panel.forceActiveFocus()
        focusPanelPending = false
    }
    function requestFocus() {
        if (!hostRequestedVisible || !ready || blocked || handoffHeld || nativeDialogOpen || !panel) return
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
        // Explicit launchers prepare their input before the first rendered frame.
        if (eagerActivation) focusPanel()
        const generation = ++activationGeneration
        Qt.callLater(() => {
            if (generation !== root.activationGeneration || !root.hostRequestedVisible || !root.ready
                || root.blocked || root.handoffHeld || root.nativeDialogOpen || !root.panel) return
            root.focusPanel()
            root.settleFocus()
        })
    }
    function requestInteraction() {
        if (!hostRequestedVisible || !ready || blocked || handoffHeld || nativeDialogOpen) return
        keyboardEnabled = true
        focusPanelPending = false // Preserve the clicked control, rather than refocusing Search.
        if (windowActive && grab.active) return
        requestingKeyboardFocus = true
        if (windowActive) Qt.callLater(root.settleFocus)
    }
    function queueInteraction() {
        const generation = activationGeneration
        Qt.callLater(() => {
            if (generation === root.activationGeneration) root.requestInteraction()
        })
    }
    Connections {
        target: root.nativeWindow
        function onActiveFocusItemChanged() {
            // Text-control presses can bypass ancestor handlers. Mouse focus is
            // an explicit interaction; programmatic/hover focus stays passive.
            const control = root.nativeWindow?.activeFocusItem
            if (root.passive && root.hostRequestedVisible && control?.focusReason === Qt.MouseFocusReason)
                root.queueInteraction()
        }
    }
    function settleFocus() {
        if (!windowActive || !hostRequestedVisible || !ready || blocked || handoffHeld || nativeDialogOpen || !keyboardEnabled) return
        focusPanel()
        if (restoringDialogFocus) {
            nativeWindow?.update()
            return
        }
        // Retain keyboard focus while the pointer is elsewhere. Outside clicks
        // release this grab even for persistent managers and secret prompts;
        // dismissOnOutside controls closure, not whether they can keep focus.
        grab.active = true
        activationSettled = true
        requestingKeyboardFocus = false
    }
    function finishDialogFocus() {
        if (!restoringDialogFocus || nativeDialogOpen || !windowActive || !hostRequestedVisible || blocked || handoffHeld) return
        restoringDialogFocus = false
        grab.active = true
        activationSettled = true
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
    // Loader content can change inside the same focused native surface.
    // Keep its established grab while the replacement control is constructed.
    onFocusSessionChanged: { if (!retainingNativeFocus) release(); activate() }
    onReadyChanged: {
        if (ready) activate()
        else if (!retainingNativeFocus) { restoringDialogFocus = false; release() }
    }
    onBlockedChanged: if (blocked) release()
    onHandoffHeldChanged: if (handoffHeld) {
        release()
        // Existing panels must not all request opening focus when the hold ends.
        // Only the saved destination explicitly requests focus on return.
        activationSettled = true
    }

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
        onPressedChanged: if (pressed) root.queueInteraction()
    }
    Instantiator {
        // Recreate the observer with each focused control: parenting a persistent
        // handler to a Loader's field would destroy it when that field unloads.
        model: root.passive && root.hostRequestedVisible && root.nativeWindow?.activeFocusItem
            ? [root.nativeWindow.activeFocusItem] : []
        delegate: TapHandler {
            required property var modelData
            parent: modelData
            target: null
            acceptedButtons: Qt.AllButtons
            gesturePolicy: TapHandler.DragThreshold
            onPressedChanged: if (pressed) root.queueInteraction()
        }
    }
    HyprlandFocusGrab {
        id: grab
        windows: root.interactionWindows
        onCleared: if (root.hostRequestedVisible && root.ready && root.dismissOnOutside
            && !root.blocked && !root.handoffHeld && !root.nativeDialogOpen && !root.restoringDialogFocus)
            root.dismissRequested()
    }
}
