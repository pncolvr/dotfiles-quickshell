pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

Singleton {
    id: root
    property var files: []
    property string error: ""
    readonly property bool loading: scan.running
    readonly property bool dragging: state.dragging
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
    readonly property var folderAliases: {
        const saved = PreferencesRepository.value("files.folderAliases", {})
        return saved && typeof saved === "object" && !Array.isArray(saved) ? saved : {}
    }
    signal folderAdded(string path)

    QtObject {
        id: state
        property int panels: 0
        property bool dragging: false
        property bool refreshPending: false
        property string activeFolder: ""
        property var navigationFolders: []
        property string requestFolder: ""
        property bool addingFolder: false
        property var deferredSnapshot: null
    }

    function beginPanel() {
        if (state.panels === 0) {
            state.navigationFolders = []
            state.activeFolder = defaultFolder
            files = []
            error = ""
        }
        state.panels++
        refresh()
    }
    function endPanel() { state.panels = Math.max(0, state.panels - 1) }
    function beginDrag() { state.dragging = true }
    function endDrag() {
        state.dragging = false
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
                state.navigationFolders = []
                files = snapshot.files
                error = ""
                folderAdded(snapshot.folder)
            } else error = "Could not save the folder list."
        } else if (state.requestFolder === currentFolder) {
            if (canNavigateUp && snapshot.folder !== currentFolder)
                state.navigationFolders = state.navigationFolders.slice(0, -1).concat([snapshot.folder])
            files = snapshot.files
            error = ""
        }
    }
    function refresh() {
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
        if (state.activeFolder === path && !canNavigateUp) return
        state.activeFolder = path
        state.navigationFolders = []
        files = []
        error = ""
        refresh()
    }
    function navigateFolder(path) {
        if (!activeFolder || state.dragging || (scan.running && state.addingFolder)
            || typeof path !== "string" || !path || path === currentFolder) return false
        state.navigationFolders = state.navigationFolders.concat([path])
        files = []
        error = ""
        refresh()
        return true
    }
    function navigateUp() {
        if (!canNavigateUp || state.dragging) return false
        state.navigationFolders = state.navigationFolders.slice(0, -1)
        files = []
        error = ""
        refresh()
        return true
    }
    function addFolder(path) {
        if (scan.running || state.dragging) return false
        if (!path) { error = "Enter a folder path."; return false }
        state.refreshPending = false
        state.requestFolder = path
        state.addingFolder = true
        error = ""
        scan.command = folderCommand(path)
        scan.running = true
        return true
    }
    function removeFolder(path) {
        if (state.dragging || !folders.includes(path)) return false
        const values = {"files.folders": folders.filter(folder => folder !== path)}
        if (defaultFolder === path) values["files.defaultFolder"] = ""
        const aliases = Object.assign({}, folderAliases)
        delete aliases[path]
        values["files.folderAliases"] = aliases
        if (!PreferencesRepository.setValues(values)) {
            error = "Could not save the folder list."
            return false
        }
        if (state.activeFolder === path) selectFolder("")
        return true
    }
    function setDefaultFolder(path) {
        if (state.dragging || (path && !folders.includes(path))) return false
        if (!PreferencesRepository.setValue("files.defaultFolder", path)) {
            error = "Could not save the default tab."
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
            error = "Could not save the tab name."
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
            } else if (state.addingFolder || state.requestFolder === root.currentFolder)
                root.error = snapshot?.error || "Could not load files."
            if (state.refreshPending && !state.dragging) Qt.callLater(root.refresh)
        }
        // qmllint enable signal-handler-parameters
    }
    IpcHandler {
        target: "recentfiles"
        function reload(): void { root.refresh() }
    }
}
