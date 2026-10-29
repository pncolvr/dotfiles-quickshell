pragma ComponentBehavior: Bound
pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "../../config"

// Outgoing desktop-notification transport. Producers own notification content;
// this service owns batching and process lifetime.
Singleton {
    id: root

    readonly property int pendingBatchCount: Object.keys(state.batches).length
    readonly property int pendingNotificationCount: Object.values(state.batches)
        .reduce((count, batch) => count + batch.notifications.length, 0)
    readonly property int activeCount: state.activeCount
    signal dispatched(string cohort, int count)

    QtObject {
        id: state
        property var batches: ({})
        property int sequence: 0
        property int activeCount: 0
    }

    function normalize(notification) {
        if (!notification) return null
        const summary = String(notification.summary ?? "")
        const body = String(notification.body ?? "")
        if (!summary && !body) return null
        const requestedExpiry = Number(notification.expireTime)
        return {
            source: String(notification.source ?? notification.appName ?? "notification"),
            appName: String(notification.appName ?? "Quickshell"),
            icon: String(notification.icon ?? ""),
            urgency: String(notification.urgency ?? "normal"),
            expireTime: Number.isFinite(requestedExpiry) && requestedExpiry >= 0
                ? Math.round(requestedExpiry) : Config.notificationNormalTimeout,
            summary,
            body,
            sequence: ++state.sequence
        }
    }

    function setBatch(cohort, batch) {
        state.batches = Object.assign({}, state.batches, {[cohort]: batch})
    }

    function removeBatch(cohort) {
        const batches = Object.assign({}, state.batches)
        delete batches[cohort]
        state.batches = batches
    }

    function beginBatch(cohort, source) {
        cohort = String(cohort ?? "")
        source = String(source ?? "")
        if (!cohort || !source) return false
        const now = Date.now()
        const current = state.batches[cohort]
        const batch = current ?? {
            joinUntil: now + Config.notificationBatchJoinWindow,
            deadline: now + Config.notificationBatchMaxWait,
            participants: ({}),
            notifications: []
        }
        if (batch.participants[source] === false) return true
        // A producer can schedule one follow-up refresh while an earlier result
        // is waiting for peers. Reopen it so the batch cannot flush mid-refresh.
        const participants = Object.assign({}, batch.participants, {[source]: false})
        setBatch(cohort, Object.assign({}, batch, {participants}))
        scheduleFlush()
        return true
    }

    function completeBatch(cohort, source, notification = null) {
        cohort = String(cohort ?? "")
        source = String(source ?? "")
        const batch = state.batches[cohort]
        if (!batch || batch.participants[source] === undefined) {
            if (notification) send(notification)
            return false
        }
        const participants = Object.assign({}, batch.participants, {[source]: true})
        const normalized = normalize(notification)
        const notifications = normalized ? batch.notifications.concat([normalized]) : batch.notifications
        setBatch(cohort, Object.assign({}, batch, {participants, notifications}))
        flushReady()
        return true
    }

    function cancelSource(source) {
        source = String(source ?? "")
        if (!source) return
        for (const cohort of Object.keys(state.batches)) {
            const batch = state.batches[cohort]
            if (batch.participants[source] === undefined
                    && !batch.notifications.some(notification => notification.source === source)) continue
            const participants = Object.assign({}, batch.participants)
            delete participants[source]
            const notifications = batch.notifications.filter(notification => notification.source !== source)
            if (!Object.keys(participants).length) removeBatch(cohort)
            else setBatch(cohort, Object.assign({}, batch, {participants, notifications}))
        }
        flushReady()
    }

    function send(notification) {
        const normalized = normalize(notification)
        if (!normalized) return false
        dispatch("", [normalized])
        return true
    }

    function allComplete(batch) {
        const participants = Object.values(batch.participants)
        return participants.length > 0 && participants.every(completed => completed)
    }

    function flushReady() {
        flushTimer.stop()
        const now = Date.now()
        const ready = []
        for (const cohort of Object.keys(state.batches)) {
            const batch = state.batches[cohort]
            if (now >= batch.deadline || (now >= batch.joinUntil && allComplete(batch))) ready.push(cohort)
        }
        for (const cohort of ready) {
            const batch = state.batches[cohort]
            removeBatch(cohort)
            dispatch(cohort, batch.notifications)
        }
        scheduleFlush()
    }

    function scheduleFlush() {
        flushTimer.stop()
        const now = Date.now()
        let deadline = Infinity
        for (const batch of Object.values(state.batches)) {
            const candidate = allComplete(batch) ? Math.min(batch.joinUntil, batch.deadline) : batch.deadline
            deadline = Math.min(deadline, candidate)
        }
        if (!Number.isFinite(deadline)) return
        flushTimer.interval = Math.max(1, Math.ceil(deadline - now))
        flushTimer.start()
    }

    function command(notification) {
        const command = ["notify-send", `--app-name=${notification.appName}`,
            `--urgency=${notification.urgency}`, `--expire-time=${notification.expireTime}`]
        if (notification.icon) command.push("--icon", notification.icon)
        command.push("--", notification.summary, notification.body)
        return command
    }

    function dispatch(cohort, notifications) {
        const ordered = notifications.slice().sort((left, right) => left.sequence - right.sequence)
        for (const notification of ordered) {
            const process = senderComponent.createObject(root, {
                command: root.command(notification), notificationSource: notification.source
            }) as Process
            state.activeCount++
            process.running = true
        }
        if (ordered.length) dispatched(cohort, ordered.length)
    }

    Timer { id: flushTimer; repeat: false; onTriggered: root.flushReady() }

    Component {
        id: senderComponent
        Process {
            id: sender
            property string notificationSource: ""
            stderr: StdioCollector { waitForEnd: true }
            // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
            // qmllint disable signal-handler-parameters
            onExited: (exitCode, exitStatus) => {
                if (exitCode !== 0 || exitStatus !== 0)
                    console.warn("NotificationDispatchService failed:", notificationSource, exitCode)
                state.activeCount--
                sender.destroy()
            }
            // qmllint enable signal-handler-parameters
        }
    }

    IpcHandler {
        target: "notificationDispatch"
        function begin(cohort: string, source: string): void { root.beginBatch(cohort, source) }
        function complete(cohort: string, source: string): void { root.completeBatch(cohort, source) }
    }
}
