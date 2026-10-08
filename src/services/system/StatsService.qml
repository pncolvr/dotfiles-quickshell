pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "../../config"

Singleton {
    id: root
    property bool active: false
    property string processResource: ""
    property real cpu: 0
    property var cores: []
    property real temperature: NaN
    property real memoryTotal: 0
    property real memoryUsed: 0
    property real memoryFree: 0
    property real memoryCache: 0
    property real memoryAvailable: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property real swapFree: 0
    property var processes: []
    property string processError: ""
    readonly property bool processesLoading: processSample.running
    property var previousCpu: ({})
    property var previousProcesses: ({})
    property real previousProcessTime: 0

    function applyCpu(text) {
        const next = {}
        const values = []
        for (const line of text.trim().split("\n")) {
            const fields = line.trim().split(/\s+/)
            if (!/^cpu\d*$/.test(fields[0])) continue
            const numbers = fields.slice(1, 9).map(Number)
            if (numbers.length < 8 || !numbers.every(Number.isFinite)) continue
            const total = numbers.reduce((sum, value) => sum + value, 0)
            const idle = numbers[3] + numbers[4]
            const previous = previousCpu[fields[0]]
            const delta = previous ? total - previous.total : 0
            const usage = delta > 0 ? Math.max(0, Math.min(100, Math.round((delta - idle + previous.idle) / delta * 100))) : 0
            next[fields[0]] = {total, idle}
            if (fields[0] === "cpu") cpu = usage
            else values[Number(fields[0].slice(3))] = usage
        }
        previousCpu = next
        cores = values
    }
    function applyMemory(text) {
        const values = {}
        for (const line of text.trim().split("\n")) {
            const fields = line.trim().split(/\s+/)
            values[fields[0].replace(":", "")] = Number(fields[1]) / 1024
        }
        if (!Number.isFinite(values.MemTotal)) return
        memoryTotal = values.MemTotal
        memoryFree = values.MemFree || 0
        memoryCache = Math.max(0, (values.Cached || 0) + (values.SReclaimable || 0) - (values.Shmem || 0))
        memoryAvailable = values.MemAvailable ?? memoryFree + memoryCache + (values.Buffers || 0)
        memoryUsed = Math.max(0, memoryTotal - memoryAvailable)
        swapTotal = values.SwapTotal || 0
        swapFree = values.SwapFree || 0
        swapUsed = Math.max(0, swapTotal - swapFree)
    }
    function applyProcesses(report) {
        if (!Array.isArray(report?.processes) || !Number.isFinite(report.timestamp) || !Number.isFinite(report.clockTicks) || report.clockTicks <= 0) return false
        const next = {}
        const elapsed = report.timestamp - previousProcessTime
        const groups = new Map()
        for (const row of report.processes) {
            const previous = previousProcesses[row.pid]
            const cpuUsage = previous && previous.start === row.start && elapsed > 0
                ? Math.max(0, (row.ticks - previous.ticks) / report.clockTicks / elapsed * 100) : 0
            next[row.pid] = {start: row.start, ticks: row.ticks}
            const name = row.appName || row.name
            const key = name.toLowerCase()
            const pid = row.appPid ?? row.pid
            const value = processResource === "cpu" ? cpuUsage : processResource === "memory" ? row.memory : row.down + row.up
            if (!groups.has(key)) groups.set(key, {pid, name, value: 0, down: 0, up: 0, count: 0, searchName: name, members: []})
            const group = groups.get(key)
            group.value += value
            group.down += row.down || 0
            group.up += row.up || 0
            group.count++
            group.members.push({pid: row.pid, name: row.name, label: row.role || (row.pid === pid ? "Main process" : row.name), value, down: row.down || 0, up: row.up || 0})
            group.searchName += " " + row.name + " " + (row.role || "")
            if (pid > 0 && (group.pid <= 0 || pid < group.pid)) group.pid = pid
        }
        const rows = Array.from(groups.values())
        if (processResource === "cpu") { previousProcesses = next; previousProcessTime = report.timestamp }
        const compare = (left, right) => right.value - left.value || left.name.localeCompare(right.name) || left.pid - right.pid
        for (const group of rows) group.members.sort(compare)
        rows.sort(compare)
        processes = rows
        processError = ""
        return true
    }
    function sampleProcesses() {
        if (!active || !processResource || processSample.running) return
        processSample.command = Config.statsProcessesCommand(processResource)
        processSample.resource = processResource
        processSample.running = true
    }
    function copyPid(pid) {
        if (!Number.isInteger(pid) || pid <= 0) return
        Quickshell.execDetached(["wl-copy", "--", String(pid)])
    }
    onProcessResourceChanged: {
        processSample.running = false
        processes = []
        processError = ""
        previousProcesses = ({})
        previousProcessTime = 0
        if (active && processResource) Qt.callLater(root.sampleProcesses)
    }
    onActiveChanged: {
        if (!active) processSample.running = false
        else { previousCpu = ({}); Qt.callLater(root.sampleProcesses) }
    }
    Timer {
        interval: Config.statsInterval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: { cpuFile.reload(); memoryFile.reload(); temperatureFile.reload() }
    }
    FileView {
        id: cpuFile
        path: Config.statsProcRoot + "/stat"
        preload: root.active
        printErrors: false
        onLoaded: if (root.active) root.applyCpu(text())
    }
    FileView {
        id: memoryFile
        path: Config.statsProcRoot + "/meminfo"
        preload: root.active
        printErrors: false
        onLoaded: if (root.active) root.applyMemory(text())
    }
    FileView {
        id: temperatureFile
        path: Config.statsTemperaturePath
        preload: root.active
        printErrors: false
        onLoaded: if (root.active) root.temperature = Number(text().trim()) / 1000
        onLoadFailed: root.temperature = NaN
    }
    Timer {
        interval: root.processResource === "network" ? Config.networkProcessesInterval : Config.statsInterval
        running: root.active && root.processResource.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sampleProcesses()
    }
    Process {
        id: processSample
        property string resource: ""
        stdout: StdioCollector { id: processOutput; waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (!root.active || resource !== root.processResource) return
            let report
            try { report = JSON.parse(processOutput.text) } catch (_) { report = null }
            if (exitCode !== 0 || exitStatus !== 0 || !root.applyProcesses(report))
                root.processError = report?.error || "Could not read process usage."
        }
        // qmllint enable signal-handler-parameters
    }
}
