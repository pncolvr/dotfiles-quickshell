pragma Singleton

import QtQml
import Quickshell
import "../"
import "../../config"

Singleton {
    id: root
    property int revision: 0

    function entries() {
        return readEntries() ?? []
    }

    // Cleanup callers must distinguish a failed read from an empty history.
    function readEntries() {
        const dependency = revision
        return DbService.read("SELECT id, mime, kind, bytes, text, updated_at, pinned FROM store.clipboard ORDER BY updated_at DESC, id DESC")
    }

    function prune(tx) {
        const removed = []
        const totals = tx.executeSql("SELECT COUNT(*) AS count, COALESCE(SUM(bytes), 0) AS bytes FROM store.clipboard").rows.item(0)
        let count = totals.count
        let bytes = totals.bytes
        const rows = tx.executeSql("SELECT id, bytes FROM store.clipboard WHERE pinned = 0 ORDER BY updated_at ASC, id ASC").rows
        for (let index = 0; index < rows.length && (count > Config.clipboardMaxItems || bytes > Config.clipboardMaxTotalBytes); index++) {
            const row = rows.item(index)
            removed.push(row.id)
            tx.executeSql("DELETE FROM store.clipboard WHERE id = ?", [row.id])
            count--
            bytes -= row.bytes
        }
        return removed
    }

    function add(entry) {
        let removed = []
        if (!entry || !/^[a-f0-9]{64}$/.test(entry.id) || !["text", "image"].includes(entry.kind)
            || typeof entry.mime !== "string" || typeof entry.text !== "string"
            || !Number.isInteger(entry.bytes) || entry.bytes <= 0 || entry.bytes > Config.clipboardMaxBytes) return null
        if (!DbService.write(tx => {
            // A monotonically increasing timestamp also orders imports and fast consecutive copies.
            const last = tx.executeSql("SELECT MAX(updated_at) AS stamp FROM store.clipboard").rows.item(0).stamp || 0
            tx.executeSql("INSERT OR REPLACE INTO store.clipboard (id,mime,kind,bytes,text,updated_at,pinned) VALUES (?,?,?,?,?,?,COALESCE((SELECT pinned FROM store.clipboard WHERE id = ?),0))",
                [entry.id, entry.mime, entry.kind, entry.bytes, entry.text, Math.max(Date.now(), last + 1), entry.id])
            removed = prune(tx)
        })) return null
        revision++
        return removed
    }

    function setPinned(id, pinned) {
        let removed = []
        if (!DbService.write(tx => {
            tx.executeSql("UPDATE store.clipboard SET pinned = ? WHERE id = ?", [pinned ? 1 : 0, id])
            removed = prune(tx)
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
        if (!DbService.write(tx => tx.executeSql("DELETE FROM store.clipboard WHERE pinned = 0"))) return false
        revision++
        return true
    }
}
