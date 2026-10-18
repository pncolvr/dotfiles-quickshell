pragma Singleton
import "../../i18n"
import QtQml
import Quickshell
import Quickshell.Io
import "../"
import "../launcher"
import "../../config"
import "WebappEntries.mjs" as Entries

ManagedCollectionService {
    id: root
    repository: WebappRepository
    pickerMode: PickerService.Mode.Webapps
    collectionName: Translations.text("webapps.title")
    itemForEntry: entry => ({id:entry.id,title:entry.name,subtitle:entry.url,
        search:entry.name+' '+entry.url,result:entry.id})
    busy: launchTask.running
    function newEntry() { edit(Entries.empty(Config.defaultBrowserId)) }
    function accept(items) {
        if (managing || busy || !items.length) return
        const entry=entries.find(entry => entry.id === items[0].result)
        if (!entry || !entry.enabled) return
        let command
        try { command=Entries.launch(entry,Config.browsers) }
        catch (exception) { error=Translations.message(exception); syncPicker(); return }
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
    Process {
        id: launchTask
        property var browserCommand: []
        property var afterCommand: []
        property bool beforeOpening: false
        stdout: StdioCollector { waitForEnd:true }
        stderr: StdioCollector { waitForEnd:true }
        // qmllint disable signal-handler-parameters
        onExited: (code,status) => {
            if (code || status) { root.error=Translations.text("webapps.errors.launch"); AlertService.post('webapps',root.error,'error'); return }
            if (beforeOpening) Qt.callLater(root.dispatchBrowser)
        }
        // qmllint enable signal-handler-parameters
    }
}
