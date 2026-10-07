pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

Singleton {
    id: root
    property var files: []
    readonly property string error: state.error || PinnedFilesService.error
    readonly property bool loading: scan.running
    readonly property bool dragging: state.dragging
    readonly property var pinnedFiles: PinnedFilesService.files
    readonly property bool showingPinned: state.showingPinned
    readonly property string activeTab: showingPinned ? "pinned" : activeFolder ? "folder" : "recent"
    readonly property var folders: {
        const saved = PreferencesRepository.value("files.folders", [])
        return Array.isArray(saved) ? saved.filter(path => typeof path === "string" && path.length > 0) : []
    }
    readonly property string activeFolder: state.activeFolder
    readonly property string currentFolder: state.navigationFolders.length > 0
        ? state.navigationFolders[state.navigationFolders.length - 1] : activeFolder
    readonly property bool canNavigateUp: state.navigationFolders.length > 0
    readonly property string defaultFolder: {
        const saved = PreferencesRepository.value("files.defaultFolder", "")
        return typeof saved === "string" && folders.includes(saved) ? saved : ""
    }
    readonly property string defaultTab: {
        // Preserve folder defaults saved before Recent and Pinned had their own controls.
        const saved = PreferencesRepository.value("files.defaultTab", defaultFolder ? "folder" : "recent")
        return saved === "pinned" && pinnedFiles.length > 0 ? "pinned"
            : saved === "folder" && defaultFolder ? "folder" : "recent"
    }
    readonly property var folderAliases: {
        const saved = PreferencesRepository.value("files.folderAliases", {})
        return saved && typeof saved === "object" && !Array.isArray(saved) ? saved : {}
    }
    signal folderAdded(string path)

    QtObject {
        id: state
        property int panels: 0
        property string error: ""
        property bool dragging: false
        property bool refreshPending: false
        property string activeFolder: ""
        property bool showingPinned: false
        property var navigationFolders: []
        property string requestFolder: ""
        property bool addingFolder: false
        property var deferredSnapshot: null
    }

    function beginPanel() {
        if (state.panels === 0) {
            state.navigationFolders = []
            state.showingPinned = defaultTab === "pinned"
            state.activeFolder = defaultTab === "folder" ? defaultFolder : ""
            files = state.showingPinned ? pinnedFiles : []
            state.error = ""
        }
        state.panels++
        refresh()
    }
    function endPanel() { state.panels = Math.max(0, state.panels - 1) }
    function beginDrag() { state.dragging = true; PinnedFilesService.beginDrag() }
    function endDrag() {
        state.dragging = false
        PinnedFilesService.endDrag()
        if (state.deferredSnapshot) {
            applySnapshot(state.deferredSnapshot)
            state.deferredSnapshot = null
        }
        if (state.refreshPending) refresh()
    }
    function applySnapshot(snapshot) {
        if (state.addingFolder && typeof snapshot.folder === "string") {
            if (folders.includes(snapshot.folder)
                || PreferencesRepository.setValue("files.folders", folders.concat([snapshot.folder]))) {
                state.activeFolder = snapshot.folder
                state.showingPinned = false
                state.navigationFolders = []
                files = snapshot.files
                state.error = ""
                folderAdded(snapshot.folder)
            } else state.error = "Could not save the folder list."
        } else if (!showingPinned && state.requestFolder === currentFolder) {
            if (canNavigateUp && snapshot.folder !== currentFolder)
                state.navigationFolders = state.navigationFolders.slice(0, -1).concat([snapshot.folder])
            files = snapshot.files
            state.error = ""
        }
    }
    function refresh() {
        PinnedFilesService.refresh()
        if (showingPinned) { files = pinnedFiles; return }
        if (scan.running || state.dragging) { state.refreshPending = true; return }
        state.refreshPending = false
        state.requestFolder = currentFolder
        state.addingFolder = false
        scan.command = currentFolder ? folderCommand(currentFolder) : Config.recentFilesCommand
        scan.running = true
    }
    function folderCommand(path) {
        return Config.recentFolderCommand.concat(["--folder", path])
    }
    function selectFolder(path) {
        if (state.dragging || (path && !folders.includes(path))) return
        if (!showingPinned && state.activeFolder === path && !canNavigateUp) return
        state.showingPinned = false
        state.activeFolder = path
        state.navigationFolders = []
        files = []
        state.error = ""
        refresh()
    }
    function selectPinned() {
        if (state.dragging) return
        selectPinnedForDrag()
    }
    function selectPinnedForDrag() {
        if (pinnedFiles.length === 0 || showingPinned) return
        state.activeFolder = ""
        state.navigationFolders = []
        state.showingPinned = true
        files = pinnedFiles
        state.error = ""
        PinnedFilesService.refresh()
    }
    function isPinned(uri) { return PinnedFilesService.contains(uri) }
    function acceptsPinUrls(urls) { return PinnedFilesService.acceptsUrls(urls) }
    function pinUrls(urls, beforeUri = "") { return PinnedFilesService.pinUrls(urls, beforeUri) }
    function reorderPins(uris, beforeUri = "") { return PinnedFilesService.reorder(uris, beforeUri) }
    function togglePin(file) {
        if (state.dragging) return false
        return PinnedFilesService.toggle(file)
    }
    onPinnedFilesChanged: {
        if (pinnedFiles.length === 0) Qt.callLater(root.resetEmptyPinnedDefault)
        if (!showingPinned) return
        if (pinnedFiles.length === 0) selectFolder("")
        else files = pinnedFiles
    }
    function resetEmptyPinnedDefault() {
        if (pinnedFiles.length === 0 && PreferencesRepository.value("files.defaultTab", "recent") === "pinned")
            setDefaultTab("recent")
    }
    function navigateFolder(path) {
        if (!activeFolder || state.dragging || (scan.running && state.addingFolder)
            || typeof path !== "string" || !path || path === currentFolder) return false
        state.navigationFolders = state.navigationFolders.concat([path])
        files = []
        state.error = ""
        refresh()
        return true
    }
    function navigateUp() {
        if (!canNavigateUp || state.dragging) return false
        state.navigationFolders = state.navigationFolders.slice(0, -1)
        files = []
        state.error = ""
        refresh()
        return true
    }
    function addFolder(path) {
        if (scan.running || state.dragging) return false
        if (!path) { state.error = "Enter a folder path."; return false }
        state.refreshPending = false
        state.requestFolder = path
        state.addingFolder = true
        state.error = ""
        scan.command = folderCommand(path)
        scan.running = true
        return true
    }
    function removeFolder(path) {
        if (state.dragging || !folders.includes(path)) return false
        const values = {"files.folders": folders.filter(folder => folder !== path)}
        if (defaultFolder === path) {
            values["files.defaultFolder"] = ""
            values["files.defaultTab"] = "recent"
        }
        const aliases = Object.assign({}, folderAliases)
        delete aliases[path]
        values["files.folderAliases"] = aliases
        if (!PreferencesRepository.setValues(values)) {
            state.error = "Could not save the folder list."
            return false
        }
        if (state.activeFolder === path) selectFolder("")
        return true
    }
    function setDefaultFolder(path) {
        return setDefaultTab(path ? "folder" : "recent", path)
    }
    function setDefaultTab(tab, path = "") {
        if (state.dragging || !["recent", "pinned", "folder"].includes(tab)
            || (tab === "pinned" && pinnedFiles.length === 0)
            || (tab === "folder" && !folders.includes(path))) return false
        if (!PreferencesRepository.setValues({"files.defaultTab": tab,
            "files.defaultFolder": tab === "folder" ? path : ""})) {
            state.error = "Could not save the default tab."
            return false
        }
        return true
    }
    function folderLabel(path) {
        const alias = folderAliases[path]
        return typeof alias === "string" && alias.length > 0 ? alias
            : path.split("/").filter(part => part.length > 0).pop() || "/"
    }
    function setFolderAlias(path, name) {
        if (state.dragging || !folders.includes(path)) return false
        const aliases = Object.assign({}, folderAliases)
        const alias = name.trim()
        if (alias) aliases[path] = alias
        else delete aliases[path]
        if (!PreferencesRepository.setValue("files.folderAliases", aliases)) {
            state.error = "Could not save the tab name."
            return false
        }
        return true
    }
    function openFile(file) {
        if (file.isDirectory) navigateFolder(file.path)
        else Qt.openUrlExternally(file.uri)
    }

    Timer {
        interval: Config.recentFilesRefreshInterval
        running: state.panels > 0
        repeat: true
        onTriggered: root.refresh()
    }
    Process {
        id: scan
        stdout: StdioCollector { id: output; waitForEnd: true }
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            let snapshot
            try { snapshot = JSON.parse(output.text) } catch (_) { snapshot = null }
            if (exitCode === 0 && exitStatus === 0 && Array.isArray(snapshot?.files)) {
                // Keep the drag source and its model alive until the drop finishes.
                if (state.dragging) { state.deferredSnapshot = snapshot; state.refreshPending = true }
                else root.applySnapshot(snapshot)
            } else if (state.addingFolder || (!root.showingPinned && state.requestFolder === root.currentFolder))
                state.error = snapshot?.error || "Could not load files."
            if (state.refreshPending && !state.dragging) Qt.callLater(root.refresh)
        }
        // qmllint enable signal-handler-parameters
    }
    IpcHandler {
        target: "recentfiles"
        function reload(): void { root.refresh() }
    }
}
