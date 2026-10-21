pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../../../src/services"
import "../../../src/config"
WorkerScope {
    id: root
    property bool failed: false
    property bool started: false
    property int captured: 0
    property int replies: 0
    property int heartbeats: 0
    property int maxGap: 0
    property real previousBeat: 0
    property bool finishing: false
    function check(ok,message) { if (!ok) { failed = true; console.error("CONTENTION FAIL:",message) } }
    readonly property bool loadCaptureService: ClipboardService.initialized
    Connections {
        target: PickerService
        function onSearchPendingChanged() { if (root.started && !PickerService.searchPending && !PickerService.searchFailed) root.replies++ }
    }
    Process {
        id: heldRead
        command: ["bash",Quickshell.env("CONTENTION_TEST_READER"),Config.databasePath]
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
    }
    Timer {
        interval: 10; repeat: true; running: root.started
        onTriggered: {
            const now = Date.now()
            if (root.previousBeat) root.maxGap = Math.max(root.maxGap,now - root.previousBeat)
            root.previousBeat = now; root.heartbeats++
        }
    }
    Timer {
        id: capture
        interval: 40; repeat: true; running: true
        onTriggered: {
            if (!DbService.ready || !ClipboardService.initialized) return
            if (!root.started) {
                const text = "contention synthetic fixture ".repeat(750)
                root.check(DbService.write(tx => {
                    for (let i = 0; i < 1000; i++) tx.executeSql("INSERT INTO store.clipboard(id,mime,kind,bytes,text,updated_at,pinned) VALUES(?,'text/plain','text',?,?,?,0)",[(i+1).toString(16).padStart(64,"0"),text.length,text,i])
                }),"seed history")
                ClipboardRepository.revision++
                PickerService.begin(PickerService.Mode.Clipboard,"Fixture"); PickerService.show(); PickerService.query = "contention"
                root.started = true; return
            }
            if (root.captured < 80) {
                const id = (root.captured + 2000).toString(16).padStart(64,"0")
                const payload = JSON.stringify({id,mime:root.captured % 4 ? "text/plain" : "image/png",kind:root.captured % 4 ? "text" : "image",bytes:100,text:root.captured % 4 ? "contention captured fixture " + root.captured : ""})
                ClipboardService.receive(payload,false)
                root.check(!ClipboardService.error,"capture remains writable during reads")
                if (root.captured === 5) heldRead.running = true
                if (root.captured === 30) PickerService.clipboardFuzzy = true
                if (root.captured === 45) PickerService.clipboardFuzzy = false
                root.captured++
                return
            }
            if (PickerService.searchPending || heldRead.running) return
            stop()
            root.check(!PickerService.searchFailed && PickerService.canAccept && root.replies > 0,"search settles after concurrent captures")
            root.check(root.heartbeats > 80 && root.maxGap < 700,"renderer heartbeat remains responsive")
            root.check(ClipboardRepository.count() === 1000,"retention remains bounded")
            root.check(DbService.read("SELECT count(*) AS count FROM store.clipboard WHERE updated_at > 1000")?.[0]?.count === 80,"all incoming captures survive")
            root.check(DbService.write(tx => tx.executeSql("INSERT INTO store.clipboard_fts(clipboard_fts,rank) VALUES('integrity-check',1)")),"concurrent index integrity")
            PickerService.close()
            console.log("CONTENTION METRICS",JSON.stringify({captures:root.captured,replies:root.replies,heartbeats:root.heartbeats,maxGapMs:root.maxGap}))
            if (!root.failed) console.log("PASS: capture/search contention, image JSON, fuzzy switching, retention and index integrity")
            Qt.quit()
        }
    }
}
