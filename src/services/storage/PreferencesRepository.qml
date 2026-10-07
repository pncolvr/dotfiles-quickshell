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
        if (!key) return false
        return setValues({[key]: value})
    }

    function setValues(values) {
        const entries = Object.entries(values).map(([key, value]) => [key, JSON.stringify(value)])
        if (entries.some(([key, json]) => !key || json === undefined)) return false
        if (!DbService.write(tx => {
            for (const entry of entries)
                tx.executeSql("INSERT OR REPLACE INTO preferences (key, value_json) VALUES (?, ?)", entry)
        })) return false
        state.values = Object.assign({}, state.values, values)
        return true
    }

    function setShowSeconds(value) { return setValue("clock.showSeconds", !!value) }

    Component.onCompleted: reload()
}
