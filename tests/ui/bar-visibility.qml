import QtQuick
import "../../src/ui/bar" as Bar

Item {
    id: root
    property bool failed: false
    function check(ok, message) { if (!ok) { failed = true; console.error("BAR VISIBILITY FAIL:", message) } }

    Bar.BarVisibilityState { id: state; hideDelay: 10 }
    Timer {
        interval: 1
        running: true
        onTriggered: {
            root.check(state.shown, "disabled auto-hide leaves the bar visible")
            state.enabled = true
            root.check(!state.shown, "enabling auto-hide hides an idle bar")
            state.hovered = true
            root.check(state.shown, "edge hover reveals the bar")
            state.attachmentOpen = true
            state.hovered = false
            root.check(state.shown, "an attached panel holds the bar open")
            state.attachmentOpen = false
            settle.start()
        }
    }
    Timer {
        id: settle
        interval: 20
        onTriggered: {
            root.check(!state.shown, "leaving the bar hides it after the grace period")
            state.manualVisibility = 1
            root.check(state.shown, "manual visible state holds the bar open")
            state.manualVisibility = -1
            root.check(!state.shown, "manual hidden state hides the idle bar")
            state.emptyWorkspace = true
            root.check(!state.shown, "manual hidden state overrides empty-workspace reveal")
            state.manualVisibility = 0
            root.check(state.shown, "an empty workspace reveals the automatic bar")
            state.showOnEmptyWorkspace = false
            root.check(!state.shown, "the empty-workspace setting independently disables reveal")
            state.enabled = false
            root.check(state.shown, "disabling auto-hide restores the bar immediately")
            console.log(root.failed ? "BAR VISIBILITY FAIL" : "PASS: bar auto-hide state")
            Qt.quit()
        }
    }
}
