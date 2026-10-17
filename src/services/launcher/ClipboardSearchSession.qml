pragma ComponentBehavior: Bound
import "../../i18n"
import QtQml
import QtQml.WorkerScript
import Quickshell
import Quickshell.Io
import "../"
import "../../config"

QtObject {
    id: root
    required property var owner
    readonly property bool active: owner.mode === PickerService.Mode.Clipboard && (owner.visible || owner.openingClipboard)
    property bool fuzzy: false
    property bool pending: false
    property bool failed: false
    readonly property bool busy: reader.running || workerBusy
    property bool workerBusy: false
    property int request: 0
    property var results: []
    property var statistics: ({})
    property var pendingAccept: null
    property bool hasMore: false
    property int offset: 0
    property int pageRows: 50
    property string previousId: ""
    property int fuzzyRevision: -1
    property var fuzzyMetadata: []
    property var queuedFuzzyRows: null
    signal published(var rows)
    function seed() {
        if (active && !owner.query.trim() && !Object.keys(owner.itemCriteria).length) {
            results = ClipboardRepository.previews().map(entry => row(entry))
            published(results)
        }
    }
    function row(entry) {
        return {id:entry.id,kind:entry.kind,pinned:!!entry.pinned,
            title:entry.kind === "image" ? "" : (entry.preview ?? "").replace(/\s+/g," "),
            image:entry.kind === "image" ? "file://" + Config.clipboardDirectory + "/" + entry.id : "",
            result:{id:entry.id,mime:entry.mime,kind:entry.kind,bytes:entry.bytes,pinned:!!entry.pinned,updated_at:entry.updated_at}}
    }
    function refresh(preserve = true) {
        previousId = preserve ? results[owner.currentIndex]?.id ?? "" : ""
        pageRows = preserve ? Math.min(1000,Math.max(50,Math.ceil((owner.currentIndex + 1) / 50) * 50)) : 50
        request++; pendingAccept = null; offset = 0
        failed = false; pending = active
        if (active) dispatch.restart()
    }
    function release() {
        request++; dispatch.stop(); pending = false; failed = false; pendingAccept = null
        reader.running = false; reader.input = ""; reader.output = ""
        results = []; fuzzyMetadata = []; queuedFuzzyRows = null; fuzzyRevision = -1; hasMore = false
        worker.sendMessage({clear:true})
        published([])
    }
    function more() {
        if (!active || pending || !hasMore || fuzzy) return
        previousId = results[owner.currentIndex]?.id ?? ""
        offset = results.length; request++; pending = true; pendingAccept = null; dispatch.restart()
    }
    function sendWorker(rows) {
        if (rows) queuedFuzzyRows = rows
        if (!worker.ready || workerBusy) { dispatch.restart(); return }
        const message = {generation:fuzzyRevision,request:request,query:owner.query,
            fuzzy:true,smartCase:Config.pickerSmartCase,pinnedOnly:owner.itemCriteria.pinned === true,
            kind:owner.itemCriteria.kind ?? ""}
        if (queuedFuzzyRows) { message.rows = queuedFuzzyRows; queuedFuzzyRows = null }
        workerBusy = true; worker.sendMessage(message)
    }
    function run() {
        if (!active || !pending || reader.running || workerBusy || !DbService.ready) return
        if (fuzzy && fuzzyRevision === ClipboardRepository.revision) { sendWorker(); return }
        reader.token = request
        reader.page = offset
        reader.fuzzyJob = fuzzy
        reader.take = offset ? 50 : pageRows
        const options = {engine:fuzzy ? "fuzzy" : "indexed",query:fuzzy ? "" : owner.query,
            kind:fuzzy ? "" : owner.itemCriteria.kind ?? "",pinned:!fuzzy && owner.itemCriteria.pinned === true,
            limit:reader.take + 1,offset}
        reader.input = JSON.stringify(options) + "\n"
        reader.running = true
    }
    function deliver(rows) {
        if (!fuzzy && previousId && hasMore && !rows.some(item => item.id === previousId)) {
            results = rows; published(rows); offset = rows.length; dispatch.restart(); return
        }
        results = rows; published(rows)
        owner.currentIndex = previousId ? Math.max(0,rows.findIndex(item => item.id === previousId))
            : Math.min(owner.currentIndex,Math.max(0,rows.length - 1))
        pending = false; failed = false
        const deferred = pendingAccept; pendingAccept = null
        if (deferred) Qt.callLater(() => {
            if (active && deferred.request === request) owner.accept(deferred.custom,deferred.copyOnly)
        })
    }
    onActiveChanged: { if (active) refresh(false); else release() }
    onFuzzyChanged: {
        fuzzyRevision = -1
        if (!fuzzy) { fuzzyMetadata = []; queuedFuzzyRows = null; worker.sendMessage({clear:true}) }
        refresh(false)
    }
    property Connections changes: Connections {
        target: ClipboardRepository
        function onRevisionChanged() { root.fuzzyRevision = -1; if (root.active) root.refresh() }
    }
    property Connections database: Connections {
        target: DbService
        function onReadyChanged() { if (root.active && DbService.ready) root.refresh() }
        function onErrorChanged() {
            if (root.active && !DbService.ready && DbService.error) {
                root.pending = false; root.failed = true; root.pendingAccept = null; root.owner.error = DbService.error
            }
        }
    }
    property Timer dispatch: Timer { interval: 25; onTriggered: root.run() }
    property Timer deadline: Timer {
        interval: 4000; running: reader.running
        onTriggered: { reader.running = false; root.pending = false; root.failed = true; root.pendingAccept = null; root.owner.error = Translations.text("clipboard.errors.searchTimeout") }
    }
    property Process readerProcess: Process {
        id: reader
        property int token: 0
        property int page: 0
        property bool fuzzyJob: false
        property int take: 50
        property string input: ""
        property string output: ""
        command: ["bash",Quickshell.shellPath("src/services/clipboard/query.sh"),Config.databasePath]
        stdinEnabled: true
        stdout: SplitParser { onRead: line => reader.output = root.active && reader.token === root.request ? line : "" }
        stderr: StdioCollector { waitForEnd: true }
        onStarted: { write(input); input = ""; stdinEnabled = false }
        // qmllint disable signal-handler-parameters
        onExited: (code,status) => {
            stdinEnabled = true
            const response = output; output = ""
            if (!root.active || token !== root.request) { if (root.pending) root.dispatch.restart(); return }
            let data
            try { data = JSON.parse(response) } catch (_) { data = null }
            if (code !== 0 || status !== 0 || !Array.isArray(data?.rows) || data.error) {
                root.pending = false; root.failed = true; root.pendingAccept = null; root.owner.error = Translations.text("clipboard.errors.searchUnavailable"); return
            }
            root.owner.error = ""
            if (fuzzyJob) {
                root.fuzzyMetadata = data.rows.map(entry => root.row(entry))
                root.fuzzyRevision = ClipboardRepository.revision
                root.sendWorker(data.rows.map(entry => ({title:(entry.preview ?? "").replace(/\s+/g," "),
                    search:entry.kind === "image" ? entry.mime + Translations.text("clipboard.image.suffix") : entry.search,pinned:!!entry.pinned,kind:entry.kind})))
            } else {
                root.hasMore = data.rows.length > take
                const rows = data.rows.slice(0,take).map(entry => root.row(entry))
                root.deliver(page ? root.results.concat(rows) : rows)
            }
        }
        // qmllint enable signal-handler-parameters
    }
    property WorkerScript workerEngine: WorkerScript {
        id: worker
        source: Qt.resolvedUrl("ClipboardSearch.mjs")
        onReadyChanged: if (ready && root.pending) root.dispatch.restart()
        onMessage: message => {
            root.workerBusy = false
            if (!message.cleared && root.active && root.fuzzy && message.request === root.request
                && message.generation === root.fuzzyRevision) {
                root.statistics = {reused:message.reused,candidates:message.candidates,duration:message.duration}
                root.hasMore = false
                root.deliver(message.indices.map(index => root.fuzzyMetadata[index]))
            } else if (root.pending) root.dispatch.restart()
        }
    }
}
