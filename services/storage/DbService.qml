pragma Singleton

import QtQuick
import QtQuick.LocalStorage as SQL
import Quickshell
import "../../config"

Singleton {
    id: root

    readonly property string name: Config.databaseName
    readonly property string path: Config.databasePath
    readonly property int schemaVersion: 1
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
                if (version !== 0 && version !== schemaVersion)
                    throw new Error("Unsupported schema version " + version)
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.twitch_users (login TEXT PRIMARY KEY COLLATE NOCASE, added_at INTEGER NOT NULL)")
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.twitch_schedules (login TEXT PRIMARY KEY COLLATE NOCASE, starts_at INTEGER, fetched_at INTEGER NOT NULL)")
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.twitch_avatars (login TEXT PRIMARY KEY COLLATE NOCASE, source_url TEXT NOT NULL, image_data_url TEXT NOT NULL, fetched_at INTEGER NOT NULL)")
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.battery_receivers (device_id TEXT PRIMARY KEY, payload_json TEXT NOT NULL, updated_at INTEGER NOT NULL)")
                tx.executeSql("CREATE TABLE IF NOT EXISTS store.preferences (key TEXT PRIMARY KEY, value_json TEXT NOT NULL)")
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
