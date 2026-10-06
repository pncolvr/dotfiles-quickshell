pragma Singleton

import QtQml
import QtQuick
import Quickshell
import "../../config"
import "../"

Singleton {
    id: root

    readonly property var users: state.users
    readonly property var schedules: state.schedules
    readonly property var avatars: state.avatars
    readonly property var notifiedStreams: state.notifiedStreams
    readonly property string error: state.error || DbService.error
    readonly property var removedUsers: state.removedUsers

    QtObject {
        id: state
        property var users: []
        property var schedules: ({})
        property var avatars: ({})
        property var notifiedStreams: ({})
        property string error: ""
        property var removedUsers: []
    }

    function normalizeLogin(login) { return String(login ?? "").trim().toLowerCase() }
    function validLogin(login) { return /^[a-z0-9_]{1,25}$/.test(login) }
    function logins() { return users.map(user => user.login) }

    function reload() {
        const userRows = DbService.read("SELECT login, added_at FROM twitch_users ORDER BY login")
        const scheduleRows = DbService.read("SELECT login, starts_at, fetched_at FROM twitch_schedules")
        const avatarRows = DbService.read("SELECT login, source_url, image_data_url, fetched_at FROM twitch_avatars")
        const notifiedRows = DbService.read("SELECT login, stream_id, online FROM twitch_notified_streams")
        if (userRows === null || scheduleRows === null || avatarRows === null || notifiedRows === null) return false
        const cache = {}
        for (const row of scheduleRows)
            cache[row.login] = {startsAt: row.starts_at, fetchedAt: row.fetched_at}
        const avatars = {}
        for (const row of avatarRows)
            avatars[row.login] = {sourceUrl: row.source_url, dataUrl: row.image_data_url, fetchedAt: row.fetched_at}
        const notifiedStreams = {}
        for (const row of notifiedRows) notifiedStreams[row.login] = {streamId: row.stream_id, online: !!row.online}
        state.schedules = cache
        state.avatars = avatars
        state.notifiedStreams = notifiedStreams
        state.users = userRows.map(row => ({login: row.login, addedAt: row.added_at}))
        return true
    }

    function addUser(value) {
        const input = normalizeLogin(value)
        const twitchUrl = input.match(/^(?:https?:\/\/)?(?:www\.)?twitch\.tv\/([a-z0-9_]+)\/?(?:[?#].*)?$/)
        const login = twitchUrl ? twitchUrl[1] : input
        if (!validLogin(login)) {
            state.error = "Enter a Twitch login (letters, numbers or underscores, up to 25 characters) or a streamer Twitch URL"
            return false
        }
        let added = false
        if (!DbService.write(tx => {
            added = tx.executeSql("INSERT OR IGNORE INTO twitch_users (login, added_at) VALUES (?, ?)", [login, Date.now()]).rowsAffected > 0
        })) return false
        if (!added) {
            state.error = "That streamer is already in the list"
            return false
        }
        state.error = ""
        clearUndo(login)
        return reload()
    }

    function removeUser(value) {
        const login = normalizeLogin(value)
        const user = users.find(entry => entry.login === login)
        if (!user) return false
        const snapshot = {user, schedule: schedules[login], avatar: avatars[login], stream: notifiedStreams[login]}
        let removed = false
        if (!DbService.write(tx => {
            tx.executeSql("DELETE FROM twitch_schedules WHERE login = ?", [login])
            tx.executeSql("DELETE FROM twitch_avatars WHERE login = ?", [login])
            tx.executeSql("DELETE FROM twitch_notified_streams WHERE login = ?", [login])
            removed = tx.executeSql("DELETE FROM twitch_users WHERE login = ?", [login]).rowsAffected > 0
        })) return false
        state.error = ""
        if (removed) {
            snapshot.expiresAt = Date.now() + Config.twitchUndoDuration
            state.removedUsers = [...state.removedUsers, snapshot]
            updateUndoTimer()
            reload()
        }
        return removed
    }

    function updateUndoTimer() {
        undoTimer.stop()
        if (!state.removedUsers.length) return
        undoTimer.interval = Math.max(1, Math.min(...state.removedUsers.map(entry => entry.expiresAt)) - Date.now())
        undoTimer.start()
    }

    function pruneUndo() {
        const now = Date.now()
        state.removedUsers = state.removedUsers.filter(entry => entry.expiresAt > now)
        updateUndoTimer()
    }

    function clearUndo(login) {
        state.removedUsers = state.removedUsers.filter(entry => entry.user.login !== login)
        updateUndoTimer()
    }

    function undoRemoveUser(value) {
        pruneUndo()
        const login = normalizeLogin(value)
        const snapshot = state.removedUsers.find(entry => entry.user.login === login)
        if (!snapshot) return false
        if (!DbService.write(tx => {
            tx.executeSql("INSERT INTO twitch_users (login, added_at) VALUES (?, ?)", [login, snapshot.user.addedAt])
            if (snapshot.schedule)
                tx.executeSql("INSERT INTO twitch_schedules (login, starts_at, fetched_at) VALUES (?, ?, ?)",
                    [login, snapshot.schedule.startsAt, snapshot.schedule.fetchedAt])
            if (snapshot.avatar)
                tx.executeSql("INSERT INTO twitch_avatars (login, source_url, image_data_url, fetched_at) VALUES (?, ?, ?, ?)",
                    [login, snapshot.avatar.sourceUrl, snapshot.avatar.dataUrl, snapshot.avatar.fetchedAt])
            if (snapshot.stream)
                tx.executeSql("INSERT INTO twitch_notified_streams (login, stream_id, online) VALUES (?, ?, ?)",
                    [login, snapshot.stream.streamId, snapshot.stream.online ? 1 : 0])
        })) return false
        clearUndo(login)
        state.error = ""
        return reload()
    }

    Timer {
        id: undoTimer
        objectName: "twitchUndoExpiry"
        interval: Config.twitchUndoDuration
        onTriggered: root.pruneUndo()
    }

    function saveSchedule(value, startsAt, fetchedAt) {
        const login = normalizeLogin(value)
        // A removed user's in-flight response must not recreate its cache.
        if (!logins().includes(login)) return false
        if (startsAt !== null && (!Number.isFinite(startsAt) || startsAt <= 0)) return false
        if (!Number.isFinite(fetchedAt) || fetchedAt <= 0) return false
        if (!DbService.write(tx => {
            tx.executeSql("INSERT OR REPLACE INTO twitch_schedules (login, starts_at, fetched_at) VALUES (?, ?, ?)", [login, startsAt, fetchedAt])
        })) return false
        state.schedules = Object.assign({}, state.schedules, {[login]: {startsAt, fetchedAt}})
        return true
    }

    function exportUsers() {
        // The IPC client supplies the final newline when printing this string.
        return root.logins().join("\n")
    }

    function updateStreamSnapshot(streams) {
        const followed = logins()
        const entries = streams.filter(stream => followed.includes(stream.login) && stream.streamId)
        const current = streams.map(stream => stream.login)
        const saved = Object.assign({}, state.notifiedStreams)
        const online = entries.filter(stream => saved[stream.login]?.streamId !== stream.streamId)
        const offline = followed.filter(login => saved[login]?.online && !current.includes(login)).map(login => ({login}))
        const changed = entries.filter(stream => saved[stream.login]?.streamId !== stream.streamId || !saved[stream.login]?.online)
        if (!changed.length && !offline.length) return {online, offline}
        if (!DbService.write(tx => {
            // The login primary key keeps only one past/current stream per followed user.
            for (const stream of changed)
                tx.executeSql("INSERT OR REPLACE INTO twitch_notified_streams (login, stream_id, online) VALUES (?, ?, 1)", [stream.login, stream.streamId])
            for (const stream of offline)
                tx.executeSql("UPDATE twitch_notified_streams SET online = 0 WHERE login = ?", [stream.login])
        })) return null
        for (const stream of changed) saved[stream.login] = {streamId: stream.streamId, online: true}
        for (const stream of offline) saved[stream.login] = {streamId: saved[stream.login].streamId, online: false}
        state.notifiedStreams = saved
        return {online, offline}
    }

    function imageDataUrl(base64) {
        if (typeof base64 !== "string" || !base64.length || base64.length > 1400000 || !/^[A-Za-z0-9+/]+={0,2}$/.test(base64)) return ""
        let format = ""
        if (base64.startsWith("/9j/")) format = "jpeg"
        else if (base64.startsWith("iVBORw0KGgo")) format = "png"
        else if (base64.startsWith("R0lGOD")) format = "gif"
        else if (base64.startsWith("UklGR") && base64.slice(11, 16) === "XRUJQ") format = "webp"
        return format ? `data:image/${format};base64,${base64}` : ""
    }

    function saveAvatar(value, sourceUrl, base64, fetchedAt) {
        const login = normalizeLogin(value)
        const dataUrl = imageDataUrl(base64)
        if (!logins().includes(login) || !sourceUrl || !dataUrl || !Number.isFinite(fetchedAt) || fetchedAt <= 0) return false
        // Data URLs keep the actual image payload in SQLite and are directly readable by QML Image.
        if (!DbService.write(tx => {
            tx.executeSql("INSERT OR REPLACE INTO twitch_avatars (login, source_url, image_data_url, fetched_at) VALUES (?, ?, ?, ?)", [login, sourceUrl, dataUrl, fetchedAt])
        })) return false
        state.avatars = Object.assign({}, state.avatars, {[login]: {sourceUrl, dataUrl, fetchedAt}})
        return true
    }

    Component.onCompleted: reload()
}
