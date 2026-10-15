pragma ComponentBehavior: Bound

import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/modules/launcher"
import "../../src/theme/ui" as UI
import "../../src/config"

Scope {
    id: root
    property bool failed: false
    Test.TestEvent { id: events }
    Test.TestResult { id: objects }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 560
        implicitHeight: 550
        PickerPanel { id: panel }
        UI.InputField { id: pasteSource; visible: false; text: "Beta" }
    }
    function check(condition, message) {
        if (!condition) { failed = true; console.error("PICKER FAIL: " + message) }
    }
    function seed() {
        if (Quickshell.env("PICKER_TEST_PHASE") === "restart") {
            check(ClipboardRepository.entries()[0]?.text === "hello\nworld\n", "clipboard survives process restart before any writes")
            const pinned = ClipboardRepository.entries()[0]
            check(pinned?.pinned === 1, "clipboard pin survives restart")
            const newId = "f".repeat(64)
            check(ClipboardRepository.add({id:newId,mime:"text/plain",kind:"text",bytes:1,text:"f"})?.includes(newId), "pins exceeding the byte limit evict new unpinned entries")
            check(ClipboardRepository.entries().length === 1 && ClipboardRepository.entries()[0].id === pinned.id, "over-limit pin is kept")
            check(ClipboardRepository.setPinned(pinned.id, false)?.includes(pinned.id) && !ClipboardRepository.entries().length, "unpin reapplies history limits")
            console.log(failed ? "PICKER FAIL: restart" : "PASS: picker clipboard restart")
            return
        }
        const legacy = ClipboardRepository.entries()[0]
        check(DbService.schemaVersion === 11 && legacy?.text === "legacy" && legacy.pinned === 0, "v5 migration preserves history and defaults existing entries to unpinned")
        check(DbService.read("SELECT name FROM store.sqlite_master WHERE type = 'index' AND name = 'clipboard_updated_at'")?.length === 1,
            "migration creates the clipboard ordering index")
        ClipboardRepository.clear()
        check(PickerService.filter([{title:"Banana"}, {title:"potato"}], "BAN")[0].title === "Banana", "uppercase-only queries ignore case")
        check(PickerService.filter([{title:"Banana"}, {title:"banana"}], "Ban").length === 1, "mixed-case queries respect capitalization")
        check(PickerService.filter([{title:"Banana"}], "bAn").length === 0, "incorrect mixed case rejects an entry")
        check(PickerService.filter([{title:"Banana 123"}], "BAN 123").length === 1, "digits and spaces do not make uppercase queries mixed case")
        check(PickerService.filter([{title:"Banana tomato"}], "BAN tmt").length === 0, "mixed case applies across the whole query")
        check(PickerService.filter([{title:"Éclair"}], "ÉCL").length === 1, "uppercase accented queries ignore case")
        check(PickerService.filter([{title:"éclair"}], "Écl").length === 0, "mixed-case accented queries respect case")
        check(PickerService.filter([{title:"Banana"}, {title:"potato"}], "ban")[0].title === "Banana", "case insensitive lowercase matching")
        check(PickerService.filter([{title:"Banana"}], "bna").length === 1, "missing letters still match")
        check(PickerService.filter([{title:"Potato"}], "ptt").length === 1, "subsequence fuzzy matching")
        check(PickerService.filter([{title:"Tomato"}], "tmt").length === 1, "all launcher search uses subsequences")
        check(PickerService.filter([{title:"B---a---n"}, {title:"Banana"}], "ban")[0].title === "Banana", "compact consecutive matches rank first")
        check(PickerService.filter([{title:"xbanana"}, {title:"Fresh banana"}], "ban")[0].title === "Fresh banana", "word starts rank ahead of interior matches")
        check(PickerService.filter([{title:"PurpleTallTree"}, {title:"Potato"}], "ptt")[0].title === "PurpleTallTree", "camel-case initials receive word-start bonuses")
        check(PickerService.score("b---a---n banana", "ban") < PickerService.score("b---a---n", "ban"), "later compact matches beat greedy early matches")
        check(PickerService.filter([{title:"Potato", search:"banana"}, {title:"Banana"}], "ban")[0].title === "Banana", "title matches rank ahead of metadata")
        check(PickerService.filter([{title:"Banana tomato"}], "tmt bna").length === 1, "query words match independently")
        check(PickerService.filter([{title:"Banana"}], "bnz").length === 0, "missing query characters reject an entry")
        check(PickerService.filter([{title:"Banana", result:1}, {title:"Banana", result:2}], "ban")[0].result === 1, "ties preserve source order")
        const longClipboardText = "x".repeat(40000) + "NeedlePhrase"
        const clipboardRow = {title:"Short preview", search:longClipboardText}
        check(PickerService.filter([clipboardRow], "nph")[0] === clipboardRow,
            "fuzzy clipboard search reaches text beyond the preview")
        check(PickerService.filter([clipboardRow], "nph z").length === 0,
            "long clipboard entries must match every query word")
        check(PickerService.score("a".repeat(40000), "aa") === -28,
            "repeated characters keep consecutive-match ranking in long entries")
        check(PickerService.score("a".repeat(40000), "az") === Infinity,
            "long entries with a missing subsequence are rejected")
        check(PickerService.filter([{title:"Banana", search:"Banana", result:1},
            {title:"Banana", result:2}], "ban")[0].result === 1,
            "identical title and metadata preserve source-order ties")
        check(DesktopEntries.byId("picker-test") !== null, "native application metadata")
        PickerService.begin(PickerService.Mode.Menu, "Pick a project")
        PickerService.multiple = true
        PickerService.items = [{id:"0", title:"Same", result:"first"}, {id:"1", title:"Same", result:"second"}]
        PickerService.show()
        PickerService.select(1, true)
        check(PickerService.selectedIds.join() === "1", "duplicate labels preserve item identity")
        const search = objects.findChild(panel.panel, "pickerSearch") as UI.SearchField
        search.text = "Same"
        check(PickerService.query === "Same" && !TooltipService.typingPaused, "picker search does not pause tooltips")
        PickerService.close()
        check(search.text === "", "closing clears search")
        PickerService.begin(PickerService.Mode.Windows, "Windows")
        PickerService.layout = "expose"
        PickerService.items = [{id: "0x1", result: "0x1", workspaceId: 1, title: "Start"},
            {id: "0x2", result: "0x2", workspaceId: 2, title: "Destination"}]
        PickerService.selectExposeWorkspace(2)
        PickerService.query = "Destination"
        PickerService.toggleExposeAll()
        check(PickerService.exposeWorkspace === 0 && Object.keys(PickerService.itemCriteria).length === 0,
            "Exposé all toggle removes workspace criteria")
        PickerService.toggleExposeAll()
        check(PickerService.exposeWorkspace === 2 && PickerService.itemCriteria.workspaceId === 2
            && PickerService.query === "Destination", "Exposé toggle restores its source workspace and preserves the query")
        PickerService.query = ""
        PickerService.selectExposeWorkspace(1)
        PickerService.toggleExposeAll()
        PickerService.toggleExposeAll()
        check(PickerService.exposeWorkspace === 1, "Exposé toggle remembers the latest source workspace")
        PickerService.selectExposeWorkspace(0)
        PickerService.show()
        PickerService.select(1, false)
        PickerService.accept(false, false)
        check(!PickerService.visible && PickerService.exposeCloseTarget?.result === "0x2"
            && PickerService.exposeCloseTarget?.workspaceId === 2, "Exposé retains the selected destination for animation and deferred activation")
        PickerService.begin(PickerService.Mode.Windows, "Windows")
        check(PickerService.exposeCloseTarget === null, "opening another picker cancels pending Exposé activation")
        PickerService.layout = "expose"
        PickerService.close()
        check(PickerService.exposeCloseTarget === null, "cancelling Exposé does not activate the hovered window")
        const entry = {id:"a".repeat(64),mime:"text/plain",kind:"text",bytes:12,text:"hello\nworld\n"}
        check(ClipboardRepository.add(entry) !== null, "clipboard schema accepts entry")
        check(ClipboardRepository.add(entry) !== null && ClipboardRepository.entries().length === 1, "clipboard deduplicates")
        check(ClipboardRepository.entries()[0].text === entry.text, "clipboard preserves multiline text")
        for (let index = 0; index < 4; index++) ClipboardRepository.add({id:String(index).repeat(64),mime:"text/plain",kind:"text",bytes:1,text:String(index)})
        check(ClipboardRepository.entries().length === 3 && ClipboardRepository.entries()[0].text === "3", "bounded newest-first history")
        ClipboardRepository.clear()
        testClipboardPins()
        ClipboardRepository.add(entry)
        ClipboardService.togglePaused()
        check(ClipboardService.paused && PreferencesRepository.value("clipboard.paused", false), "pause preference")
        ClipboardService.togglePaused()
        check(!ClipboardService.paused, "resume preference")
        ClipboardService.ignoreTextOnce("123456")
        ClipboardService.receive(JSON.stringify({id:"b".repeat(64),mime:"text/plain",kind:"text",bytes:6,text:"123456"}))
        check(ClipboardRepository.entries().length === 1, "TOTP codes excluded")
        console.log(failed ? "PICKER FAIL: smoke checks" : "PASS: picker filtering, shared controls, stable IDs, clipboard persistence and TOTP exclusion")
    }
    function testClipboardPins() {
        const image = {id:"e".repeat(64),mime:"image/png",kind:"image",bytes:20,text:""}
        ClipboardRepository.add(image)
        check(ClipboardRepository.setPinned(image.id, true) !== null, "image can be pinned")
        for (let index = 0; index < 4; index++) {
            ClipboardRepository.add({id:String(index).repeat(64),mime:"text/plain",kind:"text",bytes:4,text:String(index)})
        }
        check(ClipboardRepository.entries().length === 2 && ClipboardRepository.entries().some(row => row.id === image.id && row.pinned === 1), "old pinned image survives byte-based pruning")
        ClipboardRepository.add(image)
        check(ClipboardRepository.entries()[0].id === image.id && ClipboardRepository.entries()[0].pinned === 1, "recopying a pinned image preserves its pin")
        ClipboardRepository.clear()
        check(ClipboardRepository.entries().length === 1 && ClipboardRepository.entries()[0].id === image.id, "clear preserves pinned entries")
        ClipboardRepository.remove(image.id)
        const text = {id:"e".repeat(64),mime:"text/plain",kind:"text",bytes:1,text:"pinned"}
        ClipboardRepository.add(text)
        ClipboardRepository.setPinned(text.id, true)
        for (let index = 0; index < 4; index++) {
            ClipboardRepository.add({id:String(index).repeat(64),mime:"text/plain",kind:"text",bytes:1,text:String(index)})
        }
        check(ClipboardRepository.entries().length === 3 && ClipboardRepository.entries().some(row => row.id === text.id && row.pinned === 1), "old pinned text survives entry-count pruning")
        ClipboardRepository.setPinned(text.id, false)
        ClipboardRepository.add({id:"f".repeat(64),mime:"text/plain",kind:"text",bytes:1,text:"f"})
        check(!ClipboardRepository.entries().some(row => row.id === text.id), "unpinned old entry becomes eligible for pruning")
        ClipboardRepository.clear()
    }
    IpcHandler {
        target: "pickertest"
        function launchTestApplication(): void {
            PickerService.apps()
            const index = PickerService.items.findIndex(item => item.result === "picker-test")
            root.check(index >= 0, "test application is available")
            if (index < 0) return
            PickerService.currentIndex = index
            PickerService.accept(false, false)
        }

        function snapshot(): string {
            const viewer = objects.findChild(panel.panel, "imageViewer") as Image
            const image = viewer ?? objects.findChild(panel.panel, "clipboardLargeImage") as Image
            const hint = objects.findChild(panel.panel, "pickerEmptyHint") as UI.Text
            const search = objects.findChild(panel.panel, "pickerSearch") as UI.SearchField
            const list = objects.findChild(panel.panel, "pickerList") as UI.PickerList
            const rowImages = list?.contentItem.children.map(row => objects.findChild(row, "pickerRowImage") as Image).filter(image => !!image) ?? []
            return JSON.stringify({visible:PickerService.visible,mode:PickerService.mode,
            rowImageSources:rowImages.map(image => image.source.toString()),
            movePointer:PickerService.movePointer,imageOnly:PickerService.imageOnly,emptyHintVisible:hint?.visible ?? false,
            previewSmooth:image?.smooth ?? true,previewMipmap:image?.mipmap ?? true,
            previewWidth:image?.width ?? 0,sourceWidth:image?.implicitWidth ?? 0,
            panelHeight:panel.panel?.height ?? 0,listHeight:list?.height ?? 0,listImplicitHeight:list?.implicitHeight ?? 0,
            viewerHints:viewer ? panel.panel.children.filter(child => child instanceof UI.ShortcutHints).length : 0,
            emptyHint:hint?.text ?? "",placeholder:search?.placeholderText ?? "",footerHint:panel.panel?.footerHint ?? "",
            previewImages:PickerService.previewImages,previewSource:image?.source.toString() ?? "",
            previewStatus:image?.status ?? Image.Null,stackedPreview:panel.panel?.stackedPreview ?? false,
            searchPending:PickerService.searchPending,query:PickerService.query,items:PickerService.items,filtered:PickerService.filteredItems,currentIndex:PickerService.currentIndex,
            selected:PickerService.selectedIds,canAccept:PickerService.canAccept,acceptLabel:PickerService.acceptLabel,
            layout:PickerService.layout,itemCriteria:PickerService.itemCriteria,selectionKey:PickerService.selectionKey,
            directory:PickerService.requestDirectory}) }
        function clickControl(name: string): bool {
            const button = objects.findChild(panel.panel, name) as UI.ActionButton
            return !!button && button.enabled && events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
        }
        function accept(index: int): void { PickerService.select(index, false); PickerService.accept(false, false) }
        function custom(index: int): void { PickerService.select(index, false); PickerService.accept(true, false) }
        function select(index: int): void { PickerService.select(index, true) }
        function imageViewport(width: int, height: int): void {
            window.width = width; window.height = height
            panel.availableContentWidth = width; panel.availableContentHeight = height
        }
        function query(text: string): void { const search = objects.findChild(panel.panel, "pickerSearch") as UI.SearchField; search.text = text }
        function close(): void { PickerService.close() }
        function pressEscape(): void { panel.focusSearch(); events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0) }
        function enter(): void { panel.focusSearch(); events.keyClick(Qt.Key_Return, Qt.NoModifier, 0) }
        function down(): void { panel.focusSearch(); events.keyClick(Qt.Key_Down, Qt.NoModifier, 0) }
        function toggleEntry(): void { panel.focusSearch(); events.keyClick(Qt.Key_Space, Qt.ShiftModifier, 0) }
        function toggleVisible(): void { panel.focusSearch(); events.keyClick(Qt.Key_A, Qt.ControlModifier, 0) }
        function clearSelection(): void { panel.focusSearch(); events.keyClick(Qt.Key_A, Qt.ControlModifier | Qt.ShiftModifier, 0) }
        function pasteFixture(replaceSelection: bool): bool {
            pasteSource.selectAll()
            pasteSource.copy()
            const search = objects.findChild(panel.panel, "pickerSearch") as UI.SearchField
            if (replaceSelection) search.selectAll()
            else search.cursorPosition = search.text.length
            panel.focusSearch()
            events.keyClick(Qt.Key_V, Qt.ControlModifier, 0)
            return search.activeFocus
        }
        function typeSpace(): void { panel.focusSearch(); events.keyClick(Qt.Key_Space, Qt.NoModifier, 0) }
        function clipboardFixture(): void {
            PickerService.begin(PickerService.Mode.Clipboard, "Clipboard")
            ClipboardRepository.add({id:"c".repeat(64),mime:"text/plain",kind:"text",bytes:9,text:"delete me"})
            PickerService.syncClipboard()
            PickerService.show()
        }
        function copyEntry(): void {
            panel.focusSearch()
            const search = objects.findChild(panel.panel, "pickerSearch") as UI.SearchField
            search.selectAll()
            events.keyClick(Qt.Key_C, Qt.ControlModifier, 0)
        }
        function deferredCopy(): void {
            PickerService.query = "unmatched"
            PickerService.dispatchClipboardSearch()
            const list = objects.findChild(panel.panel, "pickerList") as UI.PickerList
            root.check(list.count > 0 && list.itemAtIndex(0)?.enabled === false,
                "pending clipboard searches disable activation of stale rows")
            PickerService.query = "hello"
            PickerService.accept(false, true)
        }
        function deleteEntry(): void { panel.focusSearch(); events.keyClick(Qt.Key_Delete, Qt.NoModifier, 0) }
        function togglePin(): void { panel.focusSearch(); events.keyClick(Qt.Key_P, Qt.ControlModifier, 0) }
        function togglePinnedOnly(): void { panel.focusSearch(); events.keyClick(Qt.Key_P, Qt.ControlModifier | Qt.ShiftModifier, 0) }
        function windowFocusCommand(address: string): string { return Config.hyprlandFocusWindowByAddress(address) }
        function quit(): void { Qt.quit() }
    }
    Timer { interval: 300; running: true; onTriggered: root.seed() }
}
