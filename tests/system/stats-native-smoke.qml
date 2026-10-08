import QtQuick
import Quickshell
import "../../src/services"

Scope {
    id: root
    property int step: 0
    property bool failed: false
    function check(ok, message) { if (!ok) { failed = true; console.error("STATS FAIL:", message) } }
    Component.onCompleted: {
        StatsService.processResource = "cpu"
        StatsService.active = true
        NetworkService.active = true
    }
    Timer {
        interval: 1800; repeat: true; running: true
        onTriggered: {
            if (root.step === 0) {
                root.check(StatsService.memoryTotal > 0 && StatsService.cores.length > 0, "FileView loads live proc data")
                root.check(StatsService.processes.length > 0 && StatsService.processError === "", "Bash collector loads through Quickshell Process")
                root.check(StatsService.processes.every((row, index, rows) => Number.isFinite(row.value) && (index === 0 || rows[index - 1].value >= row.value)), "live CPU processes are sorted")
                StatsService.processResource = "memory"
            } else {
                root.check(StatsService.processes.some(row => row.value > 0) && StatsService.processError === "", "switching resources samples live RSS")
                root.check(StatsService.processes.every((row, index, rows) => index === 0 || rows[index - 1].value >= row.value), "live memory processes are sorted")
                StatsService.active = false
                StatsService.processResource = ""
                NetworkService.active = false
                root.check(!StatsService.processesLoading, "closing stops the process collector")
                console.log(root.failed ? "STATS FAIL: live collectors" : "PASS: native FileView readings, Bash Process integration, live resource sorting and shutdown")
                Qt.quit()
            }
            root.step++
        }
    }
}
