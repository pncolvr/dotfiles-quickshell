import QtQuick
import Quickshell
import "../../../src/services"
Scope {
    Timer {
        interval: 25; repeat: true; running: true
        onTriggered: {
            if (!DbService.ready) { if (DbService.error) { console.error("FTS FAIL: migration"); Qt.quit() } return }
            const id = "a".repeat(64)
            const old = ClipboardRepository.entries().find(row => row.id === id)
            if (old && Quickshell.env("FTS_EXPECT_LEGACY") === "1") {
                if (old.pinned !== 1 || old.text !== "legacy alpha") console.error("FTS FAIL: legacy data")
            }
            if (ClipboardRepository.add({id,mime:"text/plain",kind:"text",bytes:10,text:"replacement beta"}) === null)
                console.error("FTS FAIL: write")
            if (DbService.read("SELECT rowid FROM store.clipboard_fts WHERE clipboard_fts MATCH 'alpha'").length)
                console.error("FTS FAIL: obsolete match")
            if (DbService.read("SELECT rowid FROM store.clipboard_fts WHERE clipboard_fts MATCH 'beta'").length !== 1)
                console.error("FTS FAIL: missing match")
            if (DbService.write(tx => { tx.executeSql("DELETE FROM store.clipboard WHERE id=?", [id]); throw new Error("synthetic rollback") }))
                console.error("FTS FAIL: rollback")
            if (DbService.read("SELECT rowid FROM store.clipboard_fts WHERE clipboard_fts MATCH 'beta'").length !== 1)
                console.error("FTS FAIL: rollback index")
            ClipboardRepository.touch(id)
            // Exercise the JSON boundary used by the capture helper, including
            // Qt's NULL binding for a decoded empty string (literal JS differs).
            const imageId = "b".repeat(64)
            const image = JSON.parse('{"id":"' + imageId + '","mime":"image/png","kind":"image","bytes":100,"text":""}')
            if (ClipboardRepository.add(image) === null) console.error("FTS FAIL: captured image")
            ClipboardRepository.setPinned(imageId, true)
            if (ClipboardRepository.add(image) === null) console.error("FTS FAIL: repeated image capture")
            const saved = DbService.read("SELECT text,pinned FROM store.clipboard WHERE id=?", [imageId])?.[0]
            if (!saved || saved.text !== "" || saved.pinned !== 1) console.error("FTS FAIL: image empty text and pin")
            if (!ClipboardRepository.remove(imageId)) console.error("FTS FAIL: image deletion")
            DbService.write(tx => tx.executeSql("INSERT INTO store.clipboard_fts(clipboard_fts,rank) VALUES('integrity-check',1)"))
            DbService.reportError(new Error("NOT NULL constraint failed: clipboard.text PRIVATE_CLIPBOARD_SENTINEL"), "write")
            DbService.reportError(new Error("NOT NULL constraint failed: private_schema.PRIVATE_SCHEMA_SENTINEL"), "write")
            if (DbService.error !== "Local database operation failed.") console.error("FTS FAIL: fixed error message")
            if (!DbService.read("SELECT COUNT(*) AS count FROM store.clipboard") || DbService.error)
                console.error("FTS FAIL: error recovery")
            console.log("PASS: FTS migration, update, rollback and touch")
            Qt.quit()
        }
    }
}
