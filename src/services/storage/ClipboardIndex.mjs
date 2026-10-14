// Derived schema stays separate from historical domain migrations.
export function migrate(tx, version) {
    const present = tx.executeSql("SELECT name FROM store.sqlite_master WHERE name='clipboard_fts'").rows.length > 0
    tx.executeSql("PRAGMA store.secure_delete=ON")
    tx.executeSql("CREATE VIRTUAL TABLE IF NOT EXISTS store.clipboard_fts USING fts5(text,mime,content='clipboard',content_rowid='rowid',tokenize='unicode61',prefix='2 3')")
    tx.executeSql("CREATE TRIGGER IF NOT EXISTS store.clipboard_fts_insert AFTER INSERT ON clipboard BEGIN INSERT INTO clipboard_fts(rowid,text,mime) VALUES(new.rowid,new.text,new.mime); END")
    tx.executeSql("CREATE TRIGGER IF NOT EXISTS store.clipboard_fts_delete AFTER DELETE ON clipboard BEGIN INSERT INTO clipboard_fts(clipboard_fts,rowid,text,mime) VALUES('delete',old.rowid,old.text,old.mime); END")
    tx.executeSql("CREATE TRIGGER IF NOT EXISTS store.clipboard_fts_update AFTER UPDATE OF text,mime ON clipboard WHEN old.text IS NOT new.text OR old.mime IS NOT new.mime BEGIN INSERT INTO clipboard_fts(clipboard_fts,rowid,text,mime) VALUES('delete',old.rowid,old.text,old.mime); INSERT INTO clipboard_fts(rowid,text,mime) VALUES(new.rowid,new.text,new.mime); END")
    tx.executeSql("INSERT INTO store.clipboard_fts(clipboard_fts,rank) VALUES('secure-delete',1)")
    if (version < 11 || !present) {
        tx.executeSql("INSERT INTO store.clipboard_fts(clipboard_fts) VALUES('rebuild')")
        tx.executeSql("INSERT INTO store.clipboard_fts(clipboard_fts,rank) VALUES('integrity-check',1)")
    }
    tx.executeSql("CREATE INDEX IF NOT EXISTS store.clipboard_kind_time ON clipboard(kind,updated_at DESC,id DESC)")
}
