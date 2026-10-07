pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

Singleton {
    id: root
    readonly property var files: {
        const saved = PreferencesRepository.value("files.pinned", [])
        return Array.isArray(saved) ? saved.filter(file => file && !file.isDirectory
            && typeof file.path === "string" && file.path.startsWith("/")
            && typeof file.uri === "string" && file.uri.startsWith("file:///")) : []
    }
    property string error: ""
    readonly property bool checking: check.running
    readonly property bool importing: importFiles.running || state.pendingPaths.length > 0

    QtObject {
        id: state
        property bool dragging: false
        property bool refreshPending: false
        property var missingUris: []
        property var checkedFiles: []
        property string input: ""
        property var pendingPaths: []
        property var pendingFiles: []
        property string importInput: ""
    }

    function contains(uri) { return files.some(file => file.uri === uri) }
    function pathsFromUrls(urls) {
        const paths = []
        for (const value of urls) {
            const url = value.toString()
            // Only local file URLs; decode after stripping the URL authority.
            if (!/^file:\/\/(?:localhost)?\//i.test(url) || /[?#]/.test(url)) continue
            try {
                const path = decodeURIComponent(url.replace(/^file:\/\/(?:localhost)?/i, ""))
                if (!path.includes("\u0000") && !paths.includes(path)) paths.push(path)
            } catch (_) { /* Ignore malformed percent escapes. */ }
        }
        return paths
    }
    function acceptsUrls(urls) { return pathsFromUrls(urls).length > 0 }
    function pinUrls(urls) {
        const paths = pathsFromUrls(urls)
        if (paths.length === 0) return false
        state.pendingPaths = Array.from(new Set(state.pendingPaths.concat(paths)))
        importNext()
        return true
    }
    function importNext() {
        if (importFiles.running || state.pendingPaths.length === 0) return
        state.importInput = JSON.stringify(state.pendingPaths)
        state.pendingPaths = []
        importFiles.stdinEnabled = true
        importFiles.running = true
    }
    function addPendingFiles() {
        if (state.dragging || state.pendingFiles.length === 0) return
        const entries = files.slice()
        for (const file of state.pendingFiles) {
            if (!entries.some(entry => entry.uri === file.uri)) entries.push(file)
        }
        if (save(entries)) { state.pendingFiles = []; refresh() }
    }
    function save(entries) {
        if (!PreferencesRepository.setValue("files.pinned", entries)) {
            error = "Could not save pinned files."
            return false
        }
        error = ""
        return true
    }
    function toggle(file) {
        if (state.dragging || !file || file.isDirectory || typeof file.path !== "string"
            || !file.path.startsWith("/") || typeof file.uri !== "string" || !file.uri.startsWith("file:///")) return false
        const entries = contains(file.uri) ? files.filter(entry => entry.uri !== file.uri)
            : files.concat([Object.assign({}, file)])
        if (!save(entries)) return false
        refresh()
        return true
    }
    function beginDrag() { state.dragging = true }
    function endDrag() {
        state.dragging = false
        addPendingFiles()
        removeMissing()
        if (state.refreshPending) refresh()
    }
    function removeMissing() {
        if (state.missingUris.length === 0) return
        // Filter the current list so pins created during the check are preserved.
        const remaining = files.filter(file => !state.missingUris.includes(file.uri) || !state.checkedFiles.includes(file))
        if (remaining.length === files.length || save(remaining)) state.missingUris = []
    }
    function refresh() {
        if (check.running || state.dragging) { state.refreshPending = true; return }
        state.refreshPending = false
        if (files.length === 0) return
        state.checkedFiles = files
        state.input = JSON.stringify(state.checkedFiles)
        check.stdinEnabled = true
        check.running = true
    }
    Component.onCompleted: refresh()

    Timer {
        interval: Config.recentFilesRefreshInterval
        running: root.files.length > 0
        repeat: true
        onTriggered: root.refresh()
    }
    Process {
        id: importFiles
        command: ["bash", Qt.resolvedUrl("folder-files.sh").toString().replace("file://", ""), "--files"]
        onStarted: { write(state.importInput); stdinEnabled = false }
        stdout: StdioCollector { id: imported; waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            let result
            try { result = JSON.parse(imported.text) } catch (_) { result = null }
            if (exitCode === 0 && exitStatus === 0 && result && Array.isArray(result.files)) {
                if (result.files.length > 0) {
                    state.pendingFiles = state.pendingFiles.concat(result.files)
                    root.addPendingFiles()
                } else root.error = "Only existing, readable files can be pinned."
            } else root.error = "Could not pin dropped files."
            if (state.pendingPaths.length > 0) Qt.callLater(root.importNext)
        }
        // qmllint enable signal-handler-parameters
    }
    Process {
        id: check
        command: ["bash", Qt.resolvedUrl("pinned-files.sh").toString().replace("file://", "")]
        onStarted: { write(state.input); stdinEnabled = false }
        stdout: StdioCollector { id: output; waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            let missing
            try { missing = JSON.parse(output.text) } catch (_) { missing = null }
            if (exitCode === 0 && exitStatus === 0 && Array.isArray(missing)) {
                root.error = ""
                state.missingUris = missing
                if (!state.dragging) root.removeMissing()
            } else root.error = "Could not check pinned files."
            if (state.refreshPending && !state.dragging) Qt.callLater(root.refresh)
        }
        // qmllint enable signal-handler-parameters
    }
}
