pragma Singleton

import QtQml
import Quickshell
import "../"

Singleton {
    id: root

    readonly property bool showSeconds: value("clock.showSeconds", false) === true

    QtObject {
        id: state
        property var values: ({})
    }

    function reload() {
        const rows = DbService.read("SELECT key, value_json FROM preferences")
        if (rows === null) return false
        const values = {}
        for (const row of rows) {
            try { values[row.key] = JSON.parse(row.value_json) }
            catch (error) { console.warn("Ignoring an invalid stored preference: " + row.key) }
        }
        state.values = values
        return true
    }

    function value(key, fallback) { return state.values[key] ?? fallback }

    function setValue(key, value) {
        const json = JSON.stringify(value)
        if (!key || json === undefined) return false
        if (!DbService.write(tx => {
            tx.executeSql("INSERT OR REPLACE INTO preferences (key, value_json) VALUES (?, ?)", [key, json])
        })) return false
        state.values = Object.assign({}, state.values, {[key]: value})
        return true
    }

    function setShowSeconds(value) { return setValue("clock.showSeconds", !!value) }

    Component.onCompleted: reload()
}
