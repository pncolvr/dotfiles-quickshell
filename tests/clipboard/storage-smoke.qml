import QtQuick
import Quickshell
import "../../src/services"

Scope {
    id: root
    property bool retried: false

    Component.onCompleted: ClipboardService.initialize()

    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            const phase = Quickshell.env("SERVICES_TEST_PHASE")
            if (phase === "prune-failure" && !root.retried) {
                if (ClipboardService.initialized || !ClipboardService.error || ClipboardService.monitoring) {
                    console.error("SERVICES FAIL: failed prune must stop initialization")
                    Qt.quit()
                    return
                }
                root.retried = true
                ClipboardService.initialize()
                return
            }
            const failedRead = phase === "database-failure"
            const valid = failedRead
                ? ClipboardRepository.readEntries() === null && !ClipboardService.initialized && !!ClipboardService.error
                : ClipboardRepository.readEntries() !== null && ClipboardService.initialized && !ClipboardService.error
            if (!valid || ClipboardService.initializing || ClipboardService.monitoring)
                console.error("SERVICES FAIL: clipboard initialization " + phase)
            else console.log("PASS: clipboard initialization " + phase)
            // A repeated call after success must not start another prune.
            ClipboardService.initialize()
            Qt.quit()
        }
    }
}
