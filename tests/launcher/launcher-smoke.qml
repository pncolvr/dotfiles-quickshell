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
    }
    function check(condition, message) {
        if (!condition) { failed = true; console.error("PICKER FAIL: " + message) }
    }
    function seed() {
        if (Quickshell.env("PICKER_TEST_PHASE") === "restart") {
            check(ClipboardRepository.entries()[0]?.text === "hello\nworld\n", "clipboard survives process restart before any writes")
            console.log(failed ? "PICKER FAIL: restart" : "PASS: picker clipboard restart")
            return
        }
        check(PickerService.filter([{title:"Alpha"}, {title:"beta"}], "AL", true, false).length === 0, "smart uppercase matching")
        check(PickerService.filter([{title:"Alpha"}, {title:"beta"}], "al", true, false)[0].title === "Alpha", "case insensitive lowercase matching")
        check(PickerService.filter([{title:"Visual Studio Code"}], "vsc", false, true).length === 1, "subsequence fuzzy matching")
        check(DesktopEntries.byId("picker-test") !== null, "native application metadata")
        PickerService.begin("menu", "Pick a project")
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
        const entry = {id:"a".repeat(64),mime:"text/plain",kind:"text",bytes:12,text:"hello\nworld\n"}
        check(ClipboardRepository.add(entry) !== null, "clipboard schema accepts entry")
        check(ClipboardRepository.add(entry) !== null && ClipboardRepository.entries().length === 1, "clipboard deduplicates")
        check(ClipboardRepository.entries()[0].text === entry.text, "clipboard preserves multiline text")
        for (let index = 0; index < 4; index++) ClipboardRepository.add({id:String(index).repeat(64),mime:"text/plain",kind:"text",bytes:1,text:String(index)})
        check(ClipboardRepository.entries().length === 3 && ClipboardRepository.entries()[0].text === "3", "bounded newest-first history")
        ClipboardRepository.clear()
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
    IpcHandler {
        target: "pickertest"
        function snapshot(): string { return JSON.stringify({visible:PickerService.visible,mode:PickerService.mode,
            query:PickerService.query,items:PickerService.items,filtered:PickerService.filteredItems,currentIndex:PickerService.currentIndex,
            selected:PickerService.selectedIds,canAccept:PickerService.canAccept,acceptLabel:PickerService.acceptLabel,
            layout:PickerService.layout,
            directory:PickerService.requestDirectory}) }
        function clickControl(name: string): bool {
            const button = objects.findChild(panel.panel, name) as UI.ActionButton
            return !!button && button.enabled && events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
        }
        function accept(index: int): void { PickerService.select(index, false); PickerService.accept(false, false) }
        function custom(index: int): void { PickerService.select(index, false); PickerService.accept(true, false) }
        function select(index: int): void { PickerService.select(index, true) }
        function query(text: string): void { const search = objects.findChild(panel.panel, "pickerSearch") as UI.SearchField; search.text = text }
        function close(): void { PickerService.close() }
        function pressEscape(): void { panel.focusSearch(); events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0) }
        function enter(): void { panel.focusSearch(); events.keyClick(Qt.Key_Return, Qt.NoModifier, 0) }
        function down(): void { panel.focusSearch(); events.keyClick(Qt.Key_Down, Qt.NoModifier, 0) }
        function toggleEntry(): void { panel.focusSearch(); events.keyClick(Qt.Key_Space, Qt.ShiftModifier, 0) }
        function toggleVisible(): void { panel.focusSearch(); events.keyClick(Qt.Key_A, Qt.ControlModifier, 0) }
        function clearSelection(): void { panel.focusSearch(); events.keyClick(Qt.Key_A, Qt.ControlModifier | Qt.ShiftModifier, 0) }
        function typeSpace(): void { panel.focusSearch(); events.keyClick(Qt.Key_Space, Qt.NoModifier, 0) }
        function clipboardFixture(): void {
            PickerService.begin("clipboard", "Clipboard")
            ClipboardRepository.add({id:"c".repeat(64),mime:"text/plain",kind:"text",bytes:9,text:"delete me"})
            PickerService.syncClipboard()
            PickerService.show()
        }
        function deleteEntry(): void { panel.focusSearch(); events.keyClick(Qt.Key_Delete, Qt.NoModifier, 0) }
        function windowFocusCommand(address: string): string { return Config.hyprlandFocusWindowByAddress(address) }
        function quit(): void { Qt.quit() }
    }
    Timer { interval: 300; running: true; onTriggered: root.seed() }
}
