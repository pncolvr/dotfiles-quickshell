pragma Singleton

import QtQml
import Quickshell
import "../"

Singleton {
    id: root
    property var emitters: ({})

    function identity(desktopEntry, appName) {
        const desktop = String(desktopEntry ?? "").trim().replace(/\.desktop$/, "")
        return desktop ? "desktop:" + desktop.toLowerCase()
            : "app:" + (String(appName ?? "").trim().toLowerCase() || "unknown")
    }

    function reload() {
        const rows = DbService.read("SELECT * FROM notification_emitters ORDER BY display_name COLLATE NOCASE")
        if (rows === null) return false
        const next = {}
        for (const row of rows) next[row.emitter_key] = {
            key: row.emitter_key, name: row.display_name, icon: row.icon,
            desktopEntry: row.desktop_entry, muted: !!row.muted,
            allowDuringDnd: !!row.allow_dnd, excludeFromHistory: !!row.exclude_history
        }
        emitters = next
        return true
    }

    function ensure(desktopEntry, appName, icon) {
        const key = identity(desktopEntry, appName)
        const previous = emitters[key]
        const name = String(appName || desktopEntry || "Unknown application")
        const image = String(icon || previous?.icon || "")
        if (previous && previous.name === name && previous.icon === image) return previous
        if (DbService.write(tx => {
            tx.executeSql("INSERT INTO notification_emitters (emitter_key, display_name, icon, desktop_entry) VALUES (?, ?, ?, ?) ON CONFLICT(emitter_key) DO UPDATE SET display_name = excluded.display_name, icon = excluded.icon, desktop_entry = excluded.desktop_entry",
                [key, name, image, String(desktopEntry || "")])
        })) reload()
        return emitters[key] ?? {key, name, icon: image, desktopEntry: desktopEntry || "",
            muted: false, allowDuringDnd: false, excludeFromHistory: false}
    }

    function setPreference(key, preference, value) {
        const columns = {muted: "muted", allowDuringDnd: "allow_dnd", excludeFromHistory: "exclude_history"}
        const column = columns[preference]
        if (!column || !emitters[key]) return false
        if (!DbService.write(tx => tx.executeSql("UPDATE notification_emitters SET " + column + " = ? WHERE emitter_key = ?", [value ? 1 : 0, key]))) return false
        return reload()
    }

    Component.onCompleted: reload()
}
