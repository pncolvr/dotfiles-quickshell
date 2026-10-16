pragma Singleton
import QtQml
import Quickshell
import "../"
import "../../config"
import "../webapps/WebappEntries.mjs" as Entries

Singleton {
    id: root
    property var entries: []
    property string error: ""
    function reload() {
        const rows = DbService.read("SELECT id,payload_json FROM webapps ORDER BY name COLLATE NOCASE,id")
        if (rows === null) { error = DbService.error; return false }
        try { entries = rows.map(row => Object.assign(JSON.parse(row.payload_json),{id:row.id})) }
        catch (_) { error = "A stored webapp could not be read."; return false }
        error = ""; return true
    }
    function validated(value) {
        const entry = Entries.validate(value,Config.webappBrowsers)
        if (entries.some(other => other.id !== entry.id && other.name.toLowerCase() === entry.name.toLowerCase()))
            throw new Error("A webapp with this name already exists.")
        return entry
    }
    function insert(tx,entry) {
        const payload = JSON.stringify(entry)
        tx.executeSql("INSERT INTO webapps (id,name,payload_json) VALUES (?,?,?)",[entry.id,entry.name,payload])
    }
    function save(value) {
        let entry
        try { entry = validated(value) } catch (exception) { error = exception.message; return false }
        if (!entry.id) entry.id = String(Date.now()) + "-" + Math.random().toString(36).slice(2)
        if (!DbService.write(tx => {
            tx.executeSql("DELETE FROM webapps WHERE id=?",[entry.id])
            insert(tx,entry)
        })) { error = DbService.error; return false }
        return reload()
    }
    function remove(id) {
        if (!DbService.write(tx => tx.executeSql("DELETE FROM webapps WHERE id=?",[id]))) { error=DbService.error; return false }
        return reload()
    }
    Connections { target: DbService; function onReadyChanged() { if (DbService.ready) root.reload() } }
    Component.onCompleted: reload()
}
