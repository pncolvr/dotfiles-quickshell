pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/services"
import "../../src/modules/launcher"
import "../../src/theme/ui" as UI
import "../../src/services/webapps/WebappEntries.mjs" as Entries
Scope {
    id: root
    property bool failed: false
    property int step:0
    property int ticks:0
    readonly property bool restarting: Quickshell.env('WEBAPP_TEST_PHASE') === 'restart'
    Test.TestEvent { id: events }
    Test.TestResult { id: objects }
    FloatingWindow {
        id: window
        visible:true; implicitWidth:650; implicitHeight:650
        PickerPanel { id:panel; anchors.fill:parent }
    }
    function check(value,message) { if (!value) { failed=true; console.error('WEBAPP FAIL:',message) } }
    function field(name) { return objects.findChild(panel,name) as UI.InputField }
    Timer {
        interval:80; running:true; repeat:true
        onTriggered: {
            if (root.failed || ++root.ticks>150) { console.error('WEBAPP FAIL: stopped',root.step,WebappService.error); Qt.quit(); return }
            if (!DbService.ready || WebappService.busy) return
            switch(root.step) {
                case 0:
                    PickerService.webapps()
                    root.check(PickerService.visible && PickerService.mode===PickerService.Mode.Webapps,'native Webapps IPC mode')
                    if (root.restarting) {
                        root.check(WebappRepository.entries.length===3,'CRUD survives restart without legacy files')
                        root.check(WebappRepository.entries.find(e=>e.name==='Window').profile==='qutebrowser-webapp','profile survives restart')
                        root.step=12; return
                    }
                    root.check(!WebappRepository.entries.length,'fresh collection starts empty')
                    for (const entry of [
                        {name:'Window',browser:'qutebrowser',profile:'qutebrowser-webapp',windowMode:'normal',url:'https://example.test/window?x=1&y=2'},
                        {name:'App',browser:'vivaldi',profile:'Test Profile',windowMode:'app',url:'https://example.test/app'},
                        {name:'Hook',enabled:false,url:'https://example.test/disabled'}
                    ]) root.check(WebappRepository.save(Object.assign(Entries.empty(),entry)),'seed managed webapp')
                    WebappService.setManaging(true)
                    root.check(PickerService.items.length===2,'disabled entries excluded from launch list')
                    root.step=2; break
                case 2:
                    root.check(panel.panel instanceof ManagedCollectionPanel,'shared management component')
                    root.check(!objects.findChild(panel,'collectionImportPath') && !objects.findChild(panel,'previewCollectionImport'),'Manage has no import controls')
                    panel.panel.beginAdd()
                    root.step=3; break
                case 3:
                    root.check(root.field('webappName')!==null,'shared form loaded')
                    panel.focusSearch()
                    events.keyClick(Qt.Key_T,Qt.NoModifier,0)
                    root.check(root.field('webappName').text==='t','new-entry name accepts keyboard input')
                    const profiles=objects.findChild(panel,'webappProfileSelector') as UI.ComboSelector
                    const browsers=objects.findChild(panel,'webappBrowserSelector') as UI.ComboSelector
                    root.check(!!profiles && profiles.options[1].description==='Webapps','profile combo uses configured names')
                    const windows=objects.findChild(panel,'webappWindowSelector') as UI.ComboSelector
                    root.check(windows.options[0].description==='Reuse profile window','Qutebrowser reuse mode has a clear label')
                    windows.selected('window')
                    root.check(panel.panel.entryForm.value().windowMode==='window','explicit new-window mode remains available')
                    windows.selected('normal')
                    profiles.selected('qutebrowser-webapp')
                    root.check(panel.panel.entryForm.value().profile==='qutebrowser-webapp','selected profile enters draft')
                    browsers.selected('vivaldi')
                    root.check(profiles.selectedName==='' && profiles.options.length===3 && profiles.options[1].description==='Work','browser switch resets incompatible profile and updates options')
                    profiles.selected('Test Profile')
                    root.check(panel.panel.entryForm.value().profile==='Test Profile','configured profile is saved as its stable ID')
                    for (const id of ['webappEnabled','webappAdvanced']) {
                        const button=objects.findChild(panel,id) as UI.ActionButton
                        root.check(button.width>=button.implicitContentWidth,'text control fits its label: '+id)
                    }
                    const category=objects.findChild(panel,'webappCategorySelector') as UI.ComboSelector
                    root.check(!!category && category.visible && !panel.panel.entryForm.advanced,'category dropdown is visible outside Advanced')
                    root.check(category.selectedName==='personal' && category.options.map(option=>option.name).join(',')==='personal,work','category offers Personal and Work')
                    category.selected('work')
                    root.check(panel.panel.entryForm.value().category==='work','category choice enters the draft')
                    root.field('webappName').text='Added'
                    root.field('webappUrl').text='https://example.test/new?a=1&b=2'
                    panel.panel.submit()
                    root.check(WebappRepository.entries.length===4 && !WebappService.draft,'add saves and exits edit mode')
                    root.step=4; break
                case 4: {
                    const entry=WebappRepository.entries.find(entry=>entry.name==='Added')
                    root.check(entry.category==='work','selected category is saved')
                    panel.panel.edit(entry)
                    root.step=5; break
                }
                case 5:
                    root.check((objects.findChild(panel,'webappProfileSelector') as UI.ComboSelector).selectedName==='Test Profile','editing restores configured profile selection')
                    const editedCategory=objects.findChild(panel,'webappCategorySelector') as UI.ComboSelector
                    root.check(editedCategory.selectedName==='work','editing restores category selection')
                    const profileSelector=objects.findChild(panel,'webappProfileSelector') as UI.ComboSelector
                    panel.panel.entryForm.load(Object.assign({},WebappService.draft,{profile:'Removed Profile'}))
                    root.check(profileSelector.selectedName==='Removed Profile' && profileSelector.selectedDescription==='Profile unavailable — choose another','unavailable saved profile is shown without resetting it')
                    panel.panel.submit()
                    root.check(!!WebappService.error && !!WebappService.draft,'saving an unavailable profile is rejected without discarding the draft')
                    profileSelector.selected('Test Profile')
                    editedCategory.selected('personal')
                    root.field('webappName').text='Renamed'
                    panel.panel.submit()
                    root.check(WebappRepository.entries.some(e=>e.name==='Renamed' && e.category==='personal'),'editing and personal category persist')
                    const renamed=WebappRepository.entries.find(entry=>entry.name==='Renamed')
                    root.check(DbService.write(tx=>tx.executeSql("CREATE TRIGGER store.reject_webapp_update BEFORE INSERT ON webapps WHEN NEW.name='Broken' BEGIN SELECT RAISE(ABORT,'fixture'); END")),'install failure fixture')
                    root.check(!WebappRepository.save(Object.assign({},renamed,{name:'Broken'})),'failed update is rejected')
                    root.check(DbService.read('SELECT name FROM webapps WHERE id=?',[renamed.id])[0].name==='Renamed','failed update preserves the saved entry')
                    DbService.write(tx=>tx.executeSql('DROP TRIGGER store.reject_webapp_update'))
                    WebappService.newEntry()
                    WebappService.save(Object.assign(Entries.empty(),{name:'window',url:'https://example.test'}))
                    root.check(!!WebappService.error && WebappRepository.entries.length===4,'duplicate names rejected without data loss')
                    WebappService.cancel()
                    WebappService.remove(WebappRepository.entries.find(e=>e.name==='Renamed').id)
                    root.check(WebappRepository.entries.length===3,'remove entry')
                    WebappService.setManaging(false)
                    PickerService.query='Window'
                    PickerService.accept(false,false)
                    root.check(!PickerService.visible,'Enter launches selected webapp and closes picker')
                    root.step=6; break
                case 6:
                    PickerService.webapps()
                    PickerService.query='App'
                    PickerService.accept(false,false)
                    root.step=7; break
                case 7:
                    PickerService.webapps()
                    PickerService.query='Hook'
                    root.check(PickerService.filteredItems.length===0,'disabled record stays unavailable')
                    PickerService.close()
                    WebappService.newEntry()
                    WebappService.save(Object.assign(Entries.empty(),{name:'Before hook',url:'https://example.test/hook',
                        before:[Quickshell.env('WEBAPP_TEST_DIR')+'/bin/beforetest','literal $(not-executed)'],
                        after:[Quickshell.env('WEBAPP_TEST_DIR')+'/bin/aftertest','literal;argument']}))
                    PickerService.webapps(); PickerService.query='Before hook'; PickerService.accept(false,false)
                    root.step=8; break
                case 8:
                    WebappService.newEntry()
                    WebappService.save(Object.assign(Entries.empty(),{name:'Failed hook',url:'https://example.test/must-not-open',
                        before:[Quickshell.env('WEBAPP_TEST_DIR')+'/bin/beforetest','fail']}))
                    PickerService.webapps(); PickerService.query='Failed hook'; PickerService.accept(false,false)
                    root.step=9; break
                case 9:
                    root.check(!!WebappService.error,'failed before command reports an error')
                    for (const name of ['Before hook','Failed hook']) WebappService.remove(WebappRepository.entries.find(e=>e.name===name).id)
                    root.step=12; break
                case 12:
                    if (!root.failed) console.log('PASS: webapps shared Manage focus, CRUD, disabled entries and restart')
                    Qt.quit(); break
            }
        }
    }
}
