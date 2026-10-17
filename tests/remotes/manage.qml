pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/config"
import "../../src/services"
import "../../src/modules/launcher"
import "../../src/ui" as UI
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
    Process { id: restartVm; command: Config.remoteVmCommand.concat(['start','--','fixture-vm']) }
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
                    if(root.testPhase==='ssh') {
                        RemoteService.setManaging(true); root.step=30; return
                    }
                    if(root.testPhase==='sshrestart') { root.step=33; return }
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
                    root.check(!(objects.findChild(panel,'remoteRunningOnly') as UI.ActionButton).enabled,
                        'Running only is disabled without active sessions')
                    root.check(!RemoteService.canShutdownSelected,'stopped VM cannot be shut down')
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
                    if(!RemoteService.canShutdownSelected)return
                    const disconnect=objects.findChild(panel,'remoteDisconnect') as UI.ActionButton
                    const shutdown=objects.findChild(panel,'remoteShutdown') as UI.ActionButton
                    root.check(!!disconnect && disconnect.enabled && shutdown.visible && shutdown.enabled,'running VM actions available')
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
                    root.step=52; break
                }
                case 52:
                    if(!RemoteService.canShutdownSelected)return
                    RemoteService.shutdownSelected()
                    root.step=6; break
                case 6:
                    if(RemoteService.canShutdownSelected)return
                    root.check(RemoteService.sessions[0]?.state==='running'
                        && !(objects.findChild(panel,'remoteShutdown') as UI.ActionButton).enabled,
                        'shutdown is disabled for a stopped VM even while its RDP client remains listed')
                    restartVm.running=true
                    root.step=61; break
                case 61:
                    if(!RemoteService.canShutdownSelected)return
                    root.check((objects.findChild(panel,'remoteShutdown') as UI.ActionButton).enabled,
                        'shutdown becomes available when the selected VM starts outside Remotes')
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
                    root.check(!RemoteService.activeOnly,'last disconnect returns to the normal list')
                    root.step=84; break
                case 84:
                    RemoteService.request()
                    if(RemoteService.sessions.length)return
                    root.check(PickerService.visible && !RemoteService.activeOnly
                        && !(objects.findChild(panel,'remoteRunningOnly') as UI.ActionButton).enabled,
                        'normal list stays open with Running only disabled after the last session ends')
                    RemoteService.toggleActiveOnly()
                    panel.focusSearch(); events.keyClick(Qt.Key_R,Qt.ControlModifier | Qt.ShiftModifier,0)
                    root.check(!RemoteService.activeOnly && PickerService.items.length===1 && PickerService.acceptLabel==='Connect',
                        'disabled running action cannot hide idle entries')
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
                    root.check(PickerService.visible && !RemoteService.activeOnly && PickerService.items.length===2,
                        'Enter cancels the last connecting session and returns to the normal list')
                    console.log('PASS: remotes Enter cancels connecting session in running-only view')
                    Qt.quit(); break
                case 30: {
                    panel.panel.beginAdd()
                    const form=panel.panel.entryForm
                    form.load(Entries.empty())
                    const jump=objects.findChild(panel,'remoteJumpToggle') as QC.ItemDelegate
                    root.check(!jump.checked && !root.field('remoteHop').visible,'RDP jump group starts collapsed')
                    jump.forceActiveFocus(Qt.TabFocusReason); events.keyClick(Qt.Key_Return,Qt.NoModifier,0)
                    root.check(jump.checked && root.field('remoteHop').visible && root.field('remoteKey').visible,
                        'keyboard disclosure reveals the RDP jump fields')
                    const type=objects.findChild(panel,'remoteTypeSelector') as UI.ComboSelector
                    type.selected('ssh')
                    root.check(root.field('remotePort').text==='22','switching to SSH defaults to port 22')
                    root.field('remoteName').text='Direct SSH'
                    root.field('remoteEndpoint').text='direct.example'
                    root.field('remoteHop').text=''
                    root.field('remoteHopPort').text=''
                    panel.panel.submit()
                    const direct=RemoteRepository.entries.find(entry=>entry.name==='Direct SSH')
                    root.check(!!direct && !direct.hopHost && direct.hopPort===22,
                        'SSH saves without a jump host or jump-host port')
                    RemoteService.remove(direct.id)
                    panel.panel.beginAdd()
                    form.load(Object.assign(Entries.empty([], 'ssh'),{name:'SSH test',endpoint:'server.example',username:'test',
                        password:'destination secret',sshKeyPath:'~/target key',hopHost:'jump.example',hopPort:2200,
                        hopUsername:'jump',hopPassword:'jump secret',hopKeyPath:'/jump key',sshArguments:['-o','ServerAliveInterval=30']}))
                    root.step=31; break
                }
                case 31: {
                    const jump=objects.findChild(panel,'remoteJumpToggle') as QC.ItemDelegate
                    root.check(!jump.checked && !root.field('remoteHop').visible,'SSH jump group starts collapsed')
                    jump.forceActiveFocus(Qt.TabFocusReason); events.keyClick(Qt.Key_Space,Qt.NoModifier,0)
                    root.check(jump.checked && root.field('remoteHop').visible && root.field('remoteHopKey').visible,
                        'Space reveals the SSH jump fields')
                    const password=objects.findChild(panel,'remotePassword') as UI.SecretField
                    const hopPassword=objects.findChild(panel,'remoteHopPassword') as UI.SecretField
                    root.check(password.echoMode===TextInput.Password && hopPassword.echoMode===TextInput.Password,
                        'destination and jump passwords are masked')
                    root.check(root.field('remoteTargetKey').visible && !root.field('remoteVm').visible,
                        'SSH has destination keys without VM fields')
                    panel.panel.submit()
                    const saved=RemoteRepository.entries.find(entry=>entry.name==='SSH test')
                    root.check(saved?.hopPort===2200 && saved.hopPassword==='jump secret' && saved.password==='destination secret'
                        && saved.sshArguments[1]==='ServerAliveInterval=30','SSH form saves destination and jump settings')
                    root.check(password.readOnly && hopPassword.readOnly,'SSH details retain masked read-only fields')
                    root.check(!jump.checked && !root.field('remoteHop').visible,'saved details start with the jump group collapsed')
                    RemoteService.setManaging(false)
                    PickerService.query='SSH test'; PickerService.accept(false,false)
                    root.step=32; break
                }
                case 32:
                    RemoteService.request()
                    if(RemoteService.sessions[0]?.state!=='running')return
                    console.log('PASS: remotes SSH form, default port, independent masked credentials, saved fields and terminal launch')
                    Qt.quit(); break
                case 33: {
                    RemoteService.request()
                    if(RemoteService.sessions[0]?.state!=='running')return
                    const saved=RemoteRepository.entries.find(entry=>entry.name==='SSH test')
                    root.check(saved?.hopPassword==='jump secret' && saved.sshKeyPath==='~/target key','SSH fields survive restart')
                    PickerService.query='SSH test'; RemoteService.toggleActiveOnly()
                    root.check(PickerService.filteredItems.length===1 && PickerService.currentItem.subtitle.startsWith('SSH terminal running')
                        && PickerService.acceptLabel==='Disconnect','running SSH is recovered and controlled after restart')
                    PickerService.accept(false,false); root.step=34; break
                }
                case 34:
                    RemoteService.request()
                    if(RemoteService.sessions.length)return
                    root.check(PickerService.visible && !RemoteService.activeOnly && PickerService.filteredItems.length===1,
                        'SSH disconnect restores the normal list and disables Running only')
                    console.log('PASS: remotes SSH restart, saved jump settings, running-only filtering and Disconnect')
                    Qt.quit(); break
            }
        }
    }
}
