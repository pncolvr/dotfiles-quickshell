pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Wayland
import "../../src/ui" as UI
import "../../src/modules/launcher"
import "../../src/services"

WorkerScope {
    id: root
    property bool simulatedActive: false
    property int focusCalls: 0
    property int dismissals: 0
    QtObject { id: fakePicker; property int mode: PickerService.Mode.Menu; signal opened(); function close(reason) {} }
    Test.TestCase { id: events; when: false }
    FloatingWindow {
        id: window
        visible: true
        property bool requestedVisible: false
        implicitWidth: 400
        implicitHeight: 100
        Item {
            id: contentPanel
            anchors.fill: parent
            property bool focusReady: false
            property bool nativeDialogOpen: false
            property bool dismissOnOutside: false
            function focusSearch() { root.focusCalls++; search.forceActiveFocus() }
            UI.InputField { id: search; width: 380 }
        }
    }
    LauncherFocusHandler {
        id: behavior
        host: window
        panel: contentPanel
        picker: fakePicker
        onDismissRequested: root.dismissals++
        windowActive: root.simulatedActive
    }
    UI.WindowFocusHandler {
        id: hover
        host: window
        panel: contentPanel
        passive: true
        autoFocus: false
        windowActive: false
    }
    function check(condition, message) { if (!condition) throw new Error(message) }
    Timer {
        interval: 50
        running: true
        onTriggered: {
            try {
                root.check(!behavior.dismissOnOutside, "persistent panel opts out of outside dismissal")
                contentPanel.dismissOnOutside = true
                root.check(behavior.dismissOnOutside, "ordinary panels retain outside dismissal")
                fakePicker.mode = PickerService.Mode.Secret
                root.check(!behavior.dismissOnOutside, "secret prompts remain persistent")
                fakePicker.mode = PickerService.Mode.Menu
                contentPanel.dismissOnOutside = false
                root.check(behavior.keyboardFocusMode === WlrKeyboardFocus.None, "closed launcher cannot take keyboard input")
                window.requestedVisible = true
                root.check(!behavior.ready && behavior.keyboardFocusMode === WlrKeyboardFocus.Exclusive,
                    "first map requests exclusive activation before lazy content readiness")
                root.check(hover.keyboardFocusMode === WlrKeyboardFocus.None, "hover remains passive during launcher preparation")
                contentPanel.focusReady = true
                fakePicker.opened()
                root.check(root.focusCalls === 1 && search.focus, "opened launcher prepares its search synchronously")
                for (const key of [Qt.Key_H, Qt.Key_Y, Qt.Key_P, Qt.Key_R]) events.keyClick(key, Qt.NoModifier, 0)
                root.check(search.text === "hypr", "the prepared input retains the first dispatched key without an animation wait")
                root.simulatedActive = true
                events.wait(30)
                root.check(behavior.activationSettled && behavior.keyboardFocusMode === WlrKeyboardFocus.OnDemand,
                    "activation settles back to on-demand")
                contentPanel.dismissOnOutside = true
                behavior.desktopActivated({name: "workspacev2", data: "1,main"})
                behavior.desktopActivated({name: "activewindowv2", data: ""})
                root.check(root.dismissals === 0 && behavior.activationSettled,
                    "unrelated events and layer-shell activation do not dismiss a focused panel")
                root.simulatedActive = false
                root.check(behavior.restoreFocus(search) && behavior.requestingKeyboardFocus,
                    "returning to the original field requests native activation")
                behavior.desktopActivated({name: "activewindowv2", data: "1234"})
                root.check(root.dismissals === 0 && behavior.requestingKeyboardFocus
                    && behavior.keyboardFocusMode === WlrKeyboardFocus.Exclusive,
                    "transient desktop activation cannot cancel a pending native return")
                root.simulatedActive = true
                events.wait(30)
                root.check(!behavior.requestingKeyboardFocus && behavior.activationSettled,
                    "native return protection ends after activation settles")
                behavior.desktopActivated({name: "activewindowv2", data: "1234"})
                root.check(root.dismissals === 0 && behavior.desktopActivationPending,
                    "late desktop IPC cannot dismiss a surface that still owns native focus")
                root.simulatedActive = false
                events.wait(20)
                root.check(root.dismissals === 1 && !behavior.desktopActivationPending,
                    "native deactivation confirms an earlier desktop IPC event")
                root.simulatedActive = true
                events.wait(20)
                behavior.desktopActivated({name: "activewindowv2", data: "1234"})
                behavior.desktopActivated({name: "activewindowv2", data: ""})
                root.simulatedActive = false
                events.wait(20)
                root.check(root.dismissals === 1 && !behavior.desktopActivationPending,
                    "a superseding layer-shell event invalidates pending desktop activation")
                behavior.desktopActivated({name: "activewindowv2", data: "1234"})
                root.check(root.dismissals === 2,
                    "desktop IPC arriving after native deactivation also dismisses")
                contentPanel.dismissOnOutside = false
                behavior.passive = true
                root.simulatedActive = true
                behavior.requestInteraction()
                events.wait(20)
                root.check(behavior.keyboardFocusMode === WlrKeyboardFocus.OnDemand,
                    "persistent tooltip has native keyboard interaction before desktop activation")
                behavior.desktopActivated({name: "activewindowv2", data: "1234"})
                root.check(root.dismissals === 2 && behavior.keyboardFocusMode === WlrKeyboardFocus.None,
                    "desktop activation releases a persistent tooltip's keyboard before native blur")
                behavior.passive = false
                behavior.requestFocus()
                events.wait(20)
                const focusCalls = root.focusCalls
                root.simulatedActive = false
                events.wait(20)
                root.check(root.focusCalls === focusCalls && behavior.keyboardFocusMode === WlrKeyboardFocus.OnDemand,
                    "blurred persistent prompts never reacquire focus")
                window.requestedVisible = false
                root.check(behavior.keyboardFocusMode === WlrKeyboardFocus.None, "logical closing releases input before native hiding")
                contentPanel.focusReady = false
                window.requestedVisible = true
                root.check(behavior.keyboardFocusMode === WlrKeyboardFocus.Exclusive, "reopening prepares exclusive activation again")
                contentPanel.nativeDialogOpen = true
                root.check(behavior.keyboardFocusMode === WlrKeyboardFocus.None, "native children always receive focus instead of their parent")
                window.requestedVisible = false
                contentPanel.nativeDialogOpen = false
                events.wait(20)
                root.check(behavior.keyboardFocusMode === WlrKeyboardFocus.None, "stale preparation cannot refocus a closed launcher")
                console.log("PASS: first-map launcher activation, synchronous input readiness, passive hover, blur and cancellation")
            } catch (error) {
                console.error("OPENING POLICY FAIL:", error)
            }
            Qt.quit()
        }
    }
}
