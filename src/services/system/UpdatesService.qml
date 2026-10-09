pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

// reload with: qs ipc call updates reload
// schedule: qs ipc call updates schedule

Singleton {
    id: root

    readonly property var updates: _internal.updates
    readonly property var priorityUpdates: _internal.priorityUpdates
    readonly property var normalUpdates: _internal.normalUpdates
    readonly property int count: _internal.count
    readonly property bool hasUpdates: _internal.hasUpdates
    readonly property bool hasPriority: _internal.hasPriority
    readonly property date lastChecked: _internal.lastChecked
    readonly property string error: _internal.error

    QtObject {
        id: _internal
        property var updates: []
        property var priorityUpdates: []
        property var normalUpdates: []
        property int count: updates.length
        property bool hasUpdates: count > 0
        property bool hasPriority: priorityUpdates.length > 0
        property date lastChecked: new Date(0)
        property string error: ""
    }

    function install() {
        installProcess.command = Config.updatesInstallCommand
        installProcess.running = true
    }

    function packageUrl(update) {
        if (update.repository === "aur") {
            return `https://aur.archlinux.org/packages/${update.name}`
        }
        if (update.repository.startsWith("endeavouros")) {
            return `https://packages.endeavouros.com/package/${update.repository}/${update.architecture}/${update.name}`
        }
        if (update.repository.startsWith("cachyos")) {
            return `https://packages.cachyos.org/package/${update.repository}/${update.architecture}/${update.name}`
        }
        return `https://archlinux.org/packages/${update.repository}/${update.architecture}/${update.name}`
    }

    function openPackage(update) {
        if (update.repository === "unknown") return
        Qt.openUrlExternally(packageUrl(update))
    }

    function markdownRow(update) {
        return `- [${update.name}](${packageUrl(update)}): ${update.oldVersion} -> ${update.newVersion}`
    }

    function openMarkdown() {
        openMarkdownProcess.running = true
    }

    function writeMarkdown() {
        const priority = root.priorityUpdates.map(root.markdownRow).join("\n")
        const normal = root.normalUpdates.map(root.markdownRow).join("\n")
        const markdown = `# Available Updates\n\n## Priority Updates\n\n${priority || "No priority updates."}\n\n## Other Updates\n\n${normal || "No other updates."}\n`
        markdownProcess.command = ["bash", "-c", "printf '%s' \"$1\" > \"$2\"", "updates-markdown", markdown, Config.updatesMarkdownFile]
        markdownProcess.running = true
    }

    Process {
        id: installProcess
    }

    Process {
        id: markdownProcess
    }

    Process {
        id: openMarkdownProcess
        command: ["xdg-open", Config.updatesMarkdownFile]
    }

    function refresh() {
        if (updatesProcess.running) return
        updatesProcess.running = true
    }

    function isPriority(line) {
        return Config.updatesPriorityPatterns.some(p => new RegExp(p).test(line))
    }

    function sortUpdates(updates) {
        return [...updates].sort((left, right) => left.name.localeCompare(right.name))
    }

    Process {
        id: updatesProcess
        command: Config.updatesCheckCommand
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0) {
                _internal.error = "Could not read available updates."
                return
            }
            const priority = []
            const normal = []
            for (const line of updatesOutput.text.split("\n").filter(line => line.trim())) {
                const parts = line.trim().split(/\s+/)
                if (parts.length !== 5) {
                    _internal.error = "Invalid response from the update checker."
                    return
                }
                const update = {repository: parts[0], architecture: parts[1], name: parts[2],
                    oldVersion: parts[3], newVersion: parts[4]}
                const target = root.isPriority(update.name) ? priority : normal
                target.push(update)
            }
            _internal.priorityUpdates = root.sortUpdates(priority)
            _internal.normalUpdates = root.sortUpdates(normal)
            _internal.updates = [..._internal.priorityUpdates, ..._internal.normalUpdates]
            _internal.lastChecked = new Date()
            _internal.error = ""
            root.writeMarkdown()
        }
        // qmllint enable signal-handler-parameters
        stdout: StdioCollector { id: updatesOutput; waitForEnd: true }
    }
    Process {
        id: refreshScriptProcess
        command: Config.updatesRefreshCommand
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0) {
                _internal.error = "Could not refresh available updates."
                return
            }
            root.refresh()
        }
        // qmllint enable signal-handler-parameters
    }

    function refreshIfOnline() {
        if (NetworkService.online) refreshScriptProcess.running = true
    }

    Connections {
        target: NetworkService
        function onOnlineChanged() {
            root.refreshIfOnline()
        }
    }

    Timer {
        id: scheduleTimer
        interval: Config.updatesScheduleDelay
        repeat: false
        onTriggered: root.refreshIfOnline()
    }

    IpcHandler {
        target: "updates"
        function reload(): void { root.refresh() }
        function schedule(): void { scheduleTimer.restart() }
    }

    Component.onCompleted: {
        refresh()
        refreshIfOnline()
    }
}
