pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Wayland
import "../../src/bar"
import "../../src/theme/ui" as UI
import "../../src/services"
import "../../src/config"

Scope {
    id: root
    property int step: 0
    property bool failed: false
    property bool simulatedActive: false
    property int dismissals: 0
    property var temporaryOwner: null
    property int focusCalls: 0
    property bool managerActive: false
    function check(ok, message) { if (!ok) { failed = true; console.error("LIFECYCLE FAIL:", message) } }
    function open() { TooltipService.show(200, null, origin, false) }
    QtObject { id: origin }
    QtObject { id: other }
    QtObject { id: firstOwner }
    QtObject { id: secondOwner }
    Test.TestCase { id: events; when: false }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 400
        implicitHeight: 200
        UI.PanelFocusScope {
            id: focusScope
            anchors.fill: parent
            property bool dialogOpen: false
            property string draft: "preserve me"
            panel: QtObject { readonly property bool nativeDialogOpen: focusScope.dialogOpen }
            onDismissRequested: { root.dismissals++; TooltipService.dismiss() }
            UI.SearchField { id: search; width: 360; y: 10 }
            UI.InputField {
                id: editor
                width: 360; y: 60
                Keys.onEscapePressed: { text = ""; search.forceActiveFocus() }
            }
        }
    }
    // The same window policy adapter as both public/private tooltip hosts.
    TooltipFocusHandler {
        id: behavior
        tooltipWindow: window
        // A real platform window supplies focus in production. Model compositor
        // transitions here without touching the user's windows or cursor.
        windowActive: root.simulatedActive
        ready: TooltipService.visible
        panel: focusScope
        // Avoid an unsupported native grab in an offscreen FloatingWindow.
        dismissOnOutside: false
    }
    Component { id: temporaryOwnerFactory; TooltipFocusHandler { dismissOnOutside: false } }
    UI.WindowFocusHandler {
        id: manager
        host: window
        panel: Item {
            property string draft: "saved draft"
            function focusSearch() { root.focusCalls++ }
        }
        autoFocus: false
        windowActive: root.managerActive
        dismissOnOutside: false
    }
    Timer {
        interval: Config.tooltipHideDelay + 100
        running: true
        repeat: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                root.open()
                TooltipService.setPanelHovered(true)
                root.check(!behavior.requestingKeyboardFocus && behavior.keyboardFocusMode === WlrKeyboardFocus.None,
                    "hover must never enable native keyboard focus or a focus grab")
                search.forceActiveFocus(); search.text = "query"; search.textEdited()
                root.simulatedActive = true
                TooltipService.setPanelHovered(false)
                break
            case 1:
                root.check(!TooltipService.visible && !TooltipService.interactionHeld && search.text === "",
                    "a query does not latch the panel open; closing resets search")
                root.open(); behavior.requestInteraction(); editor.forceActiveFocus(); editor.text = "draft"
                break
            case 2:
                root.check(TooltipService.interactionHeld && !TooltipService.pinned, "active editor retains only its owner without pinning")
                TooltipService.show(300, null, other, false)
                root.check(TooltipService.source === origin, "another hover cannot replace an active editor")
                focusScope.dialogOpen = true
                root.simulatedActive = false
                editor.focus = false
                break
            case 3:
                root.check(TooltipService.visible && TooltipService.interactionHeld && !TooltipService.pinned,
                    "native child retains its owner after keyboard focus leaves, without pinning")
                root.check(!behavior.requestingKeyboardFocus, "parent yields keyboard focus to its native child")
                focusScope.dialogOpen = false
                break
            case 4:
                root.check(!TooltipService.interactionHeld && !TooltipService.pinned && !TooltipService.visible,
                    "rejecting or accepting a native dialog releases retention and resumes hover dismissal")
                root.open(); TooltipService.togglePin(200, null, origin, false)
                focusScope.dialogOpen = true
                break
            case 5:
                root.check(TooltipService.pinned && TooltipService.interactionHeld, "native child preserves a manual pin")
                focusScope.dialogOpen = false
                break
            case 6:
                root.check(TooltipService.visible && TooltipService.pinned && !TooltipService.interactionHeld,
                    "closing a native child preserves exactly the original manual pin")
                TooltipService.togglePin(200, null, origin, false)
                TooltipService.setTriggerHovered(origin, false)
                break
            case 7:
                root.check(!TooltipService.visible, "manual unpin restores pointer-leave dismissal")
                root.open(); editor.forceActiveFocus(); root.simulatedActive = true
                break
            case 8:
                root.check(TooltipService.interactionHeld, "editing can retain again after reopening")
                root.simulatedActive = false
                break
            case 9:
                root.check(!TooltipService.visible && !TooltipService.interactionHeld, "switching apps releases an editor hold")
                root.open()
                TooltipService.setInteraction(firstOwner, true, false)
                TooltipService.show(300, null, other, false)
                root.check(TooltipService.source === other && !TooltipService.interactionHeld,
                    "keyboard-only retention does not block another module")
                root.open()
                TooltipService.setInteraction(firstOwner, true)
                TooltipService.setInteraction(secondOwner, true)
                TooltipService.setInteraction(firstOwner, false)
                root.check(TooltipService.interactionHeld, "one owner cannot release another owner's hold")
                TooltipService.setInteraction(secondOwner, false)
                break
            case 10:
                root.check(!TooltipService.visible, "last owner releases the panel")
                TooltipService.show(300, null, other, false)
                TooltipService.setPanelHovered(true)
                TooltipService.setInteraction(firstOwner, false)
                root.check(!TooltipService.interactionHeld && TooltipService.source === other,
                    "stale cleanup cannot change another session")
                editor.forceActiveFocus(); editor.text = "cancel this"
                events.keyClick(Qt.Key_Escape)
                root.check(editor.text === "" && root.dismissals === 0, "editor consumes Escape before the panel")
                // Search consumes its clear action, then an unhandled Escape reaches the common scope.
                search.focus = false; focusScope.forceActiveFocus()
                events.keyClick(Qt.Key_Escape)
                root.check(root.dismissals === 1 && !TooltipService.visible, "unhandled Escape closes the panel")
                root.open(); editor.forceActiveFocus()
                root.temporaryOwner = temporaryOwnerFactory.createObject(root, {
                    tooltipWindow: window, panel: focusScope, windowActive: true
                })
                break
            case 11:
                root.check(TooltipService.interactionHeld, "temporary owner acquires an editing hold")
                root.temporaryOwner.destroy(); root.temporaryOwner = null
                break
            case 12:
                root.check(!TooltipService.interactionHeld && !TooltipService.visible,
                    "destroying the owner always releases its hold")
                manager.requestFocus()
                manager.focusSession = other
                break
            case 13:
                root.check(root.focusCalls === 0, "a replaced session cancels its queued focus callback")
                root.managerActive = true
                manager.requestFocus()
                root.managerActive = false
                break
            case 14:
                root.check(manager.requestingKeyboardFocus && root.focusCalls === 1, "initial map/deactivation does not cancel the explicit focus request")
                root.managerActive = true
                break
            case 15:
                root.check(!manager.requestingKeyboardFocus, "initial activation returns to on-demand focus")
                root.managerActive = false
                break
            case 16:
                root.check(!manager.requestingKeyboardFocus && root.focusCalls === 1 && manager.panel.draft === "saved draft",
                    "switching apps preserves the manager/draft and never reclaims focus")
                root.managerActive = true
                break
            case 17:
                root.check(root.focusCalls === 1, "returning to manager preserves the current editor focus")
                console.log(root.failed ? "LIFECYCLE FAIL: panels" : "PASS: scoped panel editing, native-dialog cleanup, manual pins, focus handoff, Escape hierarchy and persistent manager drafts")
                Qt.quit()
                break
            }
        }
    }
}
