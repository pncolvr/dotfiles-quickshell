pragma Singleton

import Quickshell
import "../"

Singleton {
    id: root
    property int revision: 0
    readonly property string error: DbService.error

    function decodeActions(json) {
        try {
            const actions = JSON.parse(json || "[]")
            return Array.isArray(actions) ? actions.filter(action => typeof action?.identifier === "string"
                && typeof action?.text === "string").map(action => ({identifier: action.identifier, text: action.text})) : []
        } catch (_) { return [] }
    }

    function decode(row) {
        return {archiveId: row.archive_id, emitterKey: row.emitter_key,
            summary: row.summary, body: row.body, urgency: row.urgency,
            receivedAt: row.received_at, updatedAt: row.updated_at, image: row.image,
            actions: decodeActions(row.actions_json), actionHandler: row.action_handler || ""}
    }

    function groups(limit, offset) {
        return DbService.read("SELECT emitter_key AS emitterKey, COUNT(*) AS count, MAX(updated_at) AS latest FROM notifications GROUP BY emitter_key ORDER BY latest DESC, emitter_key LIMIT ? OFFSET ?", [limit, offset]) ?? []
    }

    function entries(key, limit, offset) {
        return (DbService.read("SELECT * FROM notifications WHERE emitter_key = ? ORDER BY updated_at DESC, archive_id DESC LIMIT ? OFFSET ?", [key, limit, offset]) ?? []).map(decode)
    }

    function entry(id) {
        const rows = DbService.read("SELECT * FROM notifications WHERE archive_id = ?", [id])
        return rows?.length ? decode(rows[0]) : null
    }

    function save(entry) {
        // Qt can bind empty protocol strings as NULL; keep optional text as empty strings.
        if (!DbService.write(tx => tx.executeSql("INSERT INTO notifications (archive_id, emitter_key, summary, body, urgency, received_at, updated_at, image, actions_json, action_handler) VALUES (?, ?, COALESCE(?, ''), COALESCE(?, ''), ?, ?, ?, COALESCE(?, ''), ?, COALESCE(?, '')) ON CONFLICT(archive_id) DO UPDATE SET emitter_key = excluded.emitter_key, summary = excluded.summary, body = excluded.body, urgency = excluded.urgency, updated_at = excluded.updated_at, image = excluded.image, actions_json = excluded.actions_json, action_handler = excluded.action_handler",
            [entry.archiveId, entry.emitterKey, entry.summary, entry.body, entry.urgency, entry.receivedAt, entry.updatedAt, entry.image || "",
                JSON.stringify(entry.actions ?? []), entry.actionHandler || ""]))) return false
        revision++
        return true
    }

    function saveImage(id, updatedAt, image) {
        // A late capture cannot recreate deleted history or change an excluded source.
        if (!DbService.write(tx => tx.executeSql("UPDATE notifications SET image = ? WHERE archive_id = ? AND updated_at = ? AND emitter_key IN (SELECT emitter_key FROM notification_emitters WHERE exclude_history = 0)", [image, id, updatedAt]))) return false
        revision++
        return true
    }

    function remove(id) { return erase("archive_id = ?", [id]) }
    function clearEmitter(key) { return erase("emitter_key = ?", [key]) }
    function clearAll() { return erase("1 = 1", []) }
    function erase(where, parameters) {
        if (!DbService.write(tx => tx.executeSql("DELETE FROM notifications WHERE " + where, parameters))) return false
        revision++
        return true
    }

    function live(token) {
        const rows = DbService.read("SELECT * FROM notification_live WHERE live_token = ?", [token])
        return rows?.[0] ?? null
    }
    function saveLive(token, entry) {
        return DbService.write(tx => tx.executeSql("INSERT OR REPLACE INTO notification_live (live_token, archive_id, deadline, duration, popup_visible) VALUES (?, ?, ?, ?, ?)",
            [token, entry.archiveId || "", entry.deadline, entry.duration, entry.popupVisible ? 1 : 0]))
    }
    function removeLive(token) { return DbService.write(tx => tx.executeSql("DELETE FROM notification_live WHERE live_token = ?", [token])) }
    function resetLive() { return DbService.write(tx => tx.executeSql("DELETE FROM notification_live")) }
}
