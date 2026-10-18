pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/config"
import "../../src/theme"
import "../../src/modules/launcher"
import "../../src/ui" as UI
import "../../src/services/browser/BrowserRouting.mjs" as Routing

Scope {
    id:root
    readonly property var settings:Config
    readonly property var browser:BrowserRoutingService
    property bool started:false
    Test.TestCase { id:events; when:false }
    Test.TestResult { id:objects }
    FloatingWindow { visible:true; implicitWidth:800; implicitHeight:700; PickerPanel { id:panel; anchors.fill:parent } }
    FileView { id:actions; path:Quickshell.env('BROWSER_TEST_DIR')+'/actions'; blockLoading:true; printErrors:false }
    function setOption(key,value) { settings[key]=value }
    function check(ok: bool,message: string): void { if(!ok) throw new Error(message) }
    function waitFor(predicate: var,message: string): void {
        const deadline=Date.now()+3000
        while(!predicate() && Date.now()<deadline) events.wait(10)
        check(predicate(),message)
    }
    function calls() { actions.reload(); return actions.text().trim().split('\n').filter(value=>value).map(value=>JSON.parse(value)) }
    function settled() { return !browser.requests.length && !browser.currentRequest && !browser.launchQueue.length && !browser.launching }
    function serviceLinks(recorded) {
        const date = new Date(2026, 0, 15)
        const update = {repository: 'extra', architecture: 'x86_64', name: 'fixture-package'}
        const saved = {emitterKey: 'app:twitch', actionHandler: 'twitch', actions: [{identifier: 'open-twitch', text: 'Open'}]}
        const links = [
            {url: Config.twitchBaseUrl + 'fixture_channel', open: () => TwitchService.openUrl('fixture_channel')},
            {url: Config.twitchBaseUrl, open: () => check(NotificationService.invoke(saved, 'open-twitch'), 'saved Twitch action accepted')},
            {url: CalendarService.eventUrlFor(date), open: () => CalendarService.openDate(date)},
            {url: UpdatesService.packageUrl(update), open: () => UpdatesService.openPackage(update)}
        ]
        const history = JSON.stringify(BrowserRoutingRepository.history())
        for (const link of links) {
            const before = calls().length
            link.open()
            waitFor(() => calls().length === before + 1 && settled(), 'service browser link dispatched')
            check(calls()[before][0] === '--browser=b' && calls()[before].slice(-1)[0] === link.url,
                'service link uses the configured browser and literal target without desktop integration')
            if (recorded) check(BrowserRoutingRepository.history().some(row => row.url === link.url), 'service link recorded')
        }
        if (!recorded) check(JSON.stringify(BrowserRoutingRepository.history()) === history, 'disabled routing does not record service links')
    }
    function run() {
        if(started || !DbService.ready) return
        started=true
        try {
            check(DbService.schemaVersion===16,'schema migrated')
            if(Quickshell.env('BROWSER_TEST_PHASE')==='restart') {
                check(browser.defaultBrowser===Config.webappDefaultBrowser && browser.entries.length===1 && browser.entries[0].id==='work','configured default and saved rules apply after restart')
                check(BrowserRoutingRepository.history('persisted').length===1,'history and FTS survive restart')
                check(BrowserRoutingRepository.history('persisted')[0].rule_name==='Saved rule','matched rule name survives restart')
                check(BrowserRoutingRepository.history('persisted')[0].final_url==='https://resolved.test/persisted','final URL survives restart separately from original')
                BrowserRoutingRepository.clearHistory()
                console.log('PASS: browser default comes from Config after restart; rules, history and FTS survive')
                Qt.quit()
                return
            }
            BrowserRoutingRepository.clearHistory()
            check(PreferencesRepository.setValue('browser.defaultBrowser','a'),'seed obsolete saved browser preference')
            check(browser.defaultBrowser==='b','configured default ignores obsolete saved preference')
            setOption('webappDefaultBrowser','a')
            check(browser.defaultBrowser==='a','default follows changes in Config')
            setOption('webappDefaultBrowser','b')
            check(BrowserRoutingRepository.save(Object.assign(Routing.empty('a'),{id:'work',name:'Work',pattern:'work.test',match:'host',profile:'work'})),'save route')
            check(browser.open('https://sub.work.test/hello'),'accept routed request')
            waitFor(()=>calls().length===1 && settled(),'dispatch first browser')
            check(calls()[0][0]==='--profile=work','route uses selected profile')
            check(BrowserRoutingRepository.history()[0].rule_name==='Work','history records matched browser rule')
            check(browser.open('/tmp/Local page.html'),'accept local HTML')
            waitFor(()=>calls().length===2 && settled(),'dispatch local page')
            check(calls()[1][calls()[1].length-1]==='file:///tmp/Local%20page.html','local target encoded as one argument')
            check(BrowserRoutingRepository.history().length===2,'record distinct URLs')
            check(BrowserRoutingRepository.history().find(row=>row.url.startsWith('file:')).rule_name==='','default browser history has no matched rule label')
            check(BrowserRoutingRepository.record('https://sub.work.test/hello','a'),'record existing URL')
            check(BrowserRoutingRepository.history().length===2 && BrowserRoutingRepository.history()[0].url==='https://sub.work.test/hello','deduplicate and move repeated URL to the top')
            check(BrowserRoutingRepository.history('sub work').length===1,'FTS URL token search')
            check(BrowserRoutingRepository.history('" OR *').length===0,'FTS operator input stays data')
            BookmarkService.launch([{result:'https://bookmark-handoff.test/'}])
            waitFor(()=>calls().length===3 && settled(),'bookmark command hands off to this routing session')
            setOption("browserHistoryEnabled",false)
            browser.open('https://unrecorded.test/')
            waitFor(()=>calls().length===4 && settled(),'dispatch without recording')
            check(BrowserRoutingRepository.history().length===3,'history opt-out preserves existing rows')
            setOption("browserHistoryEnabled",true)
            setOption("browserHistoryLimit",1)
            check(BrowserRoutingRepository.history().length===1,'smaller limit trims existing rows')
            setOption("browserRoutingEnabled",false)
            browser.open('https://sub.work.test/fallback')
            waitFor(()=>calls().length===5 && settled(),'dispatch disabled fallback')
            check(calls()[4][0]!=='--profile=work' && BrowserRoutingRepository.history().length===1,'disabled feature bypasses routes/history')
            setOption("browserRoutingEnabled",true)
            const transformRules=[
                Object.assign(Routing.empty(''),{id:'unwrap',name:'Unwrap',pattern:'wrapped.test',match:'host',action:'query',parameter:'destination'}),
                Object.assign(Routing.empty(''),{id:'jump',name:'Redirect',pattern:'jump.test',match:'host',action:'redirect'}),
                Object.assign(Routing.empty(''),{id:'app',name:'Application',pattern:'^https://application.test/item/([0-9]+)',match:'regex',action:'command',desktopId:'fixture-application',targetTemplate:'fixture://item/{1}',command:[Quickshell.env('BROWSER_TEST_DIR')+'/bin/browser','--item={1}','{url}']})
            ]
            for(const rule of transformRules) check(BrowserRoutingRepository.save(rule),'save configurable action')
            browser.open('https://jump.test/link')
            waitFor(()=>calls().length===6 && settled(),'redirect and query rules chain before browser selection')
            check(calls()[5][0]==='--profile=work' && calls()[5][calls()[5].length-1]==='https://sub.work.test/redirected','transformed URL selects final browser rule')
            check(BrowserRoutingRepository.history()[0].rule_name==='Redirect → Unwrap → Work','history retains the matched transformation chain')
            check(BrowserRoutingRepository.history()[0].url==='https://jump.test/link'
                && BrowserRoutingRepository.history()[0].final_url==='https://sub.work.test/redirected','history retains the original and final URLs separately')
            browser.open('https://application.test/item/42')
            waitFor(()=>calls().length===7 && settled(),'generic application rule dispatches')
            check(calls()[6][0]==='--item=42','regex capture expands as one literal argument')
            check(calls()[6].slice(-1)[0]==='fixture://item/42','selected application receives the configured capture-based target')
            setOption('browserHistoryLimit',2)
            check(BrowserRoutingRepository.record('https://default.test/a-long-original-address','b'),'seed a history row without a matching rule')
            browser.open('https://jump.test/cycle-a')
            waitFor(()=>calls().length===8 && settled(),'redirect cycle falls back instead of reopening indefinitely')
            for(const rule of transformRules) check(BrowserRoutingRepository.remove(rule.id),'remove action fixture')
            BookmarkService.open()
            waitFor(()=>!!panel.panel && PickerService.items.length===2,'bookmarks load with tabbed panel')
            check(panel.dismissOnOutside && !PickerService.privateWindow,'Bookmarks retains ordinary public picker dismissal')
            check(objects.findChild(panel,'browserRoutingDefault')===null,'Manage has no separate default-browser override')
            events.keyClick(Qt.Key_H,Qt.ControlModifier)
            waitFor(()=>BookmarkService.tab===1,'Ctrl+H opens Bookmarks History')
            check(panel.dismissOnOutside,'History retains outside dismissal')
            check(PickerService.items.length===2,'history tab publishes retained URLs')
            check(PickerService.items[0].title==='https://jump.test/cycle-a' && PickerService.items[0].result===PickerService.items[0].title,'history displays and opens the original URL')
            check(PickerService.items[0].hint.includes('https://jump.test/cycle-b') && PickerService.items[0].hint.includes('Redirect'),'history tooltip includes final URL and matched rules')
            check(!!PickerService.items[0].annotation,'history row publishes stored rule names after rules are removed')
            const historyList=objects.findChild(panel,'pickerList') as UI.PickerList
            waitFor(()=>!!historyList.itemAtIndex(0) && !!historyList.itemAtIndex(1),'history rows are rendered')
            check(historyList.rowHeight>0 && historyList.itemAtIndex(0).height===historyList.itemAtIndex(1).height,'history rows have identical two-line heights with or without matched rules')
            const annotation=objects.findChild(historyList.itemAtIndex(0),'pickerRowAnnotation') as UI.Text
            check(annotation.text.replace(/<[^>]+>/g,'').split(Theme.rightIcon).join('→')===PickerService.items[0].annotation
                && annotation.color.toString()===Theme.selectionText.toString(),'selected history rule name uses configured arrow and selection text color')
            const url=PickerService.currentItem.result
            BookmarkService.setTab(2); browser.ruleForUrl(url)
            check(!panel.dismissOnOutside && !PickerService.privateWindow,'routing Manage persists outside the public picker without using the private namespace')
            waitFor(()=>!!browser.draft,'new rule draft from history')
            check(browser.draft.pattern===url && browser.managing,'history becomes editable routing rule')
            const containsInput=objects.findChild(panel,'browserRouteContains') as UI.TextArea
            check(containsInput.visible && containsInput.text===url,'shared editor loads the generated rule into the Contains list')
            const actionSelector=objects.findChild(panel,'browserRouteAction') as UI.ComboSelector
            actionSelector.selected('query')
            check(actionSelector.selectedName==='query' && (objects.findChild(panel,'browserRouteParameter') as UI.InputField).visible,'Manage selects query action and shows parameter')
            actionSelector.selected('command')
            check(actionSelector.selectedName==='command' && (objects.findChild(panel,'browserRouteCommand') as UI.InputField).visible,'Manage selects application action and shows command')
            const form=objects.findChild(panel,'browserRoutingForm') as BrowserRoutingForm
            const commandInput=objects.findChild(panel,'browserRouteCommand') as UI.InputField
            const commandField=commandInput.parent as UI.LabeledField
            const customCommand="'custom-browser' '{url}' '{1}'"
            commandInput.text=customCommand
            containsInput.text='first.test\n\nsecond.test'
            check(JSON.stringify(form.value().patterns)===JSON.stringify(['first.test','second.test']),'Contains editor produces a list of values')
            containsInput.text=url
            check(commandField.label.includes('{url}') && commandField.label.includes('{1}') && commandField.hint.includes('{2}'),'custom command displays placeholders and their tooltip')
            waitFor(()=>form.applications.some(entry=>entry.id==='fixture-application'),'discover installed application desktop entry')
            const appSelector=objects.findChild(panel,'browserRouteApplication') as UI.ComboSelector
            check(appSelector.searchable,'application selector supports search')
            appSelector.expanded=true
            waitFor(()=>appSelector.popup.opened && appSelector.searchInput.activeFocus,'application search receives focus')
            appSelector.searchInput.text='Fixture Application'
            waitFor(()=>appSelector.choicesView.options.length===1 && appSelector.choicesView.currentIndex===0,'application search filters names')
            events.keyClick(Qt.Key_Return)
            check(appSelector.selectedName==='fixture-application' && !appSelector.expanded,'Enter chooses filtered application')
            const extra=objects.findChild(panel,'browserRouteExtraArguments') as UI.InputField
            check(commandInput.mapToItem(form,0,0).y < extra.mapToItem(form,0,0).y,'command precedes extra arguments')
            check(commandInput.readOnly && commandInput.color.toString()!==extra.color.toString(),'application command is read-only with distinct text styling')
            const targetTemplate=objects.findChild(panel,'browserRouteTargetTemplate') as UI.InputField
            check(targetTemplate.visible && !targetTemplate.readOnly && targetTemplate.text==='{url}','selected application defaults to an editable full-URL target')
            targetTemplate.text='custom://item/{1}'
            check(commandInput.readOnly && commandInput.text.includes('custom://item/{1}'),'read-only command preview follows target template')
            check(form.value().targetTemplate==='custom://item/{1}' && form.value().command.includes('{url}'),'form saves target template separately from the application base command')
            targetTemplate.text='{url}'
            extra.text="'--profile=Personal Profile'"
            const selectedApplication=form.value()
            check(selectedApplication.desktopId==='fixture-application' && selectedApplication.applicationName==='Fixture Application','Manage retains application identity')
            check(selectedApplication.extraArguments[0]==='--profile=Personal Profile' && selectedApplication.command.includes('--desktop'),'Manage retains command and optional literal arguments')
            const runningOnly=objects.findChild(panel,'browserRouteOnlyWhenRunning') as UI.CheckBox
            check(!runningOnly.checked && form.value().onlyWhenRunning==='','process guard defaults off')
            runningOnly.checked=true
            check(form.value().onlyWhenRunning==='browser','checked process guard uses application executable name')
            runningOnly.checked=false
            check(form.value().onlyWhenRunning==='','unchecked process guard clears condition')
            appSelector.selected('')
            check(!commandInput.readOnly && commandInput.text===customCommand,'returning to custom restores the editable command draft')
            check(!targetTemplate.visible,'custom command retains direct control of its own target arguments')
            check(commandField.label.includes('{url}') && commandField.label.includes('{1}') && commandField.hint.includes('{2}'),'returning to custom restores placeholder label and help')
            check(commandInput.color.toString()===extra.color.toString(),'returning to custom restores editable styling')
            const missingRule=Object.assign(Routing.empty('a'),{id:'removed-app',name:'Removed',pattern:'removed.test',match:'host',action:'command',desktopId:'uninstalled.fixture',applicationName:'Removed Application',command:[Quickshell.env('BROWSER_TEST_DIR')+'/bin/browser','--should-not-launch','{url}']})
            check(BrowserRoutingRepository.save(missingRule),'save removed desktop application rule')
            const previousCalls=calls().length
            browser.open('https://removed.test/')
            waitFor(()=>calls().length===previousCalls+1 && settled(),'removed desktop entry uses default browser')
            check(calls()[previousCalls][0]==='--browser=b','missing app uses configured default browser')
            check(AlertService.messages.some(message=>message.text.includes('Removed Application')),'missing app alert names attempted application')
            check(BrowserRoutingRepository.remove(missingRule.id),'remove unavailable application fixture')
            browser.cancel()
            check(BrowserRoutingRepository.save(Object.assign(Routing.empty('b'),{name:'AAA later rule',patterns:['work.test','second-work.test'],match:'contains'})),'append a multi-value Contains rule')
            const later=browser.entries.find(entry=>entry.name==='AAA later rule')
            check(browser.entries[0].id==='work' && browser.entries[1].id===later.id,'new rule appends in execution order instead of alphabetical order')
            const manager=objects.findChild(panel,'browserRoutingManager') as ManagedCollectionPanel
            manager.managementView.select(later.id)
            const up=objects.findChild(panel,'browserRuleMoveUp') as UI.ActionButton
            const down=objects.findChild(panel,'browserRuleMoveDown') as UI.ActionButton
            check(up.enabled && !down.enabled,'last rule can move up but not down')
            up.clicked()
            check(browser.entries[0].id===later.id && manager.selectedEntry.id===later.id,'move up reorders rules and retains selection')
            check(!up.enabled && down.enabled,'first rule can move down but not up')
            check(Routing.choose('https://work.test/',browser.entries,Config.webappDefaultBrowser).id===later.id,'execution follows visible rule order')
            check(BrowserRoutingRepository.reload() && browser.entries[0].id===later.id,'moved order persists in storage')
            check(browser.entries[0].patterns.length===2 && Routing.matches(browser.entries[0],'https://second-work.test/'),'Contains values survive storage reload and each can match')
            down.clicked()
            check(browser.entries[0].id==='work' && browser.entries[1].id===later.id,'move down restores order')
            check(!BrowserRoutingRepository.move('work',-1) && !BrowserRoutingRepository.move(later.id,1),'boundary moves are rejected')
            check(BrowserRoutingRepository.remove(later.id),'remove ordering fixture')
            check(BrowserRoutingRepository.reload() && browser.entries[0].id==='work','saved routes persist')
            const textCalls=calls().length
            for(const text of ['www.google.com','search with spaces']) check(browser.open(text),'accept browser address-bar text')
            waitFor(()=>calls().length===textCalls+2 && settled(),'dispatch domain and search text')
            check(calls()[textCalls].slice(-1)[0]==='www.google.com' && calls()[textCalls+1].slice(-1)[0]==='search with spaces','browser receives unchanged domains and search text as single arguments')
            setOption('webappDefaultBrowser','a')
            const youtube='https://www.youtube.com/watch?v=3c0MnSBJqR4'
            const beforeYoutube=calls().length
            BookmarkService.launch([{result:youtube}])
            waitFor(()=>calls().length===beforeYoutube+1 && settled(),'wrapper hands unmatched YouTube URL to the router')
            check(BrowserRoutingRepository.history()[0].url===youtube && BrowserRoutingRepository.history()[0].rule_name==='','unmatched URL is recorded without a rule label')
            check(calls()[beforeYoutube][0]==='--target' && calls()[beforeYoutube].slice(-1)[0]===youtube,'default browser receives its reuse flags and the YouTube URL')
            setOption('webappDefaultBrowser','b')
            check(BrowserRoutingRepository.record('https://original.test/link','b','First','https://final.test/first'),'record original and final URL')
            const historyCount=BrowserRoutingRepository.history().length
            check(BrowserRoutingRepository.record('https://original.test/link','b','Renamed','https://final.test/second'),'update same original URL')
            check(BrowserRoutingRepository.history().length===historyCount && BrowserRoutingRepository.history()[0].url==='https://original.test/link'
                && BrowserRoutingRepository.history()[0].final_url==='https://final.test/second' && BrowserRoutingRepository.history()[0].rule_name==='Renamed','reopening original deduplicates and updates final URL and rule label')
            BrowserRoutingRepository.clearHistory()
            check(BrowserRoutingRepository.history().length===0,'clear history and FTS')
            serviceLinks(true)
            BrowserRoutingRepository.clearHistory()
            check(BrowserRoutingRepository.record('https://persisted.test/','b','Saved rule','https://resolved.test/persisted'),'seed persisted history')
            PickerService.close()
            setOption('bookmarkFile','')
            BookmarkService.open()
            waitFor(()=>PickerService.visible && PickerService.items.length===0,'empty bookmark source keeps routing tabs usable')
            BookmarkService.setTab(1)
            check(PickerService.items.length===1,'history remains available without bookmark source')
            BookmarkService.setTab(2)
            check(!PickerService.canAccept,'Manage does not launch a stale history selection')
            setOption('browserRoutingEnabled',false)
            check(!PickerService.visible,'disabling routing restores empty-source disabled behavior')
            serviceLinks(false)
            console.log('PASS: browser routing, profile/default/fallback, local HTML, history retention/FTS, opt-outs and shared bookmark tabs')
        } catch(exception) { console.error('BROWSER FAIL:',String(exception)) }
        Qt.callLater(() => Qt.quit())
    }
    Connections { target:DbService; function onReadyChanged() { Qt.callLater(root.run) } }
    Component.onCompleted:Qt.callLater(run)
}
