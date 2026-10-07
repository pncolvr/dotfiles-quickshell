pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

Singleton {
    id: root

    readonly property bool active: TooltipService.visible && TooltipService.source?.totpModule === true
    readonly property bool ready: state.ready
    readonly property bool busy: state.busy
    readonly property string error: state.error
    readonly property int secondsRemaining: Math.max(0, Math.ceil(state.expiresAt - state.now))
    readonly property real countdownProgress: ready
        ? Math.max(0, Math.min(1, (state.expiresAt - state.now) / state.period)) : 0
    readonly property string copiedId: state.copiedId
    readonly property alias entries: entriesModel

    signal editorLoaded(string entryId, string name, string token)
    signal saved(string entryId)
    signal editFailed()

    QtObject {
        id: state
        property bool ready: false
        property bool busy: false
        property bool stopping: false
        property string error: ""
        property string copiedId: ""
        property real now: Date.now() / 1000
        property real timestamp: 0
        property real expiresAt: 0
        property int period: Config.totpDefaultPeriod
    }

    ListModel { id: entriesModel }

    onActiveChanged: {
        if (active) {
            if (!worker.running) start()
        } else {
            // Let an in-flight keyring write finish, then discard the worker's secrets.
            if (worker.running && !state.stopping) {
                state.stopping = true
                worker.write(JSON.stringify({action: "quit"}) + "\n")
            }
            entriesModel.clear()
            state.ready = false
            state.copiedId = ""
            copiedTimer.stop()
        }
    }

    function start() {
        state.stopping = false
        state.ready = false
        state.busy = true
        state.error = ""
        state.now = Date.now() / 1000
        worker.running = true
    }

    function request(message) {
        if (!active || state.busy || state.stopping || !worker.running) return false
        state.busy = true
        state.error = ""
        worker.write(JSON.stringify(message) + "\n")
        return true
    }

    function reload() {
        if (!worker.running) start()
        else request({action: "load"})
    }

    function edit(entryId) { return request({action: "edit", id: entryId}) }
    function save(entryId, name, token) { return request({action: "save", id: entryId, name, token}) }
    function remove(entryId) { return request({action: "delete", id: entryId}) }
    function copy(entryId) { return request({action: "copy", id: entryId}) }

    function updateEntries(rows) {
        rows.sort((a, b) => a.name.localeCompare(b.name))
        const ids = rows.map(row => row.id)
        for (let i = entriesModel.count - 1; i >= 0; --i) {
            if (ids.indexOf(entriesModel.get(i).entryId) === -1) entriesModel.remove(i)
        }
        for (let i = 0; i < rows.length; ++i) {
            const row = rows[i]
            let oldIndex = -1
            for (let j = i; j < entriesModel.count; ++j) {
                if (entriesModel.get(j).entryId === row.id) { oldIndex = j; break }
            }
            const item = {entryId: row.id, name: row.name, code: row.code, expiresAt: row.expiresAt}
            if (oldIndex === -1) entriesModel.insert(i, item)
            else {
                if (oldIndex !== i) entriesModel.move(oldIndex, i, 1)
                entriesModel.set(i, item)
            }
        }
    }

    function receive(data) {
        let message
        try { message = JSON.parse(data) }
        catch (_error) {
            state.busy = false
            state.error = "Invalid response from the TOTP helper. Reload and retry."
            return
        }
        state.busy = false
        if (!active || state.stopping) return
        if (message.type === "snapshot") {
            updateEntries(message.entries)
            state.timestamp = message.timestamp
            state.expiresAt = message.expiresAt
            state.period = message.period ?? Config.totpDefaultPeriod
            state.now = Date.now() / 1000
            state.ready = true
            if (message.action === "save") root.saved(message.id)
        } else if (message.type === "edit") {
            root.editorLoaded(message.id, message.name, message.token)
        } else if (message.type === "copy") {
            ClipboardService.ignoreTextOnce(message.code)
            Quickshell.clipboardText = message.code
            state.copiedId = message.id
            copiedTimer.restart()
        } else if (message.type === "error") {
            state.error = message.message
            if (message.action === "load") state.ready = false
            if (message.action === "edit") root.editFailed()
        }
    }

    // Keep the visible countdown synchronized with rendered frames.
    FrameAnimation {
        running: root.active && root.ready && entriesModel.count > 0
        onTriggered: state.now = Date.now() / 1000
    }

    Timer {
        interval: Config.totpTickInterval
        running: root.active && root.ready && entriesModel.count > 0
        repeat: true
        onTriggered: {
            const now = Date.now() / 1000
            // Wall-clock comparisons handle suspend/resume and clock corrections.
            if (!root.busy && !root.error && (now >= state.expiresAt || now < state.timestamp))
                root.request({action: "refresh"})
        }
    }

    Timer {
        id: copiedTimer
        interval: Config.totpCopiedDuration
        onTriggered: state.copiedId = ""
    }

    Process {
        id: worker
        command: Config.totpCommand
        stdinEnabled: true
        onStarted: write(JSON.stringify({action: "load"}) + "\n")
        stdout: SplitParser { onRead: data => root.receive(data) }
        // Do not forward helper stderr: it must never become a secret-bearing shell log.
        stderr: SplitParser { onRead: _data => {} }
        onRunningChanged: {
            if (!running) {
                state.busy = false
                state.ready = false
                if (root.active && state.stopping) Qt.callLater(root.start)
                else if (root.active) state.error = "The TOTP helper is unavailable. Check the configured commands and reload."
            }
        }
    }
}
