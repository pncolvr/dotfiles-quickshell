pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/services"
import "../../src/modules/launcher"
import "../../src/theme/ui" as UI
import "../../src/services/remotes/RemoteEntries.mjs" as Entries
Scope {
    id:root
    property bool failed:false
    property int step:0
    property int ticks:0
    readonly property string testPhase:Quickshell.env('REMOTE_TEST_PHASE')
    readonly property bool restarting:testPhase==='restart'
    Test.TestEvent { id:events }
    Test.TestResult { id:objects }
    FloatingWindow {
        visible:true; implicitWidth:650; implicitHeight:800
        PickerPanel { id:panel; anchors.fill:parent }
    }
    function check(value,message) { if (!value) { failed=true; console.error('REMOTE FAIL:',message) } }
    function field(name) { return objects.findChild(panel,name) as UI.InputField }
    Timer {
        interval:80; running:true; repeat:true
        onTriggered: {
            if (root.failed || ++root.ticks>200) { console.error('REMOTE FAIL: stopped at step',root.step); Qt.quit(); return }
            if (!DbService.ready || RemoteService.busy) return
            switch(root.step) {
                case 0:
                    PickerService.remotes()
                    root.check(PickerService.visible && PickerService.mode===PickerService.Mode.Remotes,'native Remotes mode')
                    if(root.testPhase==='connecting') {
                        const alpha=RemoteRepository.entries.find(entry=>entry.name==='Alpha')
                        root.check(RemoteRepository.save(Object.assign({},alpha,{enabled:true,category:'personal'})),'enable connecting fixture')
                        PickerService.query='Alpha'; PickerService.accept(false,false); root.step=20; return
                    }
                    if(root.restarting) {
                        root.check(RemoteRepository.entries.length===3,'managed entries survive restart without legacy JSON')
                        root.step=8; return
                    }
                    root.check(!RemoteRepository.entries.length,'empty database')
                    for(const entry of [
                        {name:'Alpha',type:'vm',endpoint:'127.0.0.1',vmName:'fixture-vm',password:'literal $() \\ "password"'},
                        {name:'Beta',type:'remote',endpoint:'rdp.example',hopHost:'jump.example',hopUsername:'test'},
                        {name:'Disabled',enabled:false,type:'vm',endpoint:'127.0.0.1',vmName:'disabled-vm'}
                    ])root.check(RemoteRepository.save(Object.assign(Entries.empty(),entry)),'seed fixture entry')
                    RemoteService.setManaging(true)
                    root.check(PickerService.items.length===2,'disabled connections excluded')
                    root.step=1; break
                case 1:
                    root.check(panel.panel instanceof ManagedCollectionPanel,'shared managed picker')
                    panel.panel.beginAdd(); root.step=2; break
                case 2: {
                    panel.focusSearch(); events.keyClick(Qt.Key_T,Qt.NoModifier,0)
                    root.check(root.field('remoteName').text==='t','name field accepts typing')
                    const form=panel.panel.entryForm
                    form.load(Object.assign(Entries.empty(),{name:'Added',type:'vm',endpoint:'127.0.0.1',vmName:'new-vm',password:'fixture secret'}))
                    const secret=objects.findChild(panel,'remotePassword') as UI.SecretField
                    root.check(secret.echoMode===TextInput.Password,'password is masked')
                    root.check((objects.findChild(panel,'remoteCategorySelector') as UI.ComboSelector).visible,'category is visible')
                    panel.panel.submit()
                    root.check(RemoteRepository.entries.length===4 && !RemoteService.draft,'new entry saved')
                    panel.panel.edit(RemoteRepository.entries.find(entry=>entry.name==='Added'))
                    root.step=3; break
                }
                case 3: {
                    root.check(root.field('remoteName').selectedText==='Added','edit selects name')
                    root.field('remoteName').text='Renamed'; panel.panel.submit()
                    const renamed=RemoteRepository.entries.find(entry=>entry.name==='Renamed')
                    root.check(renamed.password==='fixture secret','edit preserves saved secret')
                    DbService.write(tx=>tx.executeSql("CREATE TRIGGER store.reject_remote_update BEFORE INSERT ON remotes WHEN NEW.name='Broken' BEGIN SELECT RAISE(ABORT,'fixture'); END"))
                    root.check(!RemoteRepository.save(Object.assign({},renamed,{name:'Broken'})),'failed write rejected')
                    root.check(DbService.read('SELECT name FROM remotes WHERE id=?',[renamed.id])[0].name==='Renamed','failed update rolls back')
                    DbService.write(tx=>tx.executeSql('DROP TRIGGER store.reject_remote_update'))
                    RemoteService.newEntry(); RemoteService.save(Object.assign(Entries.empty(),{name:'alpha',type:'vm',endpoint:'127.0.0.1',vmName:'fixture'}))
                    root.check(!!RemoteService.error && RemoteRepository.entries.length===4,'case-insensitive duplicates rejected')
                    RemoteService.cancel(); RemoteService.remove(renamed.id)
                    root.check(RemoteRepository.entries.length===3,'remove saved entry')
                    PickerService.remotes(); PickerService.query='Disabled'
                    root.check(!PickerService.filteredItems.length,'disabled entry cannot launch')
                    PickerService.query='Alpha'; PickerService.accept(false,false)
                    root.check(!PickerService.visible,'accept dispatches and dismisses')
                    root.step=4; break
                }
                case 4:
                    RemoteService.request()
                    if(RemoteService.sessions[0]?.state!=='running')return
                    PickerService.remotes(); PickerService.query='Alpha'; root.step=5; break
                case 5: {
                    const disconnect=objects.findChild(panel,'remoteDisconnect') as UI.ActionButton
                    const shutdown=objects.findChild(panel,'remoteShutdown') as UI.ActionButton
                    root.check(!!disconnect && disconnect.enabled && shutdown.visible,'selected connection actions available')
                    root.check(PickerService.acceptLabel==='Disconnect','Enter hint describes running selection')
                    panel.focusSearch(); events.keyClick(Qt.Key_R,Qt.ControlModifier | Qt.ShiftModifier,0)
                    root.step=51; break
                }
                case 51: {
                    const running=objects.findChild(panel,'remoteRunningOnly') as UI.ActionButton
                    root.check(RemoteService.activeOnly && running.checked,'Ctrl+Shift+R enables the checked running filter')
                    root.check(PickerService.items.length===1,'running filter excludes idle hosts')
                    PickerService.query='Beta'; root.check(!PickerService.filteredItems.length,'search composes with running filter')
                    PickerService.query='Alpha'
                    const active=RemoteRepository.entries.find(entry=>entry.name==='Alpha')
                    root.check(RemoteRepository.save(Object.assign({},active,{enabled:false,category:'work'})),'disable active record and change its category')
                    root.check(PickerService.filteredItems.length===1 && RemoteService.selectedEntry?.id===active.id,'active connection remains selectable across disabled/status filtering')
                    root.check(!panel.panel.canRemoveEntry(active),'active connection cannot be deleted')
                    RemoteService.shutdownSelected()
                    root.step=6; break
                }
                case 6:
                    console.log('PASS: remotes shared Manage focus, CRUD, masked secrets, rollback and owned launch')
                    Qt.quit(); break
                case 8:
                    RemoteService.request()
                    if(RemoteService.sessions[0]?.state!=='running')return
                    root.check(RemoteService.sessions.length===1,'detached connection recovered after bar restart')
                    root.check(!RemoteService.activeOnly,'running filter resets each opening')
                    PickerService.query='Beta'; PickerService.accept(false,false); root.step=81; break
                case 81:
                    RemoteService.request()
                    if(RemoteService.sessions.length!==2 || RemoteService.sessions.some(session=>session.state!=='running'))return
                    PickerService.remotes(); PickerService.query=''; panel.focusSearch()
                    events.keyClick(Qt.Key_R,Qt.ControlModifier | Qt.ShiftModifier,0); root.step=82; break
                case 82:
                    root.check(RemoteService.activeOnly && PickerService.items.length===2,'running filter includes both owned clients')
                    root.check(PickerService.acceptLabel==='Disconnect','Enter hint follows the selected running row')
                    RemoteService.request()
                    panel.focusSearch(); events.keyClick(Qt.Key_Return,Qt.NoModifier,0)
                    root.check(PickerService.visible,'Enter disconnect keeps picker open')
                    root.check(PickerService.items.length===1 && PickerService.currentItem?.title==='Beta','disconnecting row leaves running filter immediately')
                    events.keyClick(Qt.Key_Return,Qt.NoModifier,0)
                    root.check(!PickerService.items.length,'rapid second Enter acts on next running connection')
                    root.step=84; break
                case 84:
                    RemoteService.request()
                    if(RemoteService.sessions.length)return
                    root.check(PickerService.visible && RemoteService.activeOnly && !PickerService.items.length,'empty running list stays open after sequential disconnects')
                    RemoteService.toggleActiveOnly()
                    root.check(PickerService.items.length===1 && PickerService.acceptLabel==='Connect','idle entries and Connect hint return after clearing filter')
                    console.log('PASS: remotes restart, running filter, keyboard toggle and sequential Enter disconnects')
                    Qt.quit(); break
                case 20:
                    RemoteService.request()
                    if(root.ticks<7 || RemoteService.sessions[0]?.state!=='connecting')return
                    PickerService.remotes(); PickerService.query=''; panel.focusSearch()
                    events.keyClick(Qt.Key_R,Qt.ControlModifier | Qt.ShiftModifier,0); root.step=21; break
                case 21:
                    root.check(RemoteService.activeOnly && PickerService.items.length===1 && PickerService.acceptLabel==='Disconnect','connecting session appears in running filter with Disconnect action')
                    events.keyClick(Qt.Key_Return,Qt.NoModifier,0); root.step=22; break
                case 22:
                    RemoteService.request()
                    if(RemoteService.sessions.length)return
                    root.check(PickerService.visible && !PickerService.items.length,'Enter cancels connecting session and keeps picker open')
                    console.log('PASS: remotes Enter cancels connecting session in running-only view')
                    Qt.quit(); break
            }
        }
    }
}
