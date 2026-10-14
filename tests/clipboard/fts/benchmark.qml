import QtQuick
import Quickshell
import "../../../src/services"
Scope {
    Timer {
        interval: 20; repeat: true; running: true
        onTriggered: {
            if (!DbService.ready) return
            stop()
            const bytes = Number(Quickshell.env("FTS_BENCH_BYTES") || 500000)
            const text = "synthetic clipboard alpha beta gamma ".repeat(Math.ceil(bytes / 37)).slice(0,bytes)
            const start = Date.now()
            DbService.write(tx => {
                tx.executeSql("DROP TRIGGER clipboard_fts_insert")
                for (let i = 0; i < 1000; i++) tx.executeSql("INSERT INTO store.clipboard(id,mime,kind,bytes,text,updated_at,pinned) VALUES(?,'text/plain','text',?,?,?,0)",[(i+1).toString(16).padStart(64,"0"),text.length,text,i])
            })
            const inserted = Date.now()
            DbService.write(tx => {
                tx.executeSql("INSERT INTO store.clipboard_fts(clipboard_fts) VALUES('rebuild')")
                tx.executeSql("INSERT INTO store.clipboard_fts(clipboard_fts,rank) VALUES('integrity-check',1)")
            })
            console.log("BENCH",JSON.stringify({rows:1000,bytes:1000*text.length,insertMs:inserted-start,rebuildMs:Date.now()-inserted}))
            console.log("PASS: synthetic bounded-history rebuild benchmark")
            Qt.quit()
        }
    }
}
