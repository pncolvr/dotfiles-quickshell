pragma Singleton
import QtQml
import Quickshell
import "../"
import "../launcher"
import "../network"
import "../../config"
import "N8nEntries.mjs" as Entries

ManagedCollectionService {
    id: root
    repository: N8nRepository
    pickerMode: PickerService.Mode.N8n
    collectionName: 'n8n'
    itemForEntry: entry => Entries.items([entry],[])[0]
    pickerItems: Entries.items(availableEntries,N8nRepository.workflows)
    property bool refreshing: false
    property string refreshStatus: ''
    property var queue: []
    property var current: null
    property var pending: []
    property var seenCursors: []
    property int pages: 0
    property int succeeded: 0
    property int failed: 0
    busy: refreshing
    function newEntry() { edit(Entries.empty()) }
    function accept(items) {
        if (managing || !items.length) return
        const result=items[0].result
        const instance=availableEntries.find(entry=>entry.id===result?.instanceId)
        if (!instance) return
        const cached=N8nRepository.workflows.filter(row=>row.instance_id===instance.id)
        const source=cached.find(row=>row.id==='')
        const workflow=cached.find(row=>row.id===result.workflowId)
        if (result.workflowId && (!workflow || source?.url!==instance.url)) return
        let command
        try { command=Entries.launch(instance,result.workflowId ? workflow.url : instance.url,Config.webappBrowsers) }
        catch (exception) { error=exception.message; return }
        PickerService.close()
        Quickshell.execDetached(command)
    }
    function refresh() {
        if (refreshing || !availableEntries.length) return
        queue=availableEntries.map(entry=>Object.assign({},entry))
        succeeded=0; failed=0; error=''; refreshing=true
        nextInstance()
    }
    function nextInstance() {
        if (!queue.length) {
            current=null; refreshing=false
            refreshStatus='Refreshed '+succeeded+' instance(s)'+(failed ? '; '+failed+' failed — saved lists kept.' : '.')
            return
        }
        current=queue[0]; queue=queue.slice(1); pending=[]; seenCursors=[]; pages=0
        refreshStatus='Refreshing '+current.name+'…'
        if (!current.apiKey) { fail('Add an API key in Manage before refreshing.'); return }
        requestPage('')
    }
    function requestPage(cursor) {
        if (++pages>1000 || pending.length>100000 || seenCursors.includes(cursor)) {
            fail('Pagination did not complete. The saved list was kept.'); return
        }
        seenCursors=seenCursors.concat([cursor])
        http.get(Entries.apiUrl(current,cursor),{'X-N8N-API-KEY':current.apiKey,Accept:'application/json'})
    }
    function fail(message) {
        failed++
        error+=(error ? '\n' : '')+current.name+': '+message
        Qt.callLater(nextInstance)
    }
    JsonGet {
        id: http
        objectName: 'n8nRequest'
        onCompleted: (json,message) => {
            if (message) { root.fail(message); return }
            let page
            try {
                page=Entries.page(JSON.parse(json))
                const ids=new Set(root.pending.map(row=>row.id))
                for (const row of page.workflows) {
                    if (ids.has(row.id)) throw new Error('The API repeated a workflow ID. The saved list was kept.')
                    ids.add(row.id)
                }
            } catch (exception) { root.fail(exception.message); return }
            root.pending=root.pending.concat(page.workflows)
            if (page.cursor) { Qt.callLater(()=>root.requestPage(page.cursor)); return }
            if (!N8nRepository.replaceWorkflows(root.current,root.pending)) { root.fail(N8nRepository.error); return }
            root.succeeded++
            Qt.callLater(root.nextInstance)
        }
    }
}
