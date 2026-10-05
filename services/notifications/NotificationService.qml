pragma ComponentBehavior: Bound

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

Singleton {
    id: root
    readonly property bool dndEnabled: state.dnd
    readonly property var popups: state.popups
    readonly property var liveEntries: state.liveEntries
    readonly property var imageJobs: state.imageJobs
    readonly property string error: NotificationRepository.error
    property string focusMessage: ""

    QtObject {
        id: state
        property bool dnd: false
        property var liveEntries: ({})
        property var popups: []
        property var imageJobs: []
    }

    function initialize() {
        NotificationEmitterRepository.reload()
        state.dnd = PreferencesRepository.value("notifications.dnd", false) === true
        // PID scopes protocol IDs across reloads; new processes never restore callbacks.
        DbService.write(tx => tx.executeSql("DELETE FROM notification_live WHERE live_token NOT LIKE ?", [Quickshell.processId + "/%"] ))
    }
    function check() {
        PreferencesRepository.reload()
        state.dnd = PreferencesRepository.value("notifications.dnd", false) === true
        NotificationEmitterRepository.reload()
        NotificationRepository.revision++
        applyPolicy()
    }
    function toggle() {
        if (PreferencesRepository.setValue("notifications.dnd", !state.dnd)) {
            state.dnd = !state.dnd
            applyPolicy()
        }
    }
    function token(id) { return Quickshell.processId + "/" + id }
    function uuid() { return Date.now().toString(36) + "-" + Math.random().toString(36).slice(2) + "-" + Math.random().toString(36).slice(2) }
    function timeout(notification) {
        // 0.3.1 exposes the original D-Bus timeout in milliseconds.
        if (notification.expireTimeout >= 0) return notification.expireTimeout
        return notification.urgency === 0 ? Config.notificationLowTimeout
            : notification.urgency === 2 ? Config.notificationCriticalTimeout : Config.notificationNormalTimeout
    }
    function popupAllowed(emitter) { return !emitter.muted && (!state.dnd || emitter.allowDuringDnd) }
    function historyAllowed(notification, emitter) { return !notification.transient && !emitter.excludeFromHistory }
    function snapshot(notification, emitter, previous) {
        const now = Date.now()
        return {recordId: previous?.recordId || uuid(), archiveId: previous?.archiveId || "",
            liveId: notification.id, emitterKey: emitter.key, summary: notification.summary,
            body: notification.body, urgency: notification.urgency, image: notification.image || "",
            actions: Array.from(notification.actions ?? []).map(action => ({identifier: action.identifier, text: action.text})),
            actionHandler: emitter.key === "app:twitch" ? "twitch" : "",
            receivedAt: previous?.receivedAt || now, updatedAt: now}
    }
    function receive(notification, carried) {
        const emitter = NotificationEmitterRepository.ensure(notification.desktopEntry, notification.appName, notification.appIcon)
        const savedLive = carried ? NotificationRepository.live(token(notification.id)) : null
        const saved = savedLive?.archive_id ? NotificationRepository.entry(savedLive.archive_id) : null
        const entry = snapshot(notification, emitter, saved ? Object.assign({recordId: saved.archiveId}, saved) : null)
        const duration = savedLive ? savedLive.duration : timeout(notification)
        const deadline = savedLive ? savedLive.deadline : duration > 0 ? Date.now() + duration : 0
        entry.duration = duration
        entry.deadline = deadline
        entry.notification = notification
        entry.popupVisible = carried ? !!savedLive?.popup_visible && (!deadline || deadline > Date.now()) && popupAllowed(emitter) : popupAllowed(emitter)
        if (!carried && historyAllowed(notification, emitter)) {
            entry.archiveId = uuid()
            saveHistory(entry)
        } else if (carried && saved) {
            entry.updatedAt = saved.updatedAt
            if (!saved.image && entry.image && !emitter.excludeFromHistory) queueImage(entry)
        }
        state.liveEntries = Object.assign({}, state.liveEntries, {[notification.id]: entry})
        NotificationRepository.saveLive(token(notification.id), entry)
        refreshPopups()
    }
    function saveHistory(entry) {
        const stored = Object.assign({}, entry, {image: entry.image.startsWith("data:image/") ? entry.image : ""})
        if (!NotificationRepository.save(stored)) return
        if (entry.image && !entry.image.startsWith("data:image/"))
            queueImage(entry)
    }
    function queueImage(entry) {
        const lock = imageLock.createObject(root, {object: entry.notification, locked: true})
        state.imageJobs = state.imageJobs.concat([{id: entry.archiveId, updatedAt: entry.updatedAt, source: entry.image, lock}])
    }
    Component { id: imageLock; RetainableLock {} }
    function updateLive(id) {
        const previous = state.liveEntries[id]
        if (!previous?.notification) return
        const notification = previous.notification
        const emitter = NotificationEmitterRepository.ensure(notification.desktopEntry, notification.appName, notification.appIcon)
        const entry = snapshot(notification, emitter, previous)
        entry.notification = notification
        entry.duration = timeout(notification)
        entry.deadline = entry.duration > 0 ? Date.now() + entry.duration : 0
        entry.popupVisible = popupAllowed(emitter)
        if (historyAllowed(notification, emitter)) {
            entry.archiveId = previous.archiveId || uuid()
            saveHistory(entry)
        } else entry.archiveId = ""
        state.liveEntries = Object.assign({}, state.liveEntries, {[id]: entry})
        NotificationRepository.saveLive(token(id), entry)
        refreshPopups()
    }
    function refreshPopups() {
        state.popups = Object.values(state.liveEntries).filter(entry => entry.popupVisible)
            .sort((a, b) => b.updatedAt - a.updatedAt || b.liveId - a.liveId)
    }
    function closed(id) {
        const next = Object.assign({}, state.liveEntries)
        delete next[id]
        state.liveEntries = next
        NotificationRepository.removeLive(token(id))
        refreshPopups()
    }
    function applyPolicy() {
        const next = Object.assign({}, state.liveEntries)
        for (const entry of Object.values(next)) {
            const emitter = NotificationEmitterRepository.emitters[entry.emitterKey]
            if (entry.popupVisible && emitter && !popupAllowed(emitter)) {
                next[entry.liveId] = Object.assign({}, entry, {popupVisible: false})
                NotificationRepository.saveLive(token(entry.liveId), next[entry.liveId])
            }
        }
        state.liveEntries = next
        refreshPopups()
    }
    function setEmitterPreference(key, preference, value) {
        if (!NotificationEmitterRepository.setPreference(key, preference, value)) return false
        applyPolicy()
        return true
    }
    function liveFor(entry) {
        return entry.liveId !== undefined ? state.liveEntries[entry.liveId] ?? null
            : Object.values(state.liveEntries).find(item => item.archiveId === entry.archiveId) ?? null
    }
    function hasSavedAction(entry, identifier) {
        return entry.emitterKey === "app:twitch" && entry.actionHandler === "twitch"
            && (identifier === "default" || identifier === "open-twitch")
            && (entry.actions ?? []).some(action => action.identifier === identifier)
    }
    function actions(entry, includeSaved) {
        const live = liveFor(entry)
        const current = live?.notification ? Array.from(live.notification.actions) : includeSaved ? entry.actions ?? [] : []
        const named = current.filter(action => action.identifier !== "default")
        const displayed = includeSaved ? current.filter(action => action.identifier !== "default"
            || !named.some(other => other.text === action.text)) : named
        return displayed.map(action => ({
            identifier: action.identifier, text: action.text,
            available: !!live?.notification || hasSavedAction(entry, action.identifier)
        }))
    }
    function invoke(entry, identifier) {
        const action = Array.from(liveFor(entry)?.notification?.actions ?? []).find(item => item.identifier === identifier)
        if (action) {
            action.invoke()
            return true
        }
        if (hasSavedAction(entry, identifier)) return Qt.openUrlExternally(Config.twitchBaseUrl)
        return false
    }
    function activate(entry) {
        if (invoke(entry, "default")) return
        const emitter = NotificationEmitterRepository.emitters[entry.emitterKey]
        focusMessage = ""
        if (!WindowService.focusEmitter(emitter?.desktopEntry || "", emitter?.name || ""))
            focusMessage = "No matching application window is available."
    }
    function dismiss(entry, fromHistory) {
        if (fromHistory && entry.archiveId && !NotificationRepository.remove(entry.archiveId)) return
        liveFor(entry)?.notification?.dismiss()
    }
    function clearEmitter(key) {
        if (!NotificationRepository.clearEmitter(key)) return
        for (const entry of Object.values(state.liveEntries)) if (entry.emitterKey === key) entry.notification.dismiss()
    }
    function deleteEmitter(key) {
        const entries = Object.values(state.liveEntries).filter(entry => entry.emitterKey === key)
        if (!NotificationEmitterRepository.remove(key, entries.map(entry => token(entry.liveId)))) return false
        NotificationRepository.revision++
        for (const entry of entries) entry.notification.dismiss()
        return true
    }
    function clearAll() {
        if (!NotificationRepository.clearAll()) return
        for (const entry of Object.values(state.liveEntries)) entry.notification.dismiss()
    }
    function finishImage(job, dataUrl) {
        if (dataUrl) NotificationRepository.saveImage(job.id, job.updatedAt, dataUrl)
        state.imageJobs = state.imageJobs.filter(item => item !== job)
        job?.lock?.destroy()
    }
    NativeNotificationServer { service: root }
    Timer {
        interval: 100
        repeat: true
        running: Object.keys(state.liveEntries).length > 0
        onTriggered: {
            const now = Date.now()
            for (const entry of Object.values(state.liveEntries))
                if (entry.deadline > 0 && entry.deadline <= now) entry.notification.expire()
        }
    }
    IpcHandler {
        target: "notifications"
        function reload(): void { root.check() }
        function toggle(): void { root.toggle() }
    }
    Component.onCompleted: initialize()
}
