pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../src/theme/ui" as UI

Scope {
    id: root
    property bool failed: false
    property int phase: 0
    property int previousCount: 0
    property ModelRow firstDelegate: null
    function verify(value, message) {
        if (!value) { failed = true; console.error("BATCH FAIL:", message) }
    }
    function source(count, prefix) {
        return Array.from({length: count}, (_, index) => ({id: prefix + index,
            body: "Notification " + index, actions: [{identifier: "open", text: "Open"}]}))
    }
    UI.BatchedListModel { id: model }
    FloatingWindow {
        visible: true
        implicitWidth: 400
        implicitHeight: 500
        Column {
            width: parent.width
            Repeater {
                id: rows
                model: model
                ModelRow {}
            }
        }
    }
    component ModelRow: Text {
        required property var value
        required property int index
        text: value.id + ": " + value.body
    }
    Timer {
        interval: 100; running: true
        onTriggered: {
            model.items = root.source(3, "original-")
            root.verify(rows.count === 3 && !model.loading, "collapsed cards available immediately")
            root.firstDelegate = rows.itemAt(0) as ModelRow
            root.verify(root.firstDelegate.value.actions[0].identifier === "open", "nested action data preserved")
            model.items = root.source(25, "original-")
            root.verify(rows.count < 25 && model.loading, "expanded list builds progressively")
            root.verify(rows.itemAt(0) === root.firstDelegate, "existing card retained on expansion")
            root.previousCount = model.count
            root.phase = 1
        }
    }
    FrameAnimation {
        running: root.phase > 0 && root.phase < 4
        onTriggered: {
            root.verify(model.count - root.previousCount <= Math.max(1, model.batchSize), "per-frame creation bounded")
            root.verify(rows.count === model.count, "delegates follow appended rows")
            if (!model.loading) {
                if (root.phase === 1) {
                    root.verify(rows.count === 25 && (rows.itemAt(24) as ModelRow).value.id === "original-24", "full list in source order")
                    root.verify(rows.itemAt(0) === root.firstDelegate, "first card retained throughout expansion")
                    model.items = root.source(70, "pending-")
                    root.verify(model.loading, "larger source queues work")
                    model.items = root.source(2, "replacement-")
                    root.verify(rows.count === 2 && !model.loading, "collapse cancels pending rows immediately")
                    root.verify(rows.itemAt(0) === root.firstDelegate && (rows.itemAt(0) as ModelRow).value.id === "replacement-0", "existing card updated without recreation")
                    model.items = root.source(18, "stale-")
                    model.items = root.source(10, "latest-")
                    root.phase = 2
                } else if (root.phase === 2) {
                    root.verify(rows.count === 10, "latest source controls final count")
                    for (let index = 0; index < rows.count; index++) {
                        root.verify((rows.itemAt(index) as ModelRow).value.id === "latest-" + index, "no stale queued rows")
                    }
                    model.items = []
                    root.verify(rows.count === 0 && !model.loading, "empty source clears and stops builder")
                    model.batchSize = 0
                    model.items = root.source(7, "single-")
                    root.phase = 3
                } else {
                    root.verify(rows.count === 7, "nonpositive batch size still completes")
                    model.items = []
                    root.phase = 4
                    finish.start()
                }
            }
            root.previousCount = model.count
        }
    }
    Timer {
        id: finish
        interval: 100
        onTriggered: {
            root.verify(rows.count === 0 && !model.builder.running, "no residual work after clearing")
            if (!root.failed) console.log("PASS: bounded per-frame creation, stable cards, collapse cancellation, source replacement and nested data")
            Qt.quit()
        }
    }
}
