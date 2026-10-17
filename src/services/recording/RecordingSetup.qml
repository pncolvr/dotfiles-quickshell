pragma ComponentBehavior: Bound
import "../../i18n"
import QtQml
import Quickshell
import Quickshell.Io
import "../"
import "../../config"
import "RecordingOptions.mjs" as Options

// Native choice flow. No recorder/audio modules are started until prepared is emitted.
Scope {
    id: root
    property var operation: null
    readonly property bool active: operation !== null
    signal prepared(var options)
    signal cancelled()
    signal failed(string message)

    function open() {
        if (active) return
        const current = {options: {}, callback: null, task: null, waiter: null}
        operation = current
        menu(current, Translations.text("recording.setup.capture"), ["output", "region"].map(mode => ({title:Translations.text("recording.modes."+mode),result:mode})), rows => {
            current.options.capture = rows[0].result
            switch (current.options.capture) {
              case "output": chooseOutput(current); break
              case "region": chooseRegion(current); break
            }
        })
    }
    function cancel() {
        const current = operation
        if (!current) return
        operation = null
        if (current.waiter) CaptureHandoffService.cancel(current.waiter)
        if (current.task?.running) current.task.signal(15)
        if (PickerService.menuCallback === current.callback) PickerService.close()
        cancelled()
    }
    function fail(message) { cancel(); failed(message) }
    function menu(current, title, rows, callback) {
        if (operation !== current) return
        current.callback = callback
        PickerService.promptMenu(title, rows, callback, "list", {
            keepOpen: true,
            onClosed: reason => { if (root.operation === current && current.callback === callback && reason !== "accepted") root.cancel() }
        })
    }
    function run(current, command, callback) {
        if (operation !== current) return
        const process = task.createObject(root, {command, callback: (ok, output, error, code) => {
            if (root.operation !== current) return
            current.task = null
            callback(ok, output, error, code)
        }}) as Process
        current.task = process
        process.running = true
    }
    function chooseOutput(current) {
        menu(current, Translations.text("recording.setup.output"), [], rows => { current.options.output = rows[0].result; chooseFramerate(current) })
        run(current, ["hyprctl", "monitors", "-j"], (ok, output) => {
            if (!ok) { fail(Translations.text("recording.errors.outputs")); return }
            try {
                const monitors = JSON.parse(output)
                if (!Array.isArray(monitors) || !monitors.length || !monitors.every(item => typeof item.name === "string" && item.name)) throw new Error(Translations.text("recording.errors.noOutputs"))
                PickerService.items = PickerService.menuRows(monitors.sort((a,b) => a.name.localeCompare(b.name)).map(item => ({title:item.name})))
            } catch (_) { fail(Translations.text("recording.errors.outputs")) }
        })
    }
    function chooseRegion(current) {
        PickerService.close()
        current.waiter = () => {
            if (root.operation !== current) return
            current.waiter = null
            run(current, ["slurp", "-d"], (ok, output, error, code) => {
                if (!ok) {
                    if (code === 1 && (!error || /^(slurp: )?selection cancelled$/.test(error))) cancel()
                    else fail(Translations.text("recording.errors.selectRegion"))
                    return
                }
                current.options.geometry = output.trim()
                if (!/^-?[0-9]+,-?[0-9]+ [1-9][0-9]*x[1-9][0-9]*$/.test(current.options.geometry)) { fail(Translations.text("recording.errors.region")); return }
                chooseFramerate(current)
            })
        }
        CaptureHandoffService.wait(current.waiter)
    }
    function chooseFramerate(current) {
        menu(current, Translations.text("recording.setup.framerate"), ["60", "30", "15"].map(title => ({title})), rows => {
            current.options.fps = Number(rows[0].result)
            menu(current, Translations.text("recording.setup.audio"), ["none", "both", "desktop", "mic"].map(mode => ({title:Translations.text("recording.audio."+mode),result:mode})), rows => {
                current.options.audio = rows[0].result
                switch (current.options.audio) {
                  case "none": finish(current); break
                  case "mic": chooseDevice(current, "sources"); break
                  default: chooseDevice(current, "sinks")
                }
            })
        })
    }
    function chooseDevice(current, kind) {
        menu(current, Translations.text(kind === "sinks" ? "recording.setup.audioOutput" : "recording.setup.microphone"), [], rows => {
            const selected = rows[0]
            switch (kind) {
              case "sinks":
                current.options.outputDevice = selected.result
                current.options.monitorSource = selected.monitorSource
                if (!selected.monitorSource) { fail(Translations.text("recording.errors.monitorSource")); return }
                if (current.options.audio === "both") chooseDevice(current, "sources")
                else finish(current)
                break
              default:
                current.options.microphone = selected.result
                finish(current)
            }
        })
        const command = kind === "sinks" ? "get-default-sink" : "get-default-source"
        run(current, ["pactl", command], (ok, output) => {
            if (!ok || !output.trim()) { fail(Translations.text("recording.errors.defaultDevice")); return }
            const defaultName = output.trim()
            run(current, ["pactl", "--format=json", "list", kind], (ok, output) => {
                if (!ok) { fail(Translations.text("recording.errors.readDevices")); return }
                let devices
                try { devices = JSON.parse(output) } catch (_) { fail(Translations.text("recording.errors.readDevices")); return }
                run(current, ["pactl", "--format=json", "list", "cards"], (ok, output) => {
                    if (!ok) { fail(Translations.text("recording.errors.deviceProfiles")); return }
                    try {
                        const rows = Options.deviceRows(devices, JSON.parse(output), defaultName, name => Translations.text("recording.device.default",[name]))
                        if (!rows.length) throw new Error(Translations.text("recording.errors.noDevices"))
                        PickerService.items = PickerService.menuRows(rows)
                    } catch (error) { fail(Translations.message(error) || Translations.text("recording.errors.readDevices")) }
                })
            })
        })
    }
    function finish(current) {
        if (operation !== current) return
        let options
        try { options = Options.prepared(current.options, Config.recordingDirectory, Config.recordingEncoderArguments) }
        catch (error) { fail(String(error)); return }
        operation = null
        PickerService.close()
        prepared(options)
    }
    Connections {
        target: PickerService
        function onOpened() { if (root.operation && PickerService.menuCallback !== root.operation.callback) root.cancel() }
    }
    Component.onDestruction: if (operation?.task?.running) operation.task.signal(15)
    Component {
        id: task
        Process {
            id: process
            property var callback: null
            // slurp reads optional rectangles first; close the QProcess pipe explicitly.
            stdinEnabled: true
            onStarted: stdinEnabled = false
            stdout: StdioCollector { id: output; waitForEnd: true }
            stderr: StdioCollector { id: error; waitForEnd: true }
            // qmllint disable signal-handler-parameters
            onExited: (code, status) => {
                callback(code === 0 && status === 0, output.text, error.text.trim(), code)
                process.destroy()
            }
            // qmllint enable signal-handler-parameters
        }
    }
}
