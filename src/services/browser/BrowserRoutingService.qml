pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io
import "../"
import "../launcher"
import "../../config"
import "../../i18n"
import "BrowserRouting.mjs" as Routing

ManagedCollectionService {
    id: root
    repository: BrowserRoutingRepository
    pickerMode: PickerService.Mode.Menu
    collectionName: Translations.text('browser.routing.rules')
    itemForEntry: entry=>({id:entry.id,title:entry.name,result:entry})
    readonly property bool enabled: Config.browserRoutingEnabled
    readonly property string defaultBrowser: Config.defaultBrowserId
    property var requests: []
    property var currentRequest: null
    property string response: ''
    property string dispatchResponse: ''
    property var launchQueue: []
    property var launching: null
    // Bookmarks owns this Menu session's rows; editing routes must not replace them.
    function syncPicker() {}
    function newEntry() { edit(Routing.empty(defaultBrowser)) }
    function ruleSubtitle(entry) { return entry.match==='contains' ? Routing.containsPatterns(entry).join(', ') : entry.pattern }
    function moveEntry(id,direction) {
        if (busy || draft) return
        if (!repository.move(id,direction)) error=repository.error
    }
    function ruleForUrl(url) {
        const value=Routing.empty(defaultBrowser)
        value.name=url; value.pattern=url; value.match='contains'
        edit(value)
    }
    function open(url) {
        let normalized
        try { normalized=Routing.target(url) }
        catch(exception) { error=Translations.message(exception); return false }
        if (!enabled) return launch(normalized,false)
        if (!DbService.ready || DbService.maintenance || requests.length>=100) return false
        requests=requests.concat([normalized])
        next()
        return true
    }
    function next() {
        if (currentRequest || resolver.running || !requests.length) return
        const url=requests[0]
        requests=requests.slice(1)
        currentRequest={url,originalUrl:url,rules:JSON.parse(JSON.stringify(entries)),used:[],visited:[url],steps:0,rule:null,ruleNames:[]}
        advance()
    }
    function advance() {
        const request=currentRequest
        if (!request || !enabled) return
        const entry=Routing.choose(request.url,request.rules,defaultBrowser,request.used)
        if (!['redirect','query'].includes(Routing.action(entry))) { finish(entry); return }
        // Bound rule chains and retry unchanged targets only through other rules.
        if (request.steps>=8) { finish(Routing.browserRule(request.url,request.rules,defaultBrowser)); return }
        try { request.rule=Routing.validate(entry,Config.browsers) }
        catch(exception) { error=Translations.message(exception); finish(Routing.browserRule(request.url,request.rules,defaultBrowser)); return }
        request.steps++
        response=''; resolver.stdinEnabled=true; resolver.running=true
    }
    function finish(entry) {
        const request=currentRequest
        currentRequest=null
        if (request && enabled) launch(request.url,true,entry,request.rules,request.ruleNames,request.originalUrl)
        Qt.callLater(next)
    }
    function launch(url,routing=true,selected=null,rules=entries,transformationNames=[],originalUrl=url) {
        try {
            const entry=selected ?? (routing ? Routing.choose(url,rules,defaultBrowser) : Routing.empty(Config.defaultBrowserId))
            if (routing) Routing.validate(Object.assign({},entry,{name:entry.name || 'Default',pattern:entry.pattern || '*'}),Config.browsers)
            const argv=routing ? Routing.command(url,entry,Config.browsers)
                : Routing.concreteCommand(Config.defaultBrowserCommand).concat(url.startsWith('-') ? ['--',url] : [url])
            const fallback=Routing.browserRule(url,rules,defaultBrowser)
            const application=routing && Routing.action(entry)==='command'
            const defaultEntry=Routing.empty(defaultBrowser)
            launchQueue=launchQueue.concat([{url,originalUrl,argv,workspace:entry.workspace,
                focusWorkspace:routing && Config.browserWorkspaceFocusEnabled,
                onlyWhenRunning:application ? entry.onlyWhenRunning : '',
                fallbackArgv:application ? Routing.command(url,fallback,Config.browsers) : argv,
                fallbackBrowser:fallback.browser,fallbackWorkspace:fallback.workspace,
                application,desktopId:application ? entry.desktopId : '',
                applicationName:application ? (entry.applicationName || entry.command[0]) : '',
                missingArgv:application ? Routing.command(url,defaultEntry,Config.browsers) : argv,
                missingBrowser:defaultBrowser,
                ruleNames:transformationNames.concat(entry.id ? [entry.name] : []),
                fallbackRuleNames:transformationNames.concat(fallback.id ? [fallback.name] : []),
                missingRuleNames:transformationNames,
                browser:application ? entry.command[0] : entry.browser,record:routing}])
            dispatch()
            return true
        } catch(exception) {
            error=Translations.message(exception)
            AlertService.post('browser',error,'error')
            return false
        }
    }
    function dispatch() {
        if (launcher.running || !launchQueue.length) return
        launching=launchQueue[0]; launchQueue=launchQueue.slice(1)
        dispatchResponse=''
        // Start a detached worker via stdin, without evaluating command templates as shell.
        launcher.stdinEnabled=true; launcher.running=true
    }
    Process {
        id: resolver
        command: Config.browserRouterCommand.concat(['resolve'])
        onStarted: {
            const request=root.currentRequest
            write(JSON.stringify({url:request.url,action:request.rule.action,parameter:request.rule.parameter})+'\n')
            stdinEnabled=false
        }
        stdout: SplitParser { onRead: line=>root.response=line }
        onExited: {
            const request=root.currentRequest
            if (!root.enabled || !request) return
            const previous=request.url
            let url=previous
            try { url=Routing.target(JSON.parse(root.response).url) } catch(_) {}
            request.used=request.used.concat([request.rule.id+'\0'+previous])
            if (url!==previous && request.visited.includes(url)) {
                root.finish(Routing.browserRule(previous,request.rules,root.defaultBrowser))
                return
            }
            if (url!==previous) {
                request.ruleNames=request.ruleNames.concat([request.rule.name])
                request.url=url; request.visited=request.visited.concat([url])
            }
            Qt.callLater(root.advance)
        }
    }
    Process {
        id: launcher
        command: Config.browserRouterCommand.concat(['dispatch'])
        onStarted: {
            const request=Object.assign({},root.launching)
            request.applicationAvailable=!request.desktopId || !!DesktopEntries.byId(request.desktopId)
            write(JSON.stringify(request)+'\n'); stdinEnabled=false
        }
        stdout: SplitParser { onRead: line=>root.dispatchResponse=line }
        onExited: (code)=>{
            let browser=root.launching?.browser
            let ruleNames=root.launching?.ruleNames ?? []
            try {
                const result=JSON.parse(root.dispatchResponse)
                browser=result.browser || browser
                ruleNames=result.ruleNames ?? ruleNames
                if (result.missingApplication) AlertService.post('browser',Translations.text('browser.routing.applicationUnavailable',[result.missingApplication]),'error')
            } catch(_) {}
            if (code===0 && root.launching?.record) BrowserRoutingRepository.record(root.launching.originalUrl,browser,ruleNames.join(' → '),root.launching.url)
            if (code!==0) {
                root.error=Translations.text('webapps.errors.browser')
                AlertService.post('browser',root.error,'error')
            }
            root.launching=null
            Qt.callLater(root.dispatch)
        }
    }
    IpcHandler {
        target: 'browser'
        function open(url: string): bool { return root.open(url) }
    }
    onEnabledChanged: if (!enabled) { requests=[]; launchQueue=[]; currentRequest=null; resolver.running=false }
}
