pragma Singleton
import "../../i18n"
import QtQml
import "../"
import "../../config"
import "../n8n/N8nEntries.mjs" as Entries

ManagedCollectionRepository {
    id: root
    tableName: 'n8n_instances'
    entryLabel: "n8n.instance.label"
    validateEntry: value => Entries.validate(value,Config.webappBrowsers)
    removeRelated: (tx,id) => tx.executeSql('DELETE FROM n8n_workflows WHERE instance_id=?',[id])
    property var workflows: []
    function reloadWorkflows() {
        const rows=DbService.read('SELECT * FROM n8n_workflows ORDER BY name COLLATE NOCASE,id')
        if (rows===null) { error=DbService.error; return false }
        workflows=rows
        return true
    }
    function replaceWorkflows(instance,rows) {
        // A renamed/removed connection must not receive a response for an old URL/key.
        const current=entries.find(entry=>entry.id===instance.id)
        if (!current || current.url!==instance.url || current.apiKey!==instance.apiKey) {
            error=Translations.text("n8n.errors.connectionChanged"); return false
        }
        const now=Date.now()
        if (!DbService.write(tx=>{
            tx.executeSql('DELETE FROM n8n_workflows WHERE instance_id=?',[instance.id])
            const links=[{id:'',name:'',url:instance.url},...rows.map(row=>Object.assign({},row,{url:Entries.workflowUrl(instance,row.id)}))]
            for (const row of links) tx.executeSql('INSERT INTO n8n_workflows(instance_id,id,name,url,fetched_at) VALUES(?,?,?,?,?)',
                [instance.id,row.id,row.name,row.url,now])
        })) { error=DbService.error; return false }
        error=''; return reloadWorkflows()
    }
    onEntriesChanged: reloadWorkflows()
    Connections {
        target: DbService
        function onReadyChanged() { if (DbService.ready) root.reloadWorkflows() }
    }
    Component.onCompleted: reloadWorkflows()
}
