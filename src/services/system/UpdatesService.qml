pragma Singleton

import "../../i18n"
import QtQml
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

// reload with: qs ipc call updates reload
// schedule: qs ipc call updates schedule

Singleton {
    id: root
    readonly property bool enabled: Config.updatesEnabled

    readonly property var updates: _internal.updates
    readonly property var priorityUpdates: _internal.priorityUpdates
    readonly property var normalUpdates: _internal.normalUpdates
    readonly property int count: _internal.count
    readonly property bool hasUpdates: _internal.hasUpdates
    readonly property bool hasPriority: _internal.hasPriority
    readonly property date lastChecked: _internal.lastChecked
    readonly property string error: _internal.error
    readonly property bool checking: refreshScriptProcess.running

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
        property var pendingNotificationUpdates: null
        property var notificationQueue: []
    }

    readonly property string notificationSnapshotKey: "updates.notificationSnapshot"

    function install() {
        if (!enabled) return
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
        if (!enabled || update.repository === "unknown") return
        BrowserRoutingService.open(packageUrl(update))
    }

    function markdownRow(update) {
        return `- [${update.name}](${packageUrl(update)}): ${update.oldVersion} -> ${update.newVersion}`
    }

    function openMarkdown() {
        if (!enabled) return
        openMarkdownProcess.running = true
    }

    function writeMarkdown() {
        if (!enabled) return
        const priority = root.priorityUpdates.map(root.markdownRow).join("\n")
        const normal = root.normalUpdates.map(root.markdownRow).join("\n")
        const markdown = `# ${Translations.text("updates.report.title")}\n\n## ${Translations.text("updates.report.priority")}\n\n${priority || Translations.text("updates.empty.priority")}\n\n## ${Translations.text("updates.report.other")}\n\n${normal || Translations.text("updates.empty.other")}\n`
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
        if (!enabled || updatesProcess.running) return
        updatesProcess.discardResult = false
        updatesProcess.running = true
    }

    function checkNow() {
        if (!enabled) return
        scheduleTimer.stop()
        startRefresh()
    }

    function schedule() {
        if (!enabled) return
        scheduleTimer.restart()
    }

    function startRefresh() {
        if (!enabled || checking) return
        refreshScriptProcess.discardResult = false
        refreshScriptProcess.running = true
    }

    onEnabledChanged: {
        if (enabled) {
            refresh()
            refreshIfOnline()
        } else {
            scheduleTimer.stop()
            for (const process of [updatesProcess, refreshScriptProcess]) {
                process.discardResult = true
                if (process.running) process.signal(15)
            }
            _internal.pendingNotificationUpdates = null
            _internal.notificationQueue = []
            if (updateNotificationProcess.running) updateNotificationProcess.signal(15)
            if (markdownProcess.running) markdownProcess.signal(15)
            _internal.error = ""
        }
    }

    function isPriority(line) {
        return Config.updatesPriorityPatterns.some(p => new RegExp(p).test(line))
    }

    function sortUpdates(updates) {
        return [...updates].sort((left, right) => left.name.localeCompare(right.name))
    }

    function notificationIdentity(update) {
        return [update.repository, update.architecture, update.name, update.newVersion].join("\u0000")
    }

    function updateNotificationSnapshot(updates) {
        if (!PreferencesRepository.ready) {
            _internal.pendingNotificationUpdates = updates
            return
        }
        _internal.pendingNotificationUpdates = null
        const previous = PreferencesRepository.value(notificationSnapshotKey, null)
        const identities = updates.map(update => root.notificationIdentity(update))
        if (!PreferencesRepository.setValue(notificationSnapshotKey, identities)) return
        if (!Array.isArray(previous)) return
        const known = new Set(previous)
        const added = updates.filter(update => !known.has(root.notificationIdentity(update)))
        if (!added.length) return
        _internal.notificationQueue.push({
            summary: Translations.text("updates.notifications.new", [], added.length),
            body: added.map(update => `${update.name}: ${update.oldVersion} -> ${update.newVersion}`).join("\n")
        })
        processNotificationQueue()
    }

    function processNotificationQueue() {
        if (!enabled || updateNotificationProcess.running || !_internal.notificationQueue.length) return
        const notification = _internal.notificationQueue.shift()
        updateNotificationProcess.command = ["notify-send", "--app-name=Updates", "--urgency=normal", "--expire-time=10000",
            "--icon=system-software-update", "--", notification.summary, notification.body]
        updateNotificationProcess.running = true
    }

    Process {
        id: updatesProcess
        property bool discardResult: false
        command: Config.updatesCheckCommand
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (!root.enabled || updatesProcess.discardResult) {
                if (root.enabled) Qt.callLater(root.refresh)
                return
            }
            if (exitCode !== 0 || exitStatus !== 0) {
                _internal.error = Translations.text("updates.errors.read")
                return
            }
            const priority = []
            const normal = []
            for (const line of updatesOutput.text.split("\n").filter(line => line.trim())) {
                const parts = line.trim().split(/\s+/)
                if (parts.length !== 5) {
                    _internal.error = Translations.text("updates.errors.invalidResponse")
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
            root.updateNotificationSnapshot(_internal.updates)
        }
        // qmllint enable signal-handler-parameters
        stdout: StdioCollector { id: updatesOutput; waitForEnd: true }
    }
    Process {
        id: refreshScriptProcess
        property bool discardResult: false
        command: Config.updatesRefreshCommand
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (!root.enabled || refreshScriptProcess.discardResult) {
                if (root.enabled) Qt.callLater(root.refreshIfOnline)
                return
            }
            if (exitCode !== 0 || exitStatus !== 0) {
                _internal.error = Translations.text("updates.errors.refresh")
                return
            }
            root.refresh()
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: updateNotificationProcess
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: Qt.callLater(root.processNotificationQueue)
        // qmllint enable signal-handler-parameters
    }

    Connections {
        target: PreferencesRepository
        function onReadyChanged() {
            if (PreferencesRepository.ready && _internal.pendingNotificationUpdates !== null)
                root.updateNotificationSnapshot(_internal.pendingNotificationUpdates)
        }
    }

    function refreshIfOnline() {
        if (enabled && NetworkService.online) startRefresh()
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
        function schedule(): void { root.schedule() }
    }

    Component.onCompleted: {
        refresh()
        refreshIfOnline()
    }
}
