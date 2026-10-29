pragma ComponentBehavior: Bound

import QtQuick
import "../../src/services"

WorkerScope {
    id: root
    property int stage: 0
    property int ticks: 0
    property bool failed: false
    property var events: []

    function check(ok, message) {
        if (!ok) { failed = true; console.error("DISPATCH FAIL:", message) }
    }
    function payload(source, body) {
        return {source, appName: source, urgency: "normal", expireTime: 10000,
            summary: "", body}
    }
    function beginPair(cohort) {
        NotificationDispatchService.beginBatch(cohort, "twitch")
        NotificationDispatchService.beginBatch(cohort, "updates")
    }

    Connections {
        target: NotificationDispatchService
        function onDispatched(cohort, count) {
            root.events = root.events.concat([{cohort, count}])
        }
    }

    Timer {
        interval: 20
        repeat: true
        running: true
        onTriggered: {
            if (++root.ticks > 150) {
                root.check(false, "timed out at stage " + root.stage)
                stop(); Qt.quit(); return
            }
            switch (root.stage) {
            case 0:
                root.beginPair("paired")
                NotificationDispatchService.completeBatch("paired", "twitch", root.payload("twitch", "twitch-batched"))
                root.stage++; root.ticks = 0; break
            case 1:
                if (root.ticks < 4) return
                root.check(root.events.length === 0 && NotificationDispatchService.pendingNotificationCount === 1,
                    "completed producer waits for its batch peer")
                NotificationDispatchService.completeBatch("paired", "updates", root.payload("updates", "updates-batched"))
                root.stage++; root.ticks = 0; break
            case 2:
                if (root.events.length < 1 || NotificationDispatchService.activeCount) return
                root.check(root.events[0].cohort === "paired" && root.events[0].count === 2,
                    "paired notifications flush as one burst")
                root.beginPair("timeout")
                NotificationDispatchService.completeBatch("timeout", "twitch", root.payload("twitch", "timeout-release"))
                root.stage++; root.ticks = 0; break
            case 3:
                if (root.events.length < 2 || NotificationDispatchService.activeCount) return
                root.check(root.events[1].cohort === "timeout" && root.events[1].count === 1,
                    "hard deadline releases a completed producer when its peer stalls")
                root.beginPair("empty")
                NotificationDispatchService.completeBatch("empty", "twitch", root.payload("twitch", "peer-empty"))
                NotificationDispatchService.completeBatch("empty", "updates", null)
                root.stage++; root.ticks = 0; break
            case 4:
                if (root.events.length < 3 || NotificationDispatchService.activeCount) return
                root.check(root.events[2].cohort === "empty" && root.events[2].count === 1,
                    "a producer with no changes still completes its batch")
                root.check(NotificationDispatchService.send(root.payload("direct", "direct-send")),
                    "unbatched notifications dispatch immediately")
                root.stage++; root.ticks = 0; break
            case 5:
                if (root.events.length < 4 || NotificationDispatchService.activeCount) return
                root.check(root.events[3].cohort === "" && root.events[3].count === 1
                    && NotificationDispatchService.pendingBatchCount === 0,
                    "direct dispatch leaves no pending batches")
                console.log(root.failed ? "DISPATCH FAIL: notification batching"
                    : "PASS: notification batches rendezvous, burst together, time out safely and accept empty peers")
                stop(); Qt.quit(); break
            }
        }
    }
}
