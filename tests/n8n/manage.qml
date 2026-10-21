pragma ComponentBehavior: Bound
import QtQuick
import "../../src/config"
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/modules/launcher"
import "../../src/ui" as UI
import "../../src/services/network" as Network
import "../../src/services/n8n/N8nEntries.mjs" as Entries

WorkerScope {
    id: root
    property int step:0
    property int ticks:0
    property bool failed:false
    property string saved:''
    readonly property string base:Quickshell.env('N8N_TEST_URL')
    readonly property bool restarting:Quickshell.env('N8N_TEST_PHASE')==='restart'
    Test.TestEvent { id:events }
    Test.TestResult { id:objects }
    FloatingWindow { id:window; visible:true; implicitWidth:650; implicitHeight:700; PickerPanel { id:panel; anchors.fill:parent } }
    FileView { id:mode; path:Quickshell.env('N8N_TEST_DIR')+'/mode' }
    function check(ok,message) { if (!ok) { failed=true; console.error('N8N FAIL:',message) } }
    function instance(id) { return N8nRepository.entries.find(entry=>entry.id===id) }
    function snapshot(id) { return JSON.stringify(N8nRepository.workflows.filter(row=>row.instance_id===id)) }
    function refresh(value) { mode.setText(value); N8nService.refresh() }
    function field(name) { return objects.findChild(panel,name) as UI.InputField }
    Timer {
        interval:90; repeat:true; running:true
        onTriggered: {
            if (root.failed || ++root.ticks>250) { console.error('N8N FAIL: stopped',root.step,N8nService.error); Qt.quit(); return }
            if (!DbService.ready || N8nService.refreshing) return
            switch(root.step) {
                case 0:
                    PickerService.n8n()
                    if (root.restarting) {
                        root.check(N8nRepository.entries.length===3 && root.instance('a').apiKey==='fixture-a','multiple private instances restored')
                        root.check(N8nRepository.workflows.filter(row=>row.instance_id==='a').length===3,'cached workflows restored without refresh')
                        root.check(PickerService.items.length===3,'personal/status filter restored on open')
                        root.check(N8nService.refreshStatus==='','restart does not refresh')
                        root.step=30; return
                    }
                    for (const entry of [{id:'a',name:'Personal',category:'personal'},{id:'b',name:'Work',category:'work'},
                        {id:'disabled',name:'Disabled',category:'personal',enabled:false}]) {
                        root.check(N8nRepository.save(Object.assign(Entries.empty(Config.defaultBrowserId),entry,{url:root.base+'/'+entry.id,apiKey:'fixture-'+entry.id})),'seed private instance')
                    }
                    root.check(PickerService.items.length===1,'disabled/work instances hidden from personal list')
                    root.check(PickerService.items[0].title==='Open Personal','instance home available before refresh')
                    root.check(!JSON.stringify(PickerService.items).includes('fixture-a'),'picker rows contain no credentials')
                    N8nService.setManaging(true); panel.panel.beginAdd(); root.step=1; break
                case 1:
                    panel.focusSearch(); events.keyClick(Qt.Key_T,Qt.NoModifier,0)
                    root.check(root.field('n8nName').text==='t','Manage name accepts input')
                    root.check((objects.findChild(panel,'n8nApiKey') as UI.SecretField).echoMode===TextInput.Password,'API key is masked')
                    root.check(!!objects.findChild(panel,'n8nBrowserSelector') && !!objects.findChild(panel,'n8nCategorySelector'),'shared browser and category controls')
                    root.check(!(objects.findChild(panel,'n8nRefreshAll') as UI.ActionButton).enabled,'Refresh all is disabled during editing')
                    N8nService.cancel()
                    panel.panel.managementView.select('a')
                    const refreshInstance=objects.findChild(panel,'n8nRefresh') as UI.ActionButton
                    const refreshAll=objects.findChild(panel,'n8nRefreshAll') as UI.ActionButton
                    const add=objects.findChild(panel,'addCollectionEntry') as UI.ActionButton
                    root.check(refreshAll.mapToItem(panel,0,0).x<add.mapToItem(panel,0,0).x
                        && refreshAll.mapToItem(panel,0,0).y===add.mapToItem(panel,0,0).y,'Refresh all is immediately before Add in the toolbar')
                    root.check(refreshInstance.mapToItem(panel,0,0).y>refreshAll.mapToItem(panel,0,0).y,'instance refresh is in the details action row')
                    refreshInstance.clicked()
                    root.check(N8nService.refreshing && N8nService.current.id==='a' && !N8nService.queue.length,'details refresh queues only the selected instance')
                    root.check(!refreshInstance.enabled && !refreshAll.enabled,'both refresh controls disable during a request')
                    root.step=12; break
                case 12:
                    root.check(N8nService.succeeded===1 && N8nRepository.workflows.filter(row=>row.instance_id==='b').length===0,'single-instance refresh leaves other caches untouched')
                    panel.panel.managementView.select('disabled')
                    root.check(!(objects.findChild(panel,'n8nRefresh') as UI.ActionButton).enabled,'disabled instances cannot be refreshed')
                    panel.panel.managementView.select('a')
                    root.check(!N8nService.showAll && N8nService.availableEntries.length===1,'Refresh all starts with the Work category hidden')
                    events.keyClick(Qt.Key_R,Qt.ControlModifier,0)
                    root.check(N8nService.refreshing,'Ctrl+R starts explicit refresh')
                    root.step=2; break
                case 2:
                    root.check(N8nService.succeeded===2 && N8nService.failed===0,'both instances fully refreshed')
                    N8nService.setManaging(false)
                    events.keyClick(Qt.Key_W,Qt.ControlModifier,0)
                    root.check(N8nService.showAll,'Ctrl+W shows both enabled instances')
                    root.check(PickerService.items.length===6 && N8nRepository.workflows.length===6,'combined home/workflow list updates reactively')
                    root.check(new Set(PickerService.items.map(item=>item.id)).size===6,'same workflow ID on different instances remains distinct')
                    root.check(!JSON.stringify(N8nRepository.workflows).includes('discard-me'),'definitions discarded before storage')
                    root.saved=root.snapshot('a'); root.refresh('partial'); root.step=3; break
                case 3:
                    root.check(N8nService.succeeded===1 && N8nService.failed===1,'failed instance does not stop others')
                    root.check(root.snapshot('a')===root.saved,'failed second page preserves entire previous snapshot')
                    root.check(N8nRepository.workflows.some(row=>row.instance_id==='b' && row.name==='Updated b'),'other instance committed successful result')
                    root.refresh('repeat'); root.step=4; break
                case 4:
                    root.check(N8nService.failed===2 && root.snapshot('a')===root.saved,'repeated pages rejected without cache loss')
                    root.refresh('invalid'); root.step=5; break
                case 5:
                    root.check(N8nService.failed===2 && root.snapshot('a')===root.saved,'malformed workflow preserves cache')
                    root.refresh('redirect'); root.step=6; break
                case 6:
                    root.check(N8nService.failed===2 && root.snapshot('a')===root.saved,'redirect not followed with private headers')
                    root.refresh('denied'); root.step=7; break
                case 7:
                    root.check(N8nService.failed===2 && root.snapshot('a')===root.saved,'authentication failure preserves cache')
                    root.check(!N8nService.error.includes('fixture key'),'server error bodies are not displayed')
                    const http=objects.findChild(N8nService,'n8nRequest') as Network.JsonGet
                    http.timeoutSeconds=1
                    root.refresh('timeout'); root.step=20; break
                case 20:
                    root.check(N8nService.failed===2 && root.snapshot('a')===root.saved,'bounded timeout preserves cache')
                    root.refresh('oversize'); root.step=21; break
                case 21:
                    root.check(N8nService.failed===2 && root.snapshot('a')===root.saved,'oversized response rejected without cache loss')
                    root.refresh('changed'); root.step=8; break
                case 8:
                    root.check(N8nService.succeeded===2,'second successful snapshot')
                    root.check(!N8nRepository.workflows.some(row=>row.id==='old') && N8nRepository.workflows.filter(row=>row.id==='new').length===2,'batch removes and additions reconciled per instance')
                    root.check(N8nRepository.workflows.some(row=>row.name==='Renamed a'),'stable workflow ID rename reconciled')
                    root.saved=root.snapshot('a')
                    root.check(!N8nRepository.replaceWorkflows(Object.assign({},root.instance('a'),{apiKey:'obsolete'}),[])
                        && root.snapshot('a')===root.saved,'stale response cannot replace changed connection cache')
                    root.check(DbService.write(tx=>tx.executeSql("CREATE TRIGGER store.reject_workflow BEFORE INSERT ON n8n_workflows WHEN NEW.name='Broken' BEGIN SELECT RAISE(ABORT,'fixture'); END")),'install rollback fixture')
                    root.check(!N8nRepository.replaceWorkflows(root.instance('a'),[{id:'broken',name:'Broken'}]),'failed snapshot rejected')
                    root.check(root.snapshot('a')===root.saved && DbService.read("SELECT COUNT(*) AS count FROM n8n_workflows WHERE instance_id='a'")[0].count===3,'failed replacement rolls back SQL and keeps memory snapshot')
                    DbService.write(tx=>tx.executeSql('DROP TRIGGER store.reject_workflow'))
                    root.refresh('empty'); root.step=9; break
                case 9:
                    root.check(N8nRepository.workflows.length===2 && PickerService.items.length===2,'valid empty refresh removes workflows, keeps instance homes')
                    root.check(N8nRepository.save(Object.assign({},root.instance('a'),{apiKey:''})),'empty API key allowed for cached navigation')
                    root.refresh('changed'); root.step=10; break
                case 10:
                    root.check(N8nService.failed===1 && N8nService.succeeded===1 && N8nRepository.workflows.filter(row=>row.instance_id==='a').length===1,'missing key preserves cache and other instance refreshes')
                    root.check(N8nRepository.save(Object.assign({},root.instance('a'),{apiKey:'fixture-a'})),'restore synthetic key')
                    root.refresh('changed'); root.step=11; break
                case 11:
                    root.check(N8nRepository.save(Object.assign(Entries.empty(Config.defaultBrowserId),{id:'remove',name:'Remove',url:root.base+'/remove'})),'create removal fixture')
                    root.check(N8nRepository.replaceWorkflows(root.instance('remove'),[{id:'x',name:'Removed workflow'}]),'seed related cache')
                    root.check(N8nRepository.remove('remove') && !N8nRepository.workflows.some(row=>row.instance_id==='remove'),'remove instance and cache together')
                    root.check(!N8nRepository.save(Object.assign(Entries.empty(Config.defaultBrowserId),{name:'personal',url:root.base+'/other'})),'duplicate instance name rejected')
                    N8nService.toggleShowAll()
                    root.check(PickerService.items.length===3,'status filtering applies to whole instance cache')
                    PickerService.query='Renamed a'
                    PickerService.accept(false,false)
                    root.check(!PickerService.visible,'workflow opens through native browser and closes picker')
                    root.step=30; break
                case 30:
                    if (!root.failed) console.log('PASS: n8n multi-instance Manage, filters, refresh transactions, cache and restart')
                    Qt.quit(); break
            }
        }
    }
}
