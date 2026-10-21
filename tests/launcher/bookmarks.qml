pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/config"
import "../../src/theme"
import "../../src/ui" as UI
import "../../src/modules/launcher"

WorkerScope {
    id: root
    readonly property var settings: Config
    property int replacementCalls: 0
    property var field: null
    Test.TestCase { id: events; when: false }
    FloatingWindow {
        visible: true
        implicitWidth: 640
        implicitHeight: 400
        PickerPanel { id: panel; anchors.fill: parent }
    }
    FileView { id: writer; path: Config.bookmarkFile; preload: false; blockWrites: true; printErrors: false }
    FileView {
        id: launches
        path: Quickshell.env("BOOKMARK_TEST_DIR") + "/launches"
        preload: false
        blockLoading: true
        printErrors: false
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function waitFor(predicate, message) {
        const deadline = Date.now() + 2000
        while (!predicate() && Date.now() < deadline) events.wait(10)
        check(predicate(), message)
    }
    function browserCalls() {
        launches.reload()
        return launches.text().trim().split("\n").filter(line => line).map(line => JSON.parse(line))
    }
    function waitCalls(count) { waitFor(() => browserCalls().length === count, "expected browser call count " + count) }
    function openList(initialQuery = "") {
        BookmarkService.open()
        field = events.findChild(panel, "pickerSearch")
        if (initialQuery) field.text = initialQuery
        waitFor(() => PickerService.items.length > 1, "bookmark file loaded asynchronously")
        check(PickerService.visible && PickerService.multiple && PickerService.allowTyped && PickerService.requestDirectory === "",
            "shared native menu permits multiple/typed choices without external request")
        field = events.findChild(panel, "pickerSearch")
        waitFor(() => !!field && field.activeFocus, "shared search receives focus")
    }
    function run() {
        if (Quickshell.env("BOOKMARK_TEST_MISSING") === "1") {
            BookmarkService.open()
            waitFor(() => PickerService.error.length > 0, "missing source has visible error")
            field = events.findChild(panel, "pickerSearch")
            check(PickerService.items.length === 0 && PickerService.visible, "missing source cannot reuse stale rows")
            field.text = "https://example.test/typed-after-error"
            events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
            waitCalls(5)
            console.log("PASS: native Bookmarks reports missing sources and still accepts a typed URL")
            return
        }
        const parsed = BookmarkService.parse("\n https://example.test/a  Café name\r\n\thttps://example.test/b\nhttps://example.test/c Last line")
        check(parsed.length === 3 && parsed[0].title === "Café name" && parsed[1].title === parsed[1].result
            && parsed[2].title === "Last line", "parse whitespace, Unicode, URL-only, CRLF and final unterminated lines")
        writer.setText("https://example.test/z Zulu\nhttps://example.test/a Alpha\nhttps://example.test/b Alpha\n")
        root.settings.bookmarksEnabled = false
        PickerService.promptMenu("Other panel",[{title:"Keep"}],() => {})
        BookmarkService.open()
        BookmarkService.launch([{result:"https://example.test/must-not-open"}])
        events.wait(30)
        check(PickerService.prompt === "Other panel" && browserCalls().length === 0,
            "disabled bookmarks preserve other panels and never launch")
        root.settings.bookmarksEnabled = true
        const sourcePath = root.settings.bookmarkFile
        root.settings.bookmarkFile = ""
        BookmarkService.open()
        check(!BookmarkService.enabled && PickerService.prompt === "Other panel",
            "blank source disables bookmarks without disturbing another menu")
        root.settings.bookmarkFile = sourcePath
        PickerService.close()
        openList()
        root.settings.bookmarksEnabled = false
        check(!PickerService.visible && !BookmarkService.enabled,"disabling closes its own menu")
        root.settings.bookmarksEnabled = true
        openList("Alpha")
        const selectButton = events.findChild(panel,"pickerSelectVisible") as UI.ActionButton
        const acceptButton = events.findChild(panel,"pickerAccept") as UI.ActionButton
        check(!selectButton.label && !acceptButton.label && selectButton.glyph === Theme.selectVisibleIcon
            && acceptButton.glyph === Theme.openLinksIcon && selectButton.hint.length > 0
            && acceptButton.hint === PickerService.acceptLabel,"icon-only selection and open actions retain tooltips")
        check(Math.abs(acceptButton.parent.x + acceptButton.x + acceptButton.width - acceptButton.parent.parent.width) < 1,
            "selection actions are right-aligned")
        check(PickerService.query === "Alpha", "typing during loading is retained")
        check(panel.panel.openedListHeight > Theme.pickerRowHeight * 2, "async rows receive the shared list height without refocusing")
        check(field.activeFocus, "native menu focuses the shared search")
        check(JSON.stringify(PickerService.items.map(item => item.title)) === JSON.stringify(["Alpha","Alpha","Zulu"])
            && new Set(PickerService.items.map(item => item.id)).size === 3, "sorted duplicate titles retain distinct stable source IDs")
        field.text = "Alpha"
        check(PickerService.filteredItems.length === 2, "normal search filters rows")
        PickerService.select(0, true)
        PickerService.select(1, true)
        events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
        check(!PickerService.visible && !PickerService.menuCallback, "accept closes menu and clears callback")
        waitCalls(2)
        let calls = browserCalls()
        check(JSON.stringify(calls.map(call => call.args.slice(-1)[0]).sort()) === JSON.stringify(["https://example.test/a","https://example.test/b"]),
            "multi-selection opens every selected URL once")
        const literal = "https://example.test/?q=$(touch " + Quickshell.env("HOME") + "/injected);'Café'"
        openList()
        field.text = literal
        check(PickerService.filteredItems.length === 0, "typed URL has no bookmark match")
        events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
        waitCalls(3)
        calls = browserCalls()
        check(calls.slice(-1)[0].args.length === 2 && calls.slice(-1)[0].args[0] === "--profile=unchanged" && calls.slice(-1)[0].args[1] === literal,
            "configured command arguments and typed URL remain literal")
        openList()
        events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
        events.wait(30)
        check(!PickerService.visible && browserCalls().length === 3, "Escape never launches a browser")
        writer.setText("https://example.test/single Only one\n")
        BookmarkService.open()
        PickerService.close()
        events.wait(50)
        check(!PickerService.visible && browserCalls().length === 3, "cancelled file read cannot reopen or launch")
        BookmarkService.open()
        PickerService.promptMenu("Replacement", [{title: "Keep working"}], () => root.replacementCalls++)
        events.wait(50)
        check(PickerService.prompt === "Replacement" && PickerService.items.length === 1 && browserCalls().length === 3,
            "late file load cannot overwrite or activate another menu")
        PickerService.accept(false, false)
        check(replacementCalls === 1, "replacement retains its callback")
        BookmarkService.open()
        waitCalls(4)
        check(!PickerService.visible && browserCalls().slice(-1)[0].args.slice(-1)[0] === "https://example.test/single",
            "single entry opens directly without accepting a menu")
        writer.setText("")
        BookmarkService.open()
        waitFor(() => !PickerService.visible, "empty source closes without launch")
        check(browserCalls().length === 4, "empty source never opens a browser")
        writer.setText("https://example.test/new Updated\nhttps://example.test/other Other\n")
        openList()
        check(PickerService.items.some(item => item.title === "Updated") && PickerService.items.every(item => item.title !== "Alpha"),
            "reopening reads file changes instead of stale cached results")
        PickerService.close()
        console.log("PASS: native Bookmarks parsing, sorted search, multi/typed acceptance, literal argv, Escape, refresh, empty/single and stale-read cancellation")
    }
    Timer {
        interval: 25; running: true; repeat: true
        onTriggered: {
            if (!DbService.ready) return
            stop()
            try { root.run() } catch (error) { console.error("BOOKMARK FAIL:", error) }
            PickerService.close()
            Qt.quit()
        }
    }
}
