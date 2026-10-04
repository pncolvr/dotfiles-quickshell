pragma Singleton

import QtQml
import Quickshell
import "../"

Singleton {
    id: root

    readonly property var users: state.users
    readonly property var schedules: state.schedules
    readonly property var avatars: state.avatars
    readonly property string error: state.error || DbService.error

    QtObject {
        id: state
        property var users: []
        property var schedules: ({})
        property var avatars: ({})
        property string error: ""
    }

    function normalizeLogin(login) { return String(login ?? "").trim().toLowerCase() }
    function validLogin(login) { return /^[a-z0-9_]{1,25}$/.test(login) }
    function logins() { return users.map(user => user.login) }

    function reload() {
        const userRows = DbService.read("SELECT login, added_at FROM twitch_users ORDER BY login")
        const scheduleRows = DbService.read("SELECT login, starts_at, fetched_at FROM twitch_schedules")
        const avatarRows = DbService.read("SELECT login, source_url, image_data_url, fetched_at FROM twitch_avatars")
        if (userRows === null || scheduleRows === null || avatarRows === null) return false
        const cache = {}
        for (const row of scheduleRows)
            cache[row.login] = {startsAt: row.starts_at, fetchedAt: row.fetched_at}
        const avatars = {}
        for (const row of avatarRows)
            avatars[row.login] = {sourceUrl: row.source_url, dataUrl: row.image_data_url, fetchedAt: row.fetched_at}
        state.schedules = cache
        state.avatars = avatars
        state.users = userRows.map(row => ({login: row.login, addedAt: row.added_at}))
        return true
    }

    function addUser(value) {
        const login = normalizeLogin(value)
        if (!validLogin(login)) {
            state.error = "Enter a Twitch login using letters, numbers or underscores (up to 25 characters)"
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
        return reload()
    }

    function removeUser(value) {
        const login = normalizeLogin(value)
        let removed = false
        if (!DbService.write(tx => {
            tx.executeSql("DELETE FROM twitch_schedules WHERE login = ?", [login])
            tx.executeSql("DELETE FROM twitch_avatars WHERE login = ?", [login])
            removed = tx.executeSql("DELETE FROM twitch_users WHERE login = ?", [login]).rowsAffected > 0
        })) return false
        state.error = ""
        if (removed) reload()
        return removed
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
