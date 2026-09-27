pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

// reload with: qs ipc call updates reload

Singleton {
    id: root

    readonly property var updates: _internal.updates
    readonly property var priorityUpdates: _internal.priorityUpdates
    readonly property var normalUpdates: _internal.normalUpdates
    readonly property int count: _internal.count
    readonly property bool hasUpdates: _internal.hasUpdates
    readonly property bool hasPriority: _internal.hasPriority
    readonly property date lastChecked: _internal.lastChecked

    QtObject {
        id: _internal
        property var updates: []
        property var priorityUpdates: []
        property var normalUpdates: []
        property int count: updates.length
        property bool hasUpdates: count > 0
        property bool hasPriority: priorityUpdates.length > 0
        property date lastChecked: new Date(0)
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
        const priority = root.priorityUpdates.map(root.markdownRow).join("\n")
        const normal = root.normalUpdates.map(root.markdownRow).join("\n")
        const markdown = `# Available Updates\n\n## Priority Updates\n\n${priority || "No priority updates."}\n\n## Other Updates\n\n${normal || "No other updates."}\n`
        markdownProcess.command = ["bash", "-c", "printf '%s' \"$1\" | base64 -d > \"$2\" && xdg-open \"$2\"", "updates-markdown", Qt.btoa(markdown), Config.updatesMarkdownFile]
        markdownProcess.running = true
    }

    Process {
        id: installProcess
    }

    Process {
        id: markdownProcess
    }

    function refresh() {
        if (updatesProcess.running) return;
        
        _internal.updates = []
        _internal.priorityUpdates = []
        _internal.normalUpdates = []
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
        onExited: exitCode => {
            if (exitCode === 0) _internal.lastChecked = new Date()
        }
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (!line) return
                const parts = line.split(/\s+/)
                const update = {
                    repository: parts[0],
                    architecture: parts[1],
                    name: parts[2],
                    oldVersion: parts[3],
                    newVersion: parts[4]
                }
                if (root.isPriority(update.name)) {
                    _internal.priorityUpdates = root.sortUpdates([..._internal.priorityUpdates, update])
                } else {
                    _internal.normalUpdates = root.sortUpdates([..._internal.normalUpdates, update])
                }
                _internal.updates = [..._internal.priorityUpdates, ...root.normalUpdates]
            }
        }
    }
    Process {
        id: refreshScriptProcess
        command: Config.updatesRefreshCommand
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

    IpcHandler {
        target: "updates"
        function reload(): void { root.refresh() }
    }

    Component.onCompleted: {
        refresh()
        refreshIfOnline()
    }
}