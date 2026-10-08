import QtQuick
import Quickshell
import "../../src/services"
Scope {
    id: root
    property bool failed: false
    function check(ok, message) { if (!ok) { failed = true; console.error("STATS FAIL:", message) } }
    Timer {
        interval: 1; running: true
        onTriggered: {
            StatsService.applyCpu("cpu 100 0 0 100 0 0 0 0\ncpu0 100 0 0 100 0 0 0 0")
            StatsService.applyCpu("cpu 150 0 0 150 0 0 0 0\ncpu0 150 0 0 150 0 0 0 0")
            root.check(StatsService.cpu === 50 && StatsService.cores[0] === 50, "native stat file deltas")
            StatsService.applyMemory("MemTotal: 8192 kB\nMemFree: 1024 kB\nMemAvailable: 3072 kB\nCached: 2048 kB\nSReclaimable: 1024 kB\nShmem: 512 kB\nSwapTotal: 4096 kB\nSwapFree: 1024 kB")
            root.check(StatsService.memoryUsed === 5 && StatsService.memoryCache === 2.5 && StatsService.swapUsed === 3, "native meminfo units and available memory")
            StatsService.processResource = "cpu"
            const report = {timestamp: 1, clockTicks: 100, processes: [{pid: 1, name: "small", ticks: 100, start: "1", memory: 2}, {pid: 2, name: "large", ticks: 100, start: "1", memory: 1}]}
            StatsService.applyProcesses(report)
            report.timestamp = 3; report.processes[0].ticks = 150; report.processes[1].ticks = 300
            StatsService.applyProcesses(report)
            root.check(StatsService.processes[0].pid === 2 && StatsService.processes[0].value === 100 && StatsService.processes[1].value === 25, "CPU uses elapsed time and sorts descending")
            report.timestamp = 4; report.processes[1].start = "2"; report.processes[1].ticks = 10000
            StatsService.applyProcesses(report)
            root.check(StatsService.processes.find(row => row.pid === 2).value === 0, "reused PID starts a new baseline")
            StatsService.processResource = "memory"
            StatsService.applyProcesses(report)
            root.check(StatsService.processes[0].pid === 1 && StatsService.processes[0].value === 2, "memory sorts by RSS")
            StatsService.processResource = "network"
            StatsService.applyProcesses({timestamp: 5, clockTicks: 100, processes: [{pid: 1, name: "a", down: 5, up: 10}, {pid: 2, name: "b", down: 20, up: 2}]})
            root.check(StatsService.processes[0].pid === 2 && StatsService.processes[0].value === 22, "network sorts combined traffic")
            // Different helper names and independent instances share one app total.
            StatsService.processResource = "cpu"
            const grouped = {timestamp: 10, clockTicks: 100, processes: [
                {pid: 10, name: "Discord", appPid: 10, appName: "Discord", ticks: 100, start: "1", memory: 100},
                {pid: 11, name: "renderer", role: "Renderer", appPid: 10, appName: "Discord", ticks: 100, start: "1", memory: 200},
                {pid: 20, name: "Discord", appPid: 20, appName: "Discord", ticks: 100, start: "1", memory: 300},
                {pid: 30, name: "QtWebEngineProc", appPid: 29, appName: "qutebrowser", ticks: 100, start: "1", memory: 400}]}
            StatsService.applyProcesses(grouped)
            grouped.timestamp = 11
            grouped.processes.forEach(row => { row.ticks += 100 })
            StatsService.applyProcesses(grouped)
            root.check(StatsService.processes.length === 2 && StatsService.processes[0].name === "Discord"
                && StatsService.processes[0].value === 300 && StatsService.processes[0].count === 3 && StatsService.processes[0].pid === 10,
                "CPU adds individual process deltas and keeps the app parent PID")
            root.check(StatsService.processes[0].members.length === 3 && StatsService.processes[0].members.reduce((sum, member) => sum + member.value, 0) === 300, "CPU group retains the individual process values")
            StatsService.processResource = "memory"
            StatsService.applyProcesses(grouped)
            root.check(StatsService.processes[0].value === 600 && StatsService.processes[0].searchName.includes("renderer"),
                "RSS adds across helper names and instances, retaining child names for filtering")
            root.check(StatsService.processes[0].members.find(member => member.pid === 11).label === "Renderer"
                && StatsService.processes[0].members.find(member => member.pid === 10).label === "Main process",
                "detected helper roles and main-process fallback survive grouping")
            root.check(StatsService.processes[0].members[0].pid === 20 && StatsService.processes[0].members[0].value === 300, "subprocesses are sorted by the selected resource")
            StatsService.processResource = "network"
            StatsService.applyProcesses({timestamp: 12, clockTicks: 100, processes: [
                {pid: 10, name: "Discord", appPid: 10, appName: "Discord", down: 4, up: 6},
                {pid: 11, name: "renderer", appPid: 10, appName: "Discord", down: 20, up: 30},
                {pid: 30, name: "QtWebEngineProc", appPid: 29, appName: "qutebrowser", down: 10, up: 10}]})
            root.check(StatsService.processes[0].value === 60 && StatsService.processes[0].down === 24
                && StatsService.processes[0].up === 36 && StatsService.processes[0].pid === 10, "network adds app traffic before sorting")
            StatsService.copyPid(2345)
            console.log(root.failed ? "STATS FAIL: collectors" : "PASS: Stats native file parsing, process deltas, PID reuse, resource sorting and clipboard command")
            Qt.quit()
        }
    }
}
