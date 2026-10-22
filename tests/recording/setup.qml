pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/services/recording"
import "../../src/modules/launcher"
import "../launcher" as Fixtures

WorkerScope {
    id: root
    property var submitted: null
    property int submittedCount: 0
    property int cancellations: 0
    property var failures: []
    Fixtures.NativeFocusDriver {
        id: driver
        timeout: 4000
        onFailed: message => { console.error("SETUP FAIL:", message, JSON.stringify({failures:root.failures,prompt:CaptureMenuService.prompt,command:setup.operation?.task?.command})); root.finish() }
        onCompleted: root.finish()
    }
    function finish() { setup.cancel(); CaptureMenuService.close(); Qt.quit() }
    RecordingSetup {
        id: setup
        onPrepared: options => { root.submitted = options; root.submittedCount++ }
        onCancelled: root.cancellations++
        onFailed: message => root.failures = root.failures.concat([message])
    }
    FloatingWindow {
        visible: true
        implicitWidth: 800; implicitHeight: 600
        PickerPanel { id: panel; picker: CaptureMenuService; anchors.fill: parent }
    }
    FileView { id: control; path: Quickshell.env("RECORD_SETUP_TEST") + "/control"; preload: false; blockWrites: true; printErrors: false }
    function check(ok, message) { driver.check(ok, message) }
    function state(options = {}) { driver.add("set tool behavior", () => control.setText(JSON.stringify(options))) }
    function menu(title) {
        driver.waitFor("native " + title + " choices", () => CaptureMenuService.visible
            && CaptureMenuService.prompt === title && CaptureMenuService.items.length > 0
            && panel.Window.active && !!driver.find(panel, "pickerSearch")?.activeFocus, () => {
                check(CaptureMenuService.requestDirectory === "" && !!CaptureMenuService.menuCallback, "choices never use a shell request")
            })
    }
    function choose(result) {
        driver.add("choose " + result, () => {
            const index = CaptureMenuService.filteredItems.findIndex(item => item.result === result)
            check(index >= 0, "choice exists: " + result)
            CaptureMenuService.select(index, false)
            driver.key(Qt.Key_Return)
        })
    }
    function cancelInput() {
        driver.add("cancel setup", () => {
            driver.key(Qt.Key_Escape)
            check(!setup.active && !CaptureMenuService.visible, "Escape cancels setup")
        })
    }
    function begin() {
        driver.add("begin setup", () => { submitted = null; setup.open() })
        menu("Capture")
    }
    function output() {
        choose("output"); menu("Output")
        driver.add("output order", () => check(CaptureMenuService.items[0].result === "DP-1", "outputs keep alphabetical order"))
        choose("DP-1"); menu("Framerate")
    }
    function audio(mode) {
        choose("60"); menu("Audio")
        driver.add("audio order", () => check(CaptureMenuService.items.map(item => item.result).join(",") === "none,both,desktop,mic", "audio order unchanged"))
        choose(mode)
    }
    function device(kind, other = false) {
        menu(kind === "sinks" ? "Audio output" : "Microphone")
        driver.add("device filtering", () => {
            check(CaptureMenuService.items[0].title.endsWith(" (default)"), "default device first")
            check(CaptureMenuService.items.every(item => !item.result.startsWith("off.")), "off profiles excluded")
            if (kind === "sources") check(CaptureMenuService.items.some(item => item.result === "virtual.monitor"), "virtual sources retained")
        })
        choose(kind === "sinks" ? (other ? "output.other" : "output.default") : (other ? "mic.other" : "mic.default"))
    }
    Component.onCompleted: {
        driver.waitFor("database ready", () => DbService.ready)
        driver.add("existing launcher", () => {
            PickerService.promptMenu("Existing Manage", [{title:"Existing entry"}], () => {})
            PickerService.query = "Existing"
        })
        state(); begin()
        driver.add("initial choices", () => {
            check(CaptureMenuService.items.map(item => item.result).join(",") === "output,region,window", "window is appended without changing existing capture defaults")
            check(PickerService.visible && PickerService.query === "Existing", "recording capture menu preserves the ordinary launcher")
            CaptureMenuService.query = "reg"
            setup.open()
            check(CaptureMenuService.query === "reg", "repeated setup leaves current choices and query intact")
            CaptureMenuService.query = ""
        })
        cancelInput()
        for (const point of ["Output", "Framerate", "Audio", "Audio output", "Microphone"]) {
            begin(); choose("output"); menu("Output")
            if (point === "Output") { cancelInput(); continue }
            choose("DP-1"); menu("Framerate")
            if (point === "Framerate") { cancelInput(); continue }
            choose("60"); menu("Audio")
            if (point === "Audio") { cancelInput(); continue }
            choose(point === "Audio output" ? "desktop" : "mic")
            menu(point); cancelInput()
        }
        driver.add("cancellation is quiet", () => check(submittedCount === 0 && failures.length === 0, "cancelling any step never submits or reports failure"))
        for (const mode of ["none", "desktop", "mic", "both"]) {
            begin(); output(); audio(mode)
            if (mode === "desktop" || mode === "both") device("sinks")
            if (mode === "mic" || mode === "both") device("sources")
            driver.waitFor("prepared " + mode + " recording options", () => !!submitted, () => {
                check(!setup.active && !CaptureMenuService.visible, "all choices close before worker handoff")
                check(submitted.command[0] === "wf-recorder" && submitted.command.includes("--no-damage") && submitted.command.includes("hevc_nvenc"), "continuous capture and encoder unchanged")
                check(submitted.command.includes("--output") && submitted.command.includes("DP-1") && submitted.command.includes("60"), "capture/framerate choices passed literally")
                switch (mode) {
                  case "none": check(submitted.loopback.length === 0 && !submitted.command.some(arg => arg.startsWith("--audio=")), "no audio has no modules or flags"); break
                  case "mic": check(submitted.command.includes("--audio=mic.default") && submitted.loopback.length === 0, "microphone source"); break
                  default:
                    check(submitted.command.includes("--audio=output.monitor"), "desktop uses output monitor source")
                    check(mode !== "both" || submitted.loopback.join("|") === "module-loopback|source=mic.default|sink=output.default", "combined audio deferred to worker")
                }
            })
        }
        begin(); output(); audio("both"); device("sinks", true); device("sources", true)
        driver.waitFor("other devices prepared", () => !!submitted, () => check(submitted.command.includes("--audio=other.monitor") && submitted.loopback.includes("sink=output.other"), "other devices use identities rather than labels"))
        const windowGate = {}
        driver.add("hold window capture readiness", () => CaptureHandoffService.update(windowGate, true))
        begin(); choose("window")
        driver.add("window waits for presentation", () => check(setup.active && !CaptureMenuService.visible
            && !setup.operation.task, "window metadata and selector wait for shared presentation readiness"))
        driver.pause(30)
        driver.add("release window capture readiness", () => CaptureHandoffService.update(windowGate, false))
        menu("Framerate"); choose("30"); menu("Audio"); choose("desktop"); device("sinks")
        driver.waitFor("window options", () => !!submitted, () => {
            check(submitted.command.includes("--geometry") && submitted.command.includes("10,20 300x200")
                && submitted.command.includes("30") && submitted.command.includes("--audio=output.monitor")
                && !submitted.command.includes("--output"), "selected window rectangle keeps framerate and audio choices")
        })
        state({slurp:"cancel"}); begin(); choose("window")
        driver.waitFor("window selector cancellation", () => !setup.active, () => check(!CaptureMenuService.visible
            && failures.length === 0, "window Escape is quiet"))
        state()
        const gate = {}
        driver.add("hold capture readiness", () => CaptureHandoffService.update(gate, true))
        begin(); choose("region")
        driver.add("region waits for presentation", () => check(setup.active && !CaptureMenuService.visible && !setup.operation.task, "region selection waits for presentation readiness"))
        driver.pause(30)
        driver.add("release capture readiness", () => CaptureHandoffService.update(gate, false))
        menu("Framerate"); choose("15"); menu("Audio"); choose("none")
        driver.waitFor("region options", () => !!submitted, () => check(submitted.command.includes("--geometry") && submitted.command.includes("10,20 300x200") && submitted.command.includes("15"), "owned region result and framerate"))
        state({slurp:"cancel"}); begin(); choose("region")
        driver.waitFor("selector cancellation", () => !setup.active, () => check(!CaptureMenuService.visible && failures.length === 0, "region Escape is quiet"))
        state({slurp:"invalid"}); begin(); choose("region")
        driver.waitFor("invalid region produces failure", () => !setup.active && failures.length === 1)
        state({empty:true}); begin(); output(); audio("desktop")
        driver.waitFor("empty device list produces failure", () => !setup.active && failures.length === 2)
        state({windows:"empty"}); begin(); choose("window")
        driver.waitFor("no visible windows produces failure", () => !setup.active && failures.length === 3)
        state({windows:"invalid"}); begin(); choose("window")
        driver.waitFor("invalid window metadata produces failure", () => !setup.active && failures.length === 4)
        state({slurp:"other"}); begin(); choose("window")
        driver.waitFor("window selector cannot return an unoffered rectangle", () => !setup.active && failures.length === 5)
        state({slurp:"error"}); begin(); choose("window")
        driver.waitFor("window backend failure is not cancellation", () => !setup.active && failures.length === 6)
        state({slowWindows:true}); begin(); choose("window")
        driver.waitFor("window metadata loading", () => setup.operation?.task?.command[1] === "clients")
        driver.add("cancel window metadata", () => setup.cancel())
        driver.pause(250)
        driver.add("cancelled window metadata stays closed", () => check(!setup.active && !CaptureMenuService.visible,
            "stale window metadata cannot reopen setup"))
        state({slow:true}); begin(); output(); audio("desktop")
        driver.waitFor("loading devices", () => CaptureMenuService.prompt === "Audio output")
        driver.add("replace pending choices", () => CaptureMenuService.promptMenu("Replacement", [{title:"Keep working"}], () => {}))
        driver.pause(350)
        driver.add("replacement survives stale metadata", () => {
            check(!setup.active && CaptureMenuService.visible && CaptureMenuService.prompt === "Replacement", "replacement cancels stale metadata callbacks")
            CaptureMenuService.close()
        })
        state()
        driver.add("controller opens setup", () => RecordingService.toggle())
        menu("Capture")
        driver.add("controller repeated shortcut", () => {
            CaptureMenuService.query = "reg"
            RecordingService.toggle()
            check(CaptureMenuService.query === "reg" && RecordingService.state === "configuring", "controller repeated shortcut preserves native choices")
            driver.key(Qt.Key_Escape)
        })
        driver.waitFor("controller releases cancelled native setup", () => RecordingService.state === "idle" && !CaptureMenuService.visible)
        driver.add("finished", () => console.log("PASS: native recording choices, defaults, all audio modes, window selection, device filtering, cancellation, replacement, EOF and shared region readiness"))
        driver.running = true
    }
}
