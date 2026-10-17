pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test

// Run each action from a fresh event-loop turn. Nested QtTest waits during
// native mapping can dispatch activation/deactivation before Qt has unwound
// the preceding surface change, leaving its focus state inconsistent.
Item {
    id: root
    visible: false
    property var steps: []
    property bool running: false
    property bool busy: false
    property int timeout: 1500
    property int currentStep: 0
    property double started: 0
    signal failed(string message)
    signal completed()
    Test.TestEvent { id: events }

    function check(ok, message) { if (!ok) throw new Error(message) }
    function add(name, action) { steps.push({name, run: action}) }
    function waitFor(name, predicate, action = null) { steps.push({name, ready: predicate, run: action}) }
    function pause(milliseconds) {
        waitFor("settle for " + milliseconds + "ms", () => Date.now() - root.started >= milliseconds)
    }
    function key(value, modifiers = Qt.NoModifier) {
        check(events.keyClick(value, modifiers, 0), "no active native window for key " + value)
    }
    function click(item, x = 20, y = 15) {
        check(events.mouseClick(item, x, y, Qt.LeftButton, Qt.NoModifier, 0), "no native window for click")
    }
    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const result = find(child, name)
            if (result) return result
        }
        return null
    }
    onRunningChanged: if (running) started = Date.now()
    Timer {
        interval: 10
        running: root.running && !root.busy
        repeat: true
        onTriggered: {
            if (root.busy) return
            const step = root.steps[root.currentStep]
            if (!step) { root.running = false; root.completed(); return }
            // QTest key/mouse helpers can process events internally as well.
            // Stop the driver while an action runs so it cannot reenter itself.
            root.busy = true
            try {
                if (step.ready && !step.ready()) {
                    root.check(Date.now() - root.started < root.timeout, "timed out")
                    return
                }
                if (step.run) step.run()
                root.currentStep++
                root.started = Date.now()
            } catch (error) {
                root.running = false
                root.failed(step.name + ": " + error)
            } finally {
                root.busy = false
            }
        }
    }
}
