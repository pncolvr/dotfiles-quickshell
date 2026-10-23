import QtQuick
import "../../src/services"

WorkerScope {
    id: root
    property bool failed: false
    property int stage: 0
    property real lastChecked: 0
    property string lastSnapshot: ""
    property int tries: 0
    function check(condition, message) {
        if (!condition) { failed = true; console.error("SERVICES FAIL: " + message) }
    }
    // Force singleton creation so its startup refresh runs.
    readonly property int count: UpdatesService.count
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            root.tries++
            if (root.tries > 40) { console.error("SERVICES FAIL: update refresh timed out"); Qt.quit(); return }
            if (root.stage === 0) {
                if (UpdatesService.count !== 2 || PreferencesRepository.value("updates.notificationSnapshot", null) === null) return
                root.check(UpdatesService.priorityUpdates[0].name === "linux" && UpdatesService.normalUpdates[0].name === "example", "initial update groups")
                root.lastChecked = UpdatesService.lastChecked.getTime()
                root.lastSnapshot = JSON.stringify(UpdatesService.updates)
            } else if (root.stage <= 2) {
                if (!UpdatesService.error) return
                root.check(JSON.stringify(UpdatesService.updates) === root.lastSnapshot && UpdatesService.lastChecked.getTime() === root.lastChecked,
                    "failed or malformed refresh preserves the last successful snapshot")
            } else if (root.stage === 3) {
                if (UpdatesService.count !== 0 || UpdatesService.error) return
            } else {
                if (UpdatesService.count !== 1 || UpdatesService.updates[0].name !== "fresh" || UpdatesService.error) return
                console.log(root.failed ? "SERVICES FAIL: updates" : "PASS: update snapshots survive errors, accept empty success and notify only newly added updates")
                Qt.quit()
                return
            }
            root.stage++
            UpdatesService.refresh()
            root.check(UpdatesService.count === (root.stage === 4 ? 0 : 2), "refresh keeps current list visible while loading")
        }
    }
}
