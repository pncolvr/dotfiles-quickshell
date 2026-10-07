pragma Singleton

import QtQml
import Quickshell
import "../"
import "../../config"

Singleton {
    id: root
    property int revision: 0

    function entries() {
        const dependency = revision
        return DbService.read("SELECT id, mime, kind, bytes, text, updated_at FROM store.clipboard ORDER BY updated_at DESC, id DESC") ?? []
    }

    function add(entry) {
        const removed = []
        if (!entry || !/^[a-f0-9]{64}$/.test(entry.id) || !["text", "image"].includes(entry.kind)
            || typeof entry.mime !== "string" || typeof entry.text !== "string"
            || !Number.isInteger(entry.bytes) || entry.bytes <= 0 || entry.bytes > Config.clipboardMaxBytes) return null
        if (!DbService.write(tx => {
            // A monotonically increasing timestamp also orders imports and fast consecutive copies.
            const last = tx.executeSql("SELECT MAX(updated_at) AS stamp FROM store.clipboard").rows.item(0).stamp || 0
            tx.executeSql("INSERT OR REPLACE INTO store.clipboard (id,mime,kind,bytes,text,updated_at) VALUES (?,?,?,?,?,?)",
                [entry.id, entry.mime, entry.kind, entry.bytes, entry.text, Math.max(Date.now(), last + 1)])
            const rows = tx.executeSql("SELECT id, bytes FROM store.clipboard ORDER BY updated_at DESC, id DESC").rows
            let total = 0
            for (let index = 0; index < rows.length; index++) {
                const row = rows.item(index)
                total += row.bytes
                if (index >= Config.clipboardMaxItems || total > 50000000) {
                    removed.push(row.id)
                    tx.executeSql("DELETE FROM store.clipboard WHERE id = ?", [row.id])
                }
            }
        })) return null
        revision++
        return removed
    }

    function remove(id) {
        if (!DbService.write(tx => tx.executeSql("DELETE FROM store.clipboard WHERE id = ?", [id]))) return false
        revision++
        return true
    }

    function clear() {
        if (!DbService.write(tx => tx.executeSql("DELETE FROM store.clipboard"))) return false
        revision++
        return true
    }
}
