export function migrate(tx) {
    tx.executeSql('CREATE TABLE IF NOT EXISTS store.browser_routes (id TEXT PRIMARY KEY,name TEXT NOT NULL COLLATE NOCASE UNIQUE,payload_json TEXT NOT NULL)')
    tx.executeSql('CREATE TABLE IF NOT EXISTS store.browser_history (url TEXT NOT NULL UNIQUE,browser TEXT NOT NULL,handled_at INTEGER NOT NULL)')
    const columns=tx.executeSql('PRAGMA store.table_info(browser_history)').rows
    let hasRuleName=false
    let hasFinalUrl=false
    let hasResolveMs=false
    for(let index=0;index<columns.length;index++) {
        if(columns.item(index).name==='rule_name') hasRuleName=true
        if(columns.item(index).name==='final_url') hasFinalUrl=true
        if(columns.item(index).name==='resolve_ms') hasResolveMs=true
    }
    if(!hasRuleName) tx.executeSql("ALTER TABLE store.browser_history ADD COLUMN rule_name TEXT NOT NULL DEFAULT ''")
    if(!hasFinalUrl) {
        tx.executeSql("ALTER TABLE store.browser_history ADD COLUMN final_url TEXT NOT NULL DEFAULT ''")
        tx.executeSql('UPDATE store.browser_history SET final_url=url')
    }
    if(!hasResolveMs) tx.executeSql('ALTER TABLE store.browser_history ADD COLUMN resolve_ms INTEGER')
    tx.executeSql('CREATE INDEX IF NOT EXISTS store.browser_history_time ON browser_history(handled_at DESC)')
    const present=tx.executeSql("SELECT name FROM store.sqlite_master WHERE name='browser_history_fts'").rows.length>0
    tx.executeSql("CREATE VIRTUAL TABLE IF NOT EXISTS store.browser_history_fts USING fts5(url,browser,content='browser_history',content_rowid='rowid',tokenize='unicode61',prefix='2 3')")
    tx.executeSql("CREATE TRIGGER IF NOT EXISTS store.browser_history_insert AFTER INSERT ON browser_history BEGIN INSERT INTO browser_history_fts(rowid,url,browser) VALUES(new.rowid,new.url,new.browser); END")
    tx.executeSql("CREATE TRIGGER IF NOT EXISTS store.browser_history_delete AFTER DELETE ON browser_history BEGIN INSERT INTO browser_history_fts(browser_history_fts,rowid,url,browser) VALUES('delete',old.rowid,old.url,old.browser); END")
    tx.executeSql("CREATE TRIGGER IF NOT EXISTS store.browser_history_update AFTER UPDATE ON browser_history BEGIN INSERT INTO browser_history_fts(browser_history_fts,rowid,url,browser) VALUES('delete',old.rowid,old.url,old.browser); INSERT INTO browser_history_fts(rowid,url,browser) VALUES(new.rowid,new.url,new.browser); END")
    tx.executeSql("INSERT INTO store.browser_history_fts(browser_history_fts,rank) VALUES('secure-delete',1)")
    if (!present) tx.executeSql("INSERT INTO store.browser_history_fts(browser_history_fts) VALUES('rebuild')")
}
