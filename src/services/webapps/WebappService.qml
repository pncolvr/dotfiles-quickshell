pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io
import "../"
import "../../config"
import "WebappEntries.mjs" as Entries

Singleton {
    id: root
    property bool managing: false
    property bool showAll: false
    property var draft: null
    property string error: ""
    readonly property bool busy: launchTask.running
    readonly property var entries: WebappRepository.entries
    readonly property var availableEntries: entries.filter(entry => entry.enabled &&
        (showAll || entry.category !== 'work' || StatusService.status === Config.pickerWorkStatus))
    signal saved()
    function open() {
        managing = false; showAll = false; draft = null; error = ''
        if (!WebappRepository.reload()) error = WebappRepository.error
        syncPicker()
    }
    function syncPicker() {
        if (PickerService.mode !== PickerService.Mode.Webapps) return
        const previous = PickerService.currentItem?.id
        PickerService.items = availableEntries.map(entry => ({id:entry.id,title:entry.name,subtitle:entry.url,
            search:entry.name + ' ' + entry.url,result:entry.id}))
        PickerService.currentIndex = Math.max(0,PickerService.filteredItems.findIndex(row => row.id === previous))
        PickerService.acceptLabel = 'Open'; PickerService.error = error
    }
    function setManaging(value) { managing = value; cancel(); if (!value) { syncPicker(); PickerService.opened() } }
    function toggleShowAll() { showAll = !showAll; syncPicker(); PickerService.opened() }
    function edit(entry) { draft = Object.assign({},entry); error='' }
    function newEntry() { edit(Entries.empty()) }
    function cancel() { draft=null; error='' }
    function save(value) {
        if (busy || !value) return
        value.id = draft?.id ?? ''
        if (!WebappRepository.save(value)) { error=WebappRepository.error; return }
        draft=null; error=''; saved()
    }
    function remove(id) { if (!WebappRepository.remove(id)) error=WebappRepository.error }
    function accept(items) {
        if (managing || busy || !items.length) return
        const entry=entries.find(entry => entry.id === items[0].result)
        if (!entry || !entry.enabled) return
        let command
        try { command=Entries.launch(entry,Config.webappBrowsers) }
        catch (exception) { error=exception.message; syncPicker(); return }
        launchTask.browserCommand=command
        launchTask.afterCommand=entry.after
        PickerService.close()
        if (entry.before.length) {
            launchTask.beforeOpening=true
            launchTask.command=entry.before
            launchTask.running=true
        } else dispatchBrowser()
    }
    function dispatchBrowser() {
        Quickshell.execDetached(launchTask.browserCommand)
        if (launchTask.afterCommand.length) {
            launchTask.beforeOpening=false
            launchTask.command=launchTask.afterCommand
            launchTask.running=true
        }
    }
    Connections { target: WebappRepository; function onEntriesChanged() { root.syncPicker() } }
    Connections { target: StatusService; function onStatusChanged() { root.syncPicker() } }
    onErrorChanged: syncPicker()
    Process {
        id: launchTask
        property var browserCommand: []
        property var afterCommand: []
        property bool beforeOpening: false
        stdout: StdioCollector { waitForEnd:true }
        stderr: StdioCollector { waitForEnd:true }
        // qmllint disable signal-handler-parameters
        onExited: (code,status) => {
            if (code || status) { root.error='Webapp launch failed.'; AlertService.post('webapps',root.error,'error'); return }
            if (beforeOpening) Qt.callLater(root.dispatchBrowser)
        }
        // qmllint enable signal-handler-parameters
    }
}
