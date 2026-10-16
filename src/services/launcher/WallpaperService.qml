pragma ComponentBehavior: Bound
pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "../"
import "../../config"

Singleton {
    id: root
    property var session: null
    property string pendingRestore: ""
    readonly property string helper: Quickshell.shellPath("src/services/launcher/providers/wallpaper.sh")

    function open(directory = "") {
        endSession()
        const operation = {rows: [], query: "", selectedResult: undefined, callback: null, job: null}
        session = operation
        browse(operation)
        operation.job = run(["list", directory || Config.wallpaperDirectory], (success, output, error) => {
            if (session !== operation) return
            operation.job = null
            if (!success) { fail(error || "Could not list wallpapers", operation); return }
            const paths = output.split("\0")
            const folder = paths.shift()
            operation.rows = PickerService.menuRows(paths.filter(path => path.length > 0).sort((a,b) => a.localeCompare(b)).map(path => ({
                title: path.slice(folder === "/" ? 1 : folder.length + 1), result: path,
                image: "file://" + path.split("/").map(encodeURIComponent).join("/")
            })))
            if (!operation.rows.length) { fail("No wallpaper images found", operation); return }
            PickerService.items = operation.rows
            PickerService.restoreMenuSelection({query: PickerService.query, selectionKey: "wallpaper.image"})
        })
    }
    function endSession() {
        const previous = session
        session = null
        if (previous?.job?.running) previous.job.signal(15)
    }
    function fail(message, operation = null) {
        AlertService.post("wallpaper", message, "error", 3000)
        if (!operation || session !== operation) return
        endSession()
        if (PickerService.menuCallback === operation.callback) PickerService.close()
    }
    function menu(operation, title, rows, callback, options = {}, returnToImages = false) {
        if (session !== operation) return
        operation.callback = callback
        PickerService.promptMenu(title, rows, callback, "list", Object.assign({}, options, {
            keepOpen: true,
            onClosed: reason => {
                if (session !== operation || operation.callback !== callback) return
                switch (reason) {
                  case "accepted": return
                  case "cancelled":
                    if (returnToImages) {
                        if (operation.job?.running) operation.job.signal(15)
                        operation.job = null
                        operation.callback = null
                        Qt.callLater(() => { if (root.session === operation) root.browse(operation) })
                        return
                    }
                    break
                }
                root.endSession()
            }
        }))
    }
    function browse(operation) {
        menu(operation, "Choose wallpaper", operation.rows, (rows, state) => {
            operation.query = state.query
            operation.selectedResult = rows[0].result
            chooseMode(operation)
        }, {previewImages: true, query: operation.query, selectedResult: operation.selectedResult,
            selectionKey: "wallpaper.image", acceptLabel: "Choose"})
    }
    function chooseMode(operation) {
        if (!Config.workModeEnabled) { chooseMonitor(operation, "personal"); return }
        menu(operation, "Wallpaper mode", [{title: "Personal", result: "personal"}, {title: "Work", result: "work"}],
            rows => chooseMonitor(operation, rows[0].result),
            {selectionKey: "wallpaper.mode", acceptLabel: "Choose mode"}, true)
    }
    function chooseMonitor(operation, mode) {
        menu(operation, "Wallpaper monitor", [], rows => apply(operation, rows[0].result, mode),
            {selectionKey: "wallpaper.monitor", acceptLabel: "Set wallpaper"}, true)
        const callback = operation.callback
        operation.job = run([], (success, output) => {
            if (session !== operation || operation.callback !== callback) return
            operation.job = null
            let outputs
            try { outputs = JSON.parse(output) } catch (_) { outputs = null }
            if (!success || !Array.isArray(outputs) || !outputs.length
                || !outputs.every(item => typeof item.name === "string" && item.name.length > 0)) {
                fail("Could not read connected monitors")
                browse(operation)
                return
            }
            outputs.sort((a,b) => Number(b.focused === true) - Number(a.focused === true))
            PickerService.items = PickerService.menuRows(outputs.map(output => ({
                title: output.name, subtitle: output.description || output.name, result: output.name
            })))
            PickerService.restoreMenuSelection({query: PickerService.query, selectionKey: "wallpaper.monitor"})
        }, ["hyprctl", "monitors", "-j"])
    }
    function apply(operation, output, mode) {
        if (!Config.workModeEnabled) mode = "personal"
        run(["--configured", "set", output, mode, operation.selectedResult], (success, _output, error) => {
            if (success) AlertService.post("wallpaper", "Wallpaper saved for " + mode + " on " + output, "success", 3000)
            else fail(error || "Could not set wallpaper")
            if (session === operation) browse(operation)
        })
    }
    function restore(mode) {
        pendingRestore = mode
        restoreNext()
    }
    function restoreNext() {
        if (!pendingRestore || restoreTask.running) return
        const mode = pendingRestore
        pendingRestore = ""
        restoreTask.command = ["bash", helper, "--configured", "restore", mode]
        restoreTask.running = true
    }
    function run(args, callback, command = null) {
        const process = task.createObject(root, {
            command: command || ["bash", helper].concat(args), callback
        }) as Process
        process.running = true
        return process
    }
    Connections {
        target: PickerService
        function onOpened() {
            if (root.session && PickerService.menuCallback !== root.session.callback) root.endSession()
        }
    }
    Component.onDestruction: root.endSession()
    Component {
        id: task
        Process {
            id: process
            property var callback: null
            environment: Config.providerEnvironment
            stdout: StdioCollector { id: output; waitForEnd: true }
            stderr: StdioCollector { id: error; waitForEnd: true }
            // qmllint disable signal-handler-parameters
            onExited: (code, status) => {
                if (callback) callback(code === 0 && status === 0, output.text, error.text.trim())
                process.destroy()
            }
            // qmllint enable signal-handler-parameters
        }
    }
    Process {
        id: restoreTask
        environment: Config.providerEnvironment
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: restoreError; waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (code, status) => {
            if (code !== 0 || status !== 0) root.fail(restoreError.text.trim() || "Could not restore wallpapers")
            Qt.callLater(root.restoreNext)
        }
        // qmllint enable signal-handler-parameters
    }
}
