pragma Singleton
import QtQml
import "../"
import "../../config"
import "../browser/BrowserRouting.mjs" as Routing

ManagedCollectionRepository {
    id: root
    tableName: 'browser_routes'
    entryLabel: 'browser.routing.rules'
    sortEntries: items=>Routing.ordered(items)
    validateEntry: entry=>Routing.validate(Object.assign({},entry,{
        priority:entry.id ? (entry.priority ?? 0) : Math.max(-1,...entries.map(row=>row.priority ?? 0))+1
    }),Config.webappBrowsers)
    property int revision: 0
    readonly property int historyCount: count(revision)
    function move(id,direction) {
        const from=entries.findIndex(entry=>entry.id===id)
        const to=from+direction
        if (![-1,1].includes(direction) || from<0 || to<0 || to>=entries.length) return false
        const reordered=entries.slice()
        const entry=reordered.splice(from,1)[0]
        reordered.splice(to,0,entry)
        if (!DbService.write(tx=>{
            reordered.forEach((row,index)=>tx.executeSql('UPDATE browser_routes SET payload_json=? WHERE id=?',
                [JSON.stringify(Object.assign({},row,{priority:index})),row.id]))
        })) { error=DbService.error; return false }
        return reload()
    }
    function count(_revision) { return DbService.ready ? (DbService.read('SELECT COUNT(*) AS count FROM browser_history')?.[0]?.count ?? 0) : 0 }
    function history(query='') {
        const search=Routing.historyQuery(query)
        if (query.trim() && !search) return []
        return DbService.read(search
            ? 'SELECT h.url,h.browser,h.handled_at,h.rule_name,h.final_url FROM browser_history h JOIN browser_history_fts ON browser_history_fts.rowid=h.rowid WHERE browser_history_fts MATCH ? ORDER BY h.handled_at DESC,h.url LIMIT ?'
            : 'SELECT url,browser,handled_at,rule_name,final_url FROM browser_history ORDER BY handled_at DESC,url LIMIT ?',
            search ? [search,root.historyLimit()] : [root.historyLimit()]) ?? []
    }
    function historyLimit() { return Math.max(0,Math.floor(Config.browserHistoryLimit)) }
    function record(url,browser,ruleName='',finalUrl=url) {
        if (!Config.browserRoutingEnabled || !Config.browserHistoryEnabled || historyLimit()===0) return true
        const success=DbService.write(tx=>{
            tx.executeSql("INSERT INTO browser_history(url,browser,handled_at,rule_name,final_url) VALUES(?,?,?,COALESCE(?,''),?) ON CONFLICT(url) DO UPDATE SET browser=excluded.browser,handled_at=excluded.handled_at,rule_name=excluded.rule_name,final_url=excluded.final_url",[url,browser,Date.now(),ruleName,finalUrl])
            prune(tx)
        })
        if (success) revision++
        return success
    }
    function prune(tx) { tx.executeSql('DELETE FROM browser_history WHERE rowid NOT IN (SELECT rowid FROM browser_history ORDER BY handled_at DESC,url LIMIT ?)',[historyLimit()]) }
    function trimHistory() { if (Config.browserRoutingEnabled && DbService.ready && DbService.write(tx=>prune(tx))) revision++ }
    function removeHistory(url) {
        if (DbService.write(tx=>tx.executeSql('DELETE FROM browser_history WHERE url=?',[url]))) revision++
    }
    function clearHistory() {
        if (DbService.write(tx=>tx.executeSql('DELETE FROM browser_history'))) revision++
    }
    Connections { target: Config; function onBrowserHistoryLimitChanged() { root.trimHistory() } }
    Connections { target: Config; function onBrowserRoutingEnabledChanged() { root.trimHistory() } }
    Connections { target: DbService; function onReadyChanged() { if(DbService.ready) root.trimHistory() } }
}
