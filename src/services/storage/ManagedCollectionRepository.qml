import QtQml
import Quickshell
import "../"

// Table names are internal constants; values and record IDs are always SQL parameters.
Singleton {
    id: root
    required property string tableName
    required property string entryLabel
    required property var validateEntry
    property var entries: []
    property string error: ''
    function reload() {
        const rows=DbService.read('SELECT id,payload_json FROM '+tableName+' ORDER BY name COLLATE NOCASE,id')
        if (rows===null) { error=DbService.error; return false }
        try { entries=rows.map(row=>Object.assign(JSON.parse(row.payload_json),{id:row.id})) }
        catch (_) { error='A stored '+entryLabel+' could not be read.'; return false }
        error=''; return true
    }
    function validated(value) {
        const entry=validateEntry(value)
        if (entries.some(other=>other.id!==entry.id && other.name.toLowerCase()===entry.name.toLowerCase()))
            throw new Error('An entry with this name already exists.')
        return entry
    }
    function save(value) {
        let entry
        try { entry=validated(value) } catch (exception) { error=exception.message; return false }
        if (!entry.id) entry.id=String(Date.now())+'-'+Math.random().toString(36).slice(2)
        if (!DbService.write(tx=>{
            tx.executeSql('DELETE FROM '+tableName+' WHERE id=?',[entry.id])
            tx.executeSql('INSERT INTO '+tableName+' (id,name,payload_json) VALUES (?,?,?)',[entry.id,entry.name,JSON.stringify(entry)])
        })) { error=DbService.error; return false }
        return reload()
    }
    function remove(id) {
        if (!DbService.write(tx=>tx.executeSql('DELETE FROM '+tableName+' WHERE id=?',[id]))) { error=DbService.error; return false }
        return reload()
    }
    Connections { target: DbService; function onReadyChanged() { if (DbService.ready) root.reload() } }
    Component.onCompleted: reload()
}
