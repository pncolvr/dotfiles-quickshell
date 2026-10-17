pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/services/recording"
import "../../src/modules/launcher"

Scope {
    id: root
    property var submitted: null
    property int submittedCount: 0
    property int cancellations: 0
    property var failures: []
    Test.TestCase { id: events; when: false }
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
    function check(ok, message) { if (!ok) throw new Error(message) }
    function waitFor(predicate, message) {
        const deadline = Date.now()+4000
        while (!predicate() && Date.now()<deadline) events.wait(10)
        check(predicate(), message + " [prompt=" + CaptureMenuService.prompt + ", active=" + setup.active + ", rows=" + CaptureMenuService.items.length + ", failures=" + JSON.stringify(failures) + "]")
    }
    function state(options = {}) { control.setText(JSON.stringify(options)) }
    function menu(title) {
        waitFor(() => CaptureMenuService.visible && CaptureMenuService.prompt === title && CaptureMenuService.items.length > 0, "native " + title + " choices")
        check(CaptureMenuService.requestDirectory === "" && !!CaptureMenuService.menuCallback, "choices never use a shell request")
        const field = events.findChild(panel,"pickerSearch")
        waitFor(() => !!field && field.activeFocus, "shared input receives focus")
    }
    function choose(result) {
        const index = CaptureMenuService.filteredItems.findIndex(item => item.result === result)
        check(index>=0, "choice exists: " + result)
        CaptureMenuService.select(index,false)
        events.keyClick(Qt.Key_Return,Qt.NoModifier,0)
    }
    function cancelInput() { events.keyClick(Qt.Key_Escape,Qt.NoModifier,0); check(!setup.active && !CaptureMenuService.visible,"Escape cancels setup") }
    function begin() { submitted = null; setup.open(); menu("Capture") }
    function output() { choose("output"); menu("Output"); check(CaptureMenuService.items[0].result === "DP-1","outputs keep alphabetical order"); choose("DP-1"); menu("Framerate") }
    function audio(mode) { choose("60"); menu("Audio"); check(CaptureMenuService.items.map(item=>item.result).join(",")==="none,both,desktop,mic","audio order unchanged"); choose(mode) }
    function device(kind, other = false) {
        menu(kind === "sinks" ? "Audio output" : "Microphone")
        check(CaptureMenuService.items[0].title.endsWith(" (default)"),"default device first")
        check(CaptureMenuService.items.every(item=>!item.result.startsWith("off.")),"off profiles excluded")
        if (kind === "sources") check(CaptureMenuService.items.some(item=>item.result === "virtual.monitor"),"virtual sources retained")
        choose(kind === "sinks" ? (other ? "output.other" : "output.default") : (other ? "mic.other" : "mic.default"))
    }
    function run() {
        PickerService.promptMenu("Existing Manage",[{title:"Existing entry"}],()=>{})
        PickerService.query = "Existing"
        state()
        begin()
        check(CaptureMenuService.items.map(item=>item.result).join(",")==="output,region","capture defaults unchanged")
        check(PickerService.visible && PickerService.query === "Existing","recording capture menu preserves the ordinary launcher")
        CaptureMenuService.query = "reg"
        setup.open()
        check(CaptureMenuService.query === "reg", "repeated setup leaves current choices and query intact")
        CaptureMenuService.query = ""
        cancelInput()
        for (const point of ["Output","Framerate","Audio","Audio output","Microphone"]) {
            begin()
            choose("output"); menu("Output")
            if (point === "Output") { cancelInput(); continue }
            choose("DP-1"); menu("Framerate")
            if (point === "Framerate") { cancelInput(); continue }
            choose("60"); menu("Audio")
            if (point === "Audio") { cancelInput(); continue }
            choose(point === "Audio output" ? "desktop" : "mic")
            menu(point); cancelInput()
        }
        check(submittedCount===0 && failures.length===0,"cancelling any step never submits or reports failure")
        for (const mode of ["none","desktop","mic","both"]) {
            begin(); output(); audio(mode)
            if (mode === "desktop" || mode === "both") device("sinks")
            if (mode === "mic" || mode === "both") device("sources")
            waitFor(()=>!!submitted,"prepared native recording options")
            check(!setup.active && !CaptureMenuService.visible,"all choices close before worker handoff")
            check(submitted.command[0]==="wf-recorder" && submitted.command.includes("--no-damage") && submitted.command.includes("hevc_nvenc"),"continuous capture and encoder unchanged")
            check(submitted.command.includes("--output") && submitted.command.includes("DP-1") && submitted.command.includes("60"),"capture/framerate choices passed literally")
            switch (mode) {
              case "none": check(submitted.loopback.length===0 && !submitted.command.some(arg=>arg.startsWith("--audio=")),"no audio has no modules or flags"); break
              case "mic": check(submitted.command.includes("--audio=mic.default") && submitted.loopback.length===0,"microphone source"); break
              default:
                check(submitted.command.includes("--audio=output.monitor"),"desktop uses output monitor source")
                check(mode!=="both" || submitted.loopback.join("|")==="module-loopback|source=mic.default|sink=output.default","combined audio deferred to worker")
            }
        }
        begin(); output(); audio("both"); device("sinks",true); device("sources",true)
        check(submitted.command.includes("--audio=other.monitor") && submitted.loopback.includes("sink=output.other"),"other devices use identities rather than labels")
        const gate = {}
        CaptureHandoffService.update(gate,true)
        begin(); choose("region")
        check(setup.active && !CaptureMenuService.visible && !setup.operation.task,"region selection waits for presentation readiness")
        events.wait(30)
        CaptureHandoffService.update(gate,false)
        menu("Framerate")
        choose("15"); menu("Audio"); choose("none")
        check(submitted.command.includes("--geometry") && submitted.command.includes("10,20 300x200") && submitted.command.includes("15"),"owned region result and framerate")
        state({slurp:"cancel"}); begin(); choose("region")
        waitFor(()=>!setup.active,"selector cancellation")
        check(!CaptureMenuService.visible && failures.length===0,"region Escape is quiet")
        state({slurp:"invalid"}); begin(); choose("region")
        waitFor(()=>!setup.active && failures.length===1,"invalid region produces failure")
        state({empty:true}); begin(); output(); audio("desktop")
        waitFor(()=>!setup.active && failures.length===2,"empty device list produces failure")
        state({slow:true}); begin(); output(); audio("desktop")
        waitFor(()=>CaptureMenuService.prompt==="Audio output","loading devices")
        CaptureMenuService.promptMenu("Replacement",[{title:"Keep working"}],()=>{})
        events.wait(350)
        check(!setup.active && CaptureMenuService.visible && CaptureMenuService.prompt==="Replacement","replacement cancels stale metadata callbacks")
        CaptureMenuService.close()
        state()
        RecordingService.toggle()
        menu("Capture")
        CaptureMenuService.query = "reg"
        RecordingService.toggle()
        check(CaptureMenuService.query === "reg" && RecordingService.state === "configuring", "controller repeated shortcut preserves native choices")
        events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
        waitFor(() => RecordingService.state === "idle" && !CaptureMenuService.visible, "controller releases cancelled native setup")
        console.log("PASS: native recording choices, defaults, all audio modes, device filtering, cancellation, replacement, EOF and shared region readiness")
    }
    Timer {
        interval:25; running:true; repeat:true
        onTriggered: {
            if (!DbService.ready) return
            stop()
            try { root.run() } catch(error) { console.error("SETUP FAIL:",error) }
            setup.cancel(); CaptureMenuService.close(); events.wait(30); Qt.quit()
        }
    }
}
