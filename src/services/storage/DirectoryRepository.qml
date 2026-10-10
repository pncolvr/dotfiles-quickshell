pragma Singleton
import QtQml
import Quickshell
import "../"

Singleton {
    property var directories: []
    property string error: ""
    function reload() {
        const rows = DbService.read("SELECT * FROM directories ORDER BY name COLLATE NOCASE,path")
        if (rows === null) { error = DbService.error; return false }
        directories = rows; error = ""; return true
    }
    function save(previousPath, path, name, category) {
        if (!path || !name.trim() || !["personal","work"].includes(category)) return false
        if (directories.some(entry => entry.path === path && entry.path !== previousPath)) {
            error = "This folder is already in the picker."; return false
        }
        if (!DbService.write(tx => {
            if (previousPath) tx.executeSql("UPDATE directories SET path = ?,name = ?,category = ? WHERE path = ?",[path,name.trim(),category,previousPath])
            else tx.executeSql("INSERT INTO directories (path,name,category) VALUES (?,?,?)",[path,name.trim(),category])
        })) { error = DbService.error; return false }
        return reload()
    }
    function remove(path) {
        if (!DbService.write(tx => tx.executeSql("DELETE FROM directories WHERE path = ?",[path]))) { error = DbService.error; return false }
        return reload()
    }
    Component.onCompleted: reload()
}
