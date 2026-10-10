pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io
import "../"
import "../../config"

Singleton {
    id: root
    property bool managing: false
    property bool showAll: false
    property string error: ""
    property var draft: null
    property int generation: 0
    readonly property bool busy: resolve.running
    readonly property var directories: DirectoryRepository.directories
    readonly property var availableDirectories: directories.filter(entry => showAll || entry.category !== "work" || StatusService.status === Config.directoryWorkStatus)
    signal saved()
    function open() {
        generation++; managing = false; showAll = false; draft = null; error = ""
        if (!DirectoryRepository.reload()) error = DirectoryRepository.error
        syncPicker()
    }
    function syncPicker() {
        if (PickerService.mode !== "directories") return
        const previous = PickerService.currentItem?.id
        PickerService.items = availableDirectories.map(entry => ({id:entry.path,title:entry.name,subtitle:entry.path,search:entry.name + " " + entry.path,result:entry.path}))
        PickerService.currentIndex = Math.max(0,PickerService.filteredItems.findIndex(entry => entry.id === previous))
        PickerService.acceptLabel = "Open"
        PickerService.error = error
    }
    function setManaging(value) {
        managing = value
        if (!value) { cancel(); syncPicker(); PickerService.opened() }
    }
    function toggleShowAll() { showAll = !showAll; syncPicker(); PickerService.opened() }
    function edit(entry) { generation++; error = ""; draft = Object.assign({},entry) }
    function cancel() { generation++; draft = null; error = "" }
    function save(path, name, category) {
        if (busy) return
        path = path.trim()
        if (/^file:\/\/(?:localhost)?\//.test(path)) {
            try { path = decodeURIComponent(path.replace(/^file:\/\/(?:localhost)?/,"")) }
            catch (error) { root.error = "Invalid folder URL."; return }
        }
        if (!path) { error = "Choose a folder or enter a file-manager location."; return }
        error = ""
        resolve.previousPath = draft?.path ?? ""
        resolve.entryName = name.trim()
        resolve.category = category
        resolve.generation = root.generation
        resolve.command = Config.directoryResolveCommand.concat([path])
        resolve.running = true
    }
    function remove(path) { if (!DirectoryRepository.remove(path)) error = DirectoryRepository.error }
    function accept(items) {
        if (managing || !items.length) return
        PickerService.close()
        Quickshell.execDetached(Config.directoryOpenCommand.concat([items[0].result]))
    }
    Connections { target: DirectoryRepository; function onDirectoriesChanged() { root.syncPicker() } }
    Connections { target: StatusService; function onStatusChanged() { root.syncPicker() } }
    Process {
        id: resolve
        property string previousPath: ""
        property string entryName: ""
        property string category: "personal"
        property int generation: 0
        stdout: StdioCollector { id: output; waitForEnd: true }
        stderr: StdioCollector { id: failures; waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (generation !== root.generation) return
            if (exitCode !== 0 || exitStatus !== 0) { root.error = failures.text.trim() || "Could not resolve folder."; return }
            try {
                const entry = JSON.parse(output.text)
                if (!DirectoryRepository.save(previousPath,entry.path,entryName || entry.name,category)) {
                    root.error = DirectoryRepository.error; return
                }
                root.draft = null; root.error = ""; root.saved()
            } catch (error) { root.error = error.message ?? String(error) }
        }
        // qmllint enable signal-handler-parameters
    }
}
