pragma Singleton

import QtQml
import QtQuick.LocalStorage as SQL
import Quickshell
import "../../config"

Singleton {
    id: root

    readonly property string name: Config.databaseName
    readonly property string path: Config.databasePath
    readonly property int schemaVersion: 8
    readonly property bool ready: state.ready
    readonly property string error: state.error

    QtObject {
        id: state
        property var database: null
        property bool ready: false
        property string error: ""
    }

    function reportError(error) {
        state.error = "Local database: " + (error.message ?? String(error))
        console.warn(state.error)
    }

    function ensureOpen() {
        if (state.database) return true
        try {
            // LocalStorage provides the native connection; all application tables live in store.
            const database = SQL.LocalStorage.openDatabaseSync(name + "-connection", "", "Quickshell SQLite connection", 0)
            database.transaction(tx => {
                const databases = tx.executeSql("PRAGMA database_list")
                let attached = false
                for (let index = 0; index < databases.rows.length; index++) {
                    const entry = databases.rows.item(index)
                    if (entry.name !== "store") continue
                    if (entry.file !== path) throw new Error("Restart Quickshell after changing the database path")
                    attached = true
                }
                if (!attached) tx.executeSql("ATTACH DATABASE ? AS store", [path])
                const version = tx.executeSql("PRAGMA store.user_version").rows.item(0).user_version
                if (version < 0 || version > schemaVersion)
                    throw new Error("Unsupported schema version " + version)
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.twitch_users (login TEXT PRIMARY KEY COLLATE NOCASE, added_at INTEGER NOT NULL)")
                if (version < 7) {
                    const columns = tx.executeSql("PRAGMA store.table_info(twitch_users)").rows
                    const names = []
                    for (let index = 0; index < columns.length; index++) names.push(columns.item(index).name)
                    if (!names.includes("fallback_login")) tx.executeSql("ALTER TABLE store.twitch_users ADD COLUMN fallback_login TEXT NOT NULL DEFAULT '' COLLATE NOCASE")
                }
                tx.executeSql("CREATE UNIQUE INDEX IF NOT EXISTS store.twitch_fallback_login ON twitch_users (fallback_login) WHERE fallback_login <> ''")
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.twitch_schedules (login TEXT PRIMARY KEY COLLATE NOCASE, starts_at INTEGER, fetched_at INTEGER NOT NULL)")
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.twitch_avatars (login TEXT PRIMARY KEY COLLATE NOCASE, source_url TEXT NOT NULL, image_data_url TEXT NOT NULL, fetched_at INTEGER NOT NULL)")
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.twitch_notified_streams (login TEXT PRIMARY KEY COLLATE NOCASE, stream_id TEXT NOT NULL, online INTEGER NOT NULL DEFAULT 1)")
                const streamColumns = tx.executeSql("PRAGMA store.table_info(twitch_notified_streams)").rows
                const streamNames = []
                for (let index = 0; index < streamColumns.length; index++) streamNames.push(streamColumns.item(index).name)
                if (!streamNames.includes("online")) tx.executeSql("ALTER TABLE store.twitch_notified_streams ADD COLUMN online INTEGER NOT NULL DEFAULT 1")
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.battery_receivers (device_id TEXT PRIMARY KEY, payload_json TEXT NOT NULL, updated_at INTEGER NOT NULL)")
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.preferences (key TEXT PRIMARY KEY, value_json TEXT NOT NULL)")
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.clipboard (id TEXT PRIMARY KEY, mime TEXT NOT NULL, kind TEXT NOT NULL, bytes INTEGER NOT NULL, text TEXT NOT NULL DEFAULT '', updated_at INTEGER NOT NULL)")
                if (version < 6) {
                    const columns = tx.executeSql("PRAGMA store.table_info(clipboard)").rows
                    const names = []
                    for (let index = 0; index < columns.length; index++) names.push(columns.item(index).name)
                    if (!names.includes("pinned")) tx.executeSql("ALTER TABLE store.clipboard ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0")
                }
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.notification_emitters (emitter_key TEXT PRIMARY KEY, display_name TEXT NOT NULL, icon TEXT NOT NULL DEFAULT '', desktop_entry TEXT NOT NULL DEFAULT '', muted INTEGER NOT NULL DEFAULT 0, allow_dnd INTEGER NOT NULL DEFAULT 0, exclude_history INTEGER NOT NULL DEFAULT 0)")
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.notifications (archive_id TEXT PRIMARY KEY, emitter_key TEXT NOT NULL, summary TEXT NOT NULL, body TEXT NOT NULL, urgency INTEGER NOT NULL, received_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, image TEXT NOT NULL DEFAULT '', actions_json TEXT NOT NULL DEFAULT '[]', action_handler TEXT NOT NULL DEFAULT '')")
                if (version < 3) {
                    const columns = tx.executeSql("PRAGMA store.table_info(notifications)").rows
                    const names = []
                    for (let index = 0; index < columns.length; index++) names.push(columns.item(index).name)
                    if (!names.includes("actions_json")) tx.executeSql("ALTER TABLE store.notifications ADD COLUMN actions_json TEXT NOT NULL DEFAULT '[]'")
                    if (!names.includes("action_handler")) tx.executeSql("ALTER TABLE store.notifications ADD COLUMN action_handler TEXT NOT NULL DEFAULT ''")
                    // Our Twitch URL action is known locally; older app callbacks cannot be recovered.
                    tx.executeSql("UPDATE store.notifications SET actions_json = ?, action_handler = 'twitch' WHERE emitter_key = 'app:twitch' AND actions_json = '[]'",
                        [JSON.stringify([{identifier: "default", text: "Open Twitch"}, {identifier: "open-twitch", text: "Open Twitch"}])])
                }
                tx.executeSql("CREATE INDEX IF NOT EXISTS store.notifications_emitter_time ON notifications (emitter_key, updated_at DESC, archive_id DESC)")
                // Only lifecycle metadata is retained here, including for excluded sources.
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.notification_live (live_token TEXT PRIMARY KEY, archive_id TEXT NOT NULL DEFAULT '', deadline INTEGER NOT NULL, duration INTEGER NOT NULL, popup_visible INTEGER NOT NULL DEFAULT 0)")
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.project_sources (path TEXT PRIMARY KEY, kind TEXT NOT NULL, category TEXT NOT NULL, error TEXT NOT NULL DEFAULT '', refreshed_at INTEGER NOT NULL DEFAULT 0)")
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.projects (source_path TEXT NOT NULL, path TEXT NOT NULL, name TEXT NOT NULL, remote_url TEXT NOT NULL DEFAULT '', PRIMARY KEY(source_path,path))")
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.project_workspaces (project_path TEXT NOT NULL, path TEXT NOT NULL, name TEXT NOT NULL, included INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(project_path,path))")
                tx.executeSql("PRAGMA store.user_version = " + schemaVersion)
            })
            state.database = database
            state.ready = true
            state.error = ""
            return true
        } catch (error) {
            root.reportError(error)
            return false
        }
    }

    // Return ordinary JavaScript rows; repositories never retain a SQL result or transaction.
    function read(sql, parameters) {
        if (!ensureOpen()) return null
        try {
            const rows = []
            state.database.readTransaction(tx => {
                const result = tx.executeSql(sql, parameters ?? [])
                for (let index = 0; index < result.rows.length; index++)
                    rows.push(Object.assign({}, result.rows.item(index)))
            })
            state.error = ""
            return rows
        } catch (error) {
            root.reportError(error)
            return null
        }
    }

    // Explicitly roll back callback errors, including those crossing QML function boundaries.
    function write(callback) {
        if (!ensureOpen()) return false
        try {
            state.database.transaction(tx => {
                tx.executeSql("SAVEPOINT repository_write")
                try {
                    callback(tx)
                    tx.executeSql("RELEASE SAVEPOINT repository_write")
                } catch (error) {
                    tx.executeSql("ROLLBACK TO SAVEPOINT repository_write")
                    tx.executeSql("RELEASE SAVEPOINT repository_write")
                    throw error
                }
            })
            state.error = ""
            return true
        } catch (error) {
            root.reportError(error)
            return false
        }
    }

    Component.onCompleted: ensureOpen()
}
