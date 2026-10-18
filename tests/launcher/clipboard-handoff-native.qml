pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../src/services"
import "../../src/modules/launcher"
import "../../src/ui" as UI
import "../../src/services/remotes/RemoteEntries.mjs" as Entries

// Real layer-shell activation; synthetic entries and mocked clipboard commands.
Scope {
    id: root
    property var originalPanel: null
    property var originalDraft: null
    property var field: null
    property int deliveredKeys: 0
    property bool checkingReturn: false
    property bool returnedWhileClosing: false
    property string phase: "setup"
    PickerWindow { id: main }
    PickerWindow { id: clipboard; picker: ClipboardPickerService }
    Connections {
        target: root.field ? root.field.Keys : null
        function onPressed(event) { if (event.key === Qt.Key_X) root.deliveredKeys++ }
    }
    Connections {
        target: root.field
        function onSelectedTextChanged() {
            console.log("HANDOFF SELECTION:", root.phase, JSON.stringify({
                selection: root.field.selectedText, mainActive: main.windowActive,
                clipboardActive: clipboard.windowActive, clipboardVisible: ClipboardPickerService.visible
            }))
        }
    }
    Connections {
        target: main.contentItem.Window.window
        function onActiveChanged() {
            if (root.checkingReturn && main.contentItem.Window.active && clipboard.visible)
                root.returnedWhileClosing = true
        }
    }
    NativeFocusDriver {
        id: driver
        timeout: 3000
        onFailed: message => {
            console.error("HANDOFF NATIVE FAIL:", message, JSON.stringify({
                mainActive: main.windowActive, clipboardActive: clipboard.windowActive,
                mainRequested: PickerService.visible, animationMode: Quickshell.env("HANDOFF_ANIMATIONS"),
                clipboardVisible: clipboard.visible, requested: ClipboardPickerService.visible,
                field: main.contentItem.Window.window?.activeFocusItem?.objectName,
                text: root.field?.text, selection: root.field?.selectedText,
                handoffActive: PanelFocusService.active, returning: !!PanelFocusService.returnHandler
            }))
            Qt.quit()
        }
        onCompleted: {
            console.log("PASS: native Clipboard Escape/Copy restore the original field and selection, deliver the next key once, and preserve the unsaved form")
            Qt.quit()
        }
    }
    function scenario(copyOnly, position) {
        const name = (copyOnly ? "Copy" : "Escape") + " " + position
        const start = position === "caret" ? 2 : position === "backward" ? 1 : 0
        const end = position === "caret" ? 2 : position === "backward" ? 5 : 6
        const cursor = position === "backward" ? start : end
        driver.add(name + " prepare field", () => {
            root.phase = name + " prepare"
            root.field.text = "before"
            root.field.forceActiveFocus()
            root.field.select(position === "backward" ? end : start, cursor)
            root.deliveredKeys = 0
            root.checkingReturn = false
        })
        driver.waitFor(name + " source focused", () => main.windowActive && root.field.activeFocus)
        driver.add(name + " open Clipboard", () => {
            driver.check(root.field.selectedText === "before".slice(start,end)
                && root.field.cursorPosition === cursor, "selection/caret established before handoff")
            root.phase = name + " opening"
            PickerService.clipboard()
            driver.check(PanelFocusService.target?.item === root.field, "original field captured")
        })
        driver.waitFor(name + " Clipboard activated", () => clipboard.windowActive
            && !ClipboardPickerService.searchPending && ClipboardPickerService.canAccept)
        driver.add(name + " close Clipboard", () => {
            root.phase = name + " returning"
            root.checkingReturn = true
            if (copyOnly) ClipboardPickerService.accept(false, true)
            else driver.key(Qt.Key_Escape)
        })
        driver.waitFor(name + " native return", () => !ClipboardPickerService.visible
            && main.windowActive && root.field.activeFocus && !PanelFocusService.returnHandler, () => {
                driver.check(root.field.text === "before" && root.field.selectedText === "before".slice(start,end)
                    && root.field.cursorPosition === cursor, name + " must preserve text, selection direction and caret")
                driver.check(main.panel.panel === root.originalPanel && RemoteService.draft === root.originalDraft,
                    "unsaved form identity preserved")
                driver.key(Qt.Key_X)
                driver.check(root.field.text === "before".slice(0,start) + "x" + "before".slice(end)
                    && root.deliveredKeys === 1,
                    "next native key reaches the original selected field exactly once")
                driver.check(ClipboardPickerService.query !== "x", "closed Clipboard must not receive the next key")
            })
        driver.waitFor(name + " unmap", () => !clipboard.visible)
        driver.add(name + " complete", () => { root.checkingReturn = false })
    }
    Component.onCompleted: {
        driver.waitFor("database ready", () => DbService.ready)
        driver.add("open synthetic Remotes form", () => {
            PickerService.remotes()
            RemoteService.setManaging(true)
            main.panel.panel.beginAdd()
            root.originalPanel = main.panel.panel
            root.originalDraft = RemoteService.draft
            main.panel.panel.entryForm.load(Object.assign(Entries.empty([], "ssh"), {
                name: "Unsaved synthetic SSH", endpoint: "test.example", username: "before"
            }))
            root.field = driver.find(main.panel, "remoteUsername")
            driver.check(!!root.field, "synthetic username field exists")
            ClipboardRepository.add({id:"a".repeat(64), mime:"text/plain", kind:"text", bytes:6, text:"pasted"})
        })
        driver.waitFor("Remotes activated", () => main.windowActive && !main.transitioning)
        for (const position of ["forward", "backward", "caret"]) {
            root.scenario(false, position)
            root.scenario(true, position)
        }
        driver.add("verify closing overlap and close form", () => {
            if (UI.MotionPolicy.enabled) driver.check(root.returnedWhileClosing,
                "native return must be exercised while Clipboard is still closing")
            PickerService.close()
        })
        driver.waitFor("form unmapped", () => !main.visible)
        driver.running = true
    }
}
