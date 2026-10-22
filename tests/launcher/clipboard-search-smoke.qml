pragma ComponentBehavior: Bound
import QtQml
import "../../src/services"
import "../../src/config"
import "../../src/services/launcher/Search.mjs" as Search

WorkerScope {
    id: root
    property var testConfig: Config
    property bool failed: false
    property bool waiting: false
    property int step: 0
    property int heartbeat: 0
    property var expected: []
    property var fixtureRows: []
    function fixtureId(index: int): string { return (index + 1).toString(16).padStart(64,"0") }
    readonly property var cases: [
        {query: "b", reused: false},
        {query: "ba", reused: true},
        {query: "ban", reused: true},
        {query: "b", reused: false},
        {query: "Ban", reused: false},
        {query: "BAN", reused: false},
        {query: "BANA", reused: true},
        {query: "bana a", reused: true},
        {query: "bana a", pinned: true, reused: false},
        {query: "nph", pinned: true, reused: false},
        {query: "nph z", pinned: true, reused: true},
        {query: "nph", pinned: true, reused: false}
    ]
    function check(value, message) {
        if (!value) { failed = true; console.error("SEARCH FAIL: " + message) }
    }
    function expectCurrentQuery() {
        const candidates = fixtureRows.filter(item => !PickerService.itemCriteria.pinned || item.pinned)
        // Clipboard's Fuzzy button is independent of the launcher's search setting.
        const pattern = Search.searchPattern(PickerService.query, Config.pickerSmartCase)
        expected = candidates.map((item,index) => ({item,index,
            score: Math.min(Search.score(item.title,pattern,true),
                item.search && item.search !== item.title ? Search.score(item.search,pattern,true) + 12 : Infinity)}))
            .filter(row => Number.isFinite(row.score))
            .sort((a,b) => a.score - b.score || a.index - b.index).map(row => row.item.id)
    }
    function verifyResults() {
        check(PickerService.filteredItems.map(item => item.id).join() === expected.join(),
            "worker preserves synchronous fuzzy scores, full text and source-order ties at step " + step)
    }
    Timer {
        interval: 5
        running: true
        repeat: true
        onTriggered: {
            if (!DbService.ready) return
            if (root.waiting) {
                if (PickerService.searchPending) { root.heartbeat++; return }
                root.verifyResults()
                if (root.step < root.cases.length)
                    root.check(PickerService.searchStatistics.reused === root.cases[root.step].reused,
                        "candidate reuse resets correctly at step " + root.step)
                root.waiting = false
                root.step++
            }
            if (root.step < root.cases.length) {
                if (root.step === 0) {
                    PickerService.begin(PickerService.Mode.Clipboard, "Clipboard")
                    const rows = [
                        {id:"0", title:"Banana", search:"Banana", pinned:false},
                        {id:"1", title:"Banana", search:"Banana", pinned:true},
                        {id:"2", title:"Potato", search:"Potato", pinned:false},
                        {id:"3", title:"Short preview", search:"x".repeat(40000) + "NeedlePhrase", pinned:true}
                    ]
                    for (let i = 4; i < 1000; i++)
                        rows.push({id:String(i), title:"Fixture", search:"z".repeat(600), pinned:false})
                    root.fixtureRows = rows.map((row,index) => ({id:root.fixtureId(index),title:row.search.replace(/\s+/g," ").slice(0,240),search:row.search,pinned:row.pinned}))
                    DbService.write(tx => {
                        for (let index = 0; index < root.fixtureRows.length; index++) {
                            const row = root.fixtureRows[index]
                            tx.executeSql("INSERT INTO store.clipboard(id,mime,kind,bytes,text,updated_at,pinned) VALUES(?,'text/plain','text',?,?,?,?)",[row.id,row.search.length,row.search,1000 - index,row.pinned ? 1 : 0])
                        }
                    })
                    ClipboardRepository.revision++
                    PickerService.clipboardFuzzy = true
                    PickerService.show()
                }
                root.testConfig.pickerFuzzySearch = root.step % 2 === 0
                const test = root.cases[root.step]
                if ((PickerService.itemCriteria.pinned === true) !== (test.pinned === true))
                    PickerService.itemCriteria = test.pinned ? ({pinned:true}) : ({})
                PickerService.query = test.query
                root.expectCurrentQuery()
                root.check(PickerService.searchPending && !PickerService.currentItem && !PickerService.canAccept,
                    "pending searches cannot activate a stale selection")
                root.waiting = true
            } else if (root.step === root.cases.length) {
                root.testConfig.pickerFuzzySearch = false
                // Change the history while a costly search is running; only the newest request may publish.
                PickerService.itemCriteria = ({})
                PickerService.query = "zzzzzzzz"
                PickerService.dispatchClipboardSearch()
                ClipboardRepository.remove(root.fixtureId(3))
                ClipboardRepository.add({id:root.fixtureId(1001),mime:"text/plain",kind:"text",bytes:12,text:"NeedlePhrase"})
                root.fixtureRows = [{id:root.fixtureId(1001),title:"NeedlePhrase",search:"NeedlePhrase",pinned:false},...root.fixtureRows.filter(item => item.id !== root.fixtureId(3))]
                PickerService.query = "does not match"
                PickerService.query = "nph"
                root.expectCurrentQuery()
                root.waiting = true
            } else if (root.step === root.cases.length + 1) {
                root.check(!Config.pickerFuzzySearch && PickerService.clipboardFuzzy,
                    "clipboard fuzzy matching remains enabled with launcher fuzzy matching off")
                root.check(PickerService.currentItem?.id === root.fixtureId(1001), "history replacement invalidates cached text and row indexes")
                root.check(root.heartbeat > 0, "UI timers continue while the background worker searches")
                PickerService.query = "zzzzzzzz"
                PickerService.dispatchClipboardSearch()
                PickerService.begin(PickerService.Mode.Menu, "Other picker")
                PickerService.items = [{id:"menu", title:"Banana"}]
                PickerService.query = "ban"
                root.step++
            } else {
                if (PickerService.searchRunning) return
                root.check(PickerService.currentItem?.id === "menu" && !PickerService.searchPending,
                    "late clipboard responses cannot replace another picker mode")
                console.log(root.failed ? "SEARCH FAIL: background clipboard search" :
                    "PASS: cached clipboard search, candidate reuse, smart case, history invalidation, latest-query results and UI heartbeat")
                Qt.quit()
            }
        }
    }
}
