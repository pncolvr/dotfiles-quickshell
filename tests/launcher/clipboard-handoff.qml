pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/services"
import "../../src/modules/launcher"
import "../../src/ui" as UI
import "../../src/services/remotes/RemoteEntries.mjs" as Entries

Scope {
    id: root
    property int step: 0
    property int ticks: 0
    property bool failed: false
    property var originalPanel: null
    property var originalDraft: null
    property var originalField: null
    Test.TestResult { id: objects }
    Component { id: tooltipContent; Item {} }
    QtObject { id: tooltipSource }
    FloatingWindow {
        id: main
        visible: true
        implicitWidth: 780
        implicitHeight: 760
        property bool requestedVisible: PickerService.visible
        property var picker: PickerService
        PickerPanel { id: mainPanel; anchors.fill: parent }
        UI.WindowFocusHandler {
            id: mainFocus
            host: main
            panel: mainPanel
            focusSession: mainPanel.panel
            // Simulate compositor activation; this test never uses Wayland.
            windowActive: !ClipboardPickerService.visible
            onRequestingKeyboardFocusChanged: if (requestingKeyboardFocus) main.contentItem.Window.window.requestActivate()
            onDismissRequested: { root.check(false, "Clipboard dismissed the parent"); PickerService.close() }
        }
        UI.InputField { id: copySource; visible: false; text: "pasted" }
    }
    FloatingWindow {
        id: clipboardWindow
        visible: ClipboardPickerService.visible
        implicitWidth: 560
        implicitHeight: 550
        property bool requestedVisible: ClipboardPickerService.visible
        property var picker: ClipboardPickerService
        PickerPanel { id: clipboardPanel; picker: ClipboardPickerService; anchors.fill: parent }
        UI.WindowFocusHandler {
            host: clipboardWindow
            panel: clipboardPanel
            windowActive: ClipboardPickerService.visible
            onDismissRequested: ClipboardPickerService.close("outside")
        }
    }
    function check(value, message) {
        if (!value) { failed = true; console.error("HANDOFF FAIL:", step, message) }
    }
    function preserved() {
        check(PickerService.visible && PickerService.mode === PickerService.Mode.Remotes, "Remotes stays open")
        check(mainPanel.panel === originalPanel && RemoteService.draft === originalDraft, "panel and draft identity survive")
        check(originalField.text === "before", "unsaved username survives")
        check(originalField.selectedText === "before", "field selection survives")
        check((objects.findChild(mainPanel, "remotePassword") as UI.SecretField).text === "PUBLIC_FORM_FIXTURE", "unsaved password survives")
    }
    function openClipboard() {
        originalField.forceActiveFocus()
        PickerService.clipboard() // The same forwarding path as Meta+V and bridge IPC.
    }
    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (root.failed || ++root.ticks > 240) {
                console.error("HANDOFF FAIL: stopped at", root.step)
                Qt.quit(); return
            }
            if (!DbService.ready) return
            switch (root.step) {
            case 0:
                PickerService.remotes()
                RemoteService.setManaging(true)
                mainPanel.panel.beginAdd()
                root.step++; break
            case 1:
                root.originalPanel = mainPanel.panel
                root.originalDraft = RemoteService.draft
                mainPanel.panel.entryForm.load(Object.assign(Entries.empty([], "ssh"), {name:"Unsaved SSH", endpoint:"test.example", username:"before", password:"PUBLIC_FORM_FIXTURE"}))
                root.originalField = objects.findChild(mainPanel, "remoteUsername")
                root.originalField.selectAll()
                TooltipService.openForKeyboard(0, tooltipContent, tooltipSource, false, null)
                ClipboardRepository.add({id:"a".repeat(64), mime:"text/plain", kind:"text", bytes:6, text:"pasted"})
                root.openClipboard()
                root.step++; break
            case 2:
                if (!ClipboardPickerService.visible || ClipboardPickerService.searchPending) return
                root.preserved()
                root.check(PanelFocusService.target?.item === root.originalField, "handoff captures original field: " + PanelFocusService.target?.item?.objectName)
                root.check(mainFocus.handoffHeld && !PanelFocusService.held(PanelFocusService.handlers.find(handler => handler.handoffOwner === ClipboardPickerService)), "only underlying focus handlers are suspended")
                root.check(TooltipService.visible && TooltipService.interactionHeld, "bar tooltip is held through Clipboard")
                ClipboardPickerService.query = "pasted"
                PickerService.clipboard()
                root.check(ClipboardPickerService.query === "pasted" && PanelFocusService.hasTarget(ClipboardPickerService), "repeated Meta+V preserves query and return target")
                ClipboardPickerService.close()
                root.step++; break
            case 3:
                root.preserved()
                root.check(!PanelFocusService.active && !mainFocus.handoffHeld, "Escape releases handoff")
                root.check(main.contentItem.Window.window.activeFocusItem === root.originalField, "Escape restores the original field: " + main.contentItem.Window.window.activeFocusItem?.objectName)
                root.openClipboard()
                root.step++; break
            case 4:
                if (ClipboardPickerService.searchPending || !ClipboardPickerService.canAccept) return
                ClipboardPickerService.accept(false, true)
                root.step++; break
            case 5:
                if (ClipboardPickerService.visible) return
                root.preserved()
                root.check(!PanelFocusService.active, "Copy releases handoff without editing the field")
                copySource.selectAll(); copySource.copy()
                root.openClipboard()
                root.step++; break
            case 6:
                if (ClipboardPickerService.searchPending || !ClipboardPickerService.canAccept) return
                ClipboardPickerService.accept(false, false)
                root.step++; break
            case 7:
                if (ClipboardPickerService.visible) return
                root.check(root.originalField.text === "pasted", "Paste replaces the original field selection")
                root.check(main.contentItem.Window.window.activeFocusItem === root.originalField, "Paste restores the original field")
                root.check(mainPanel.panel === root.originalPanel && RemoteService.draft === root.originalDraft, "Paste retains the unsaved form")
                root.originalField.text = "before"; root.originalField.selectAll()
                root.openClipboard()
                root.step++; break
            case 8:
                ClipboardPickerService.close("outside")
                root.step++; break
            case 9:
                root.preserved()
                root.check(!mainFocus.openingFocus && !mainFocus.requestingKeyboardFocus, "outside dismissal does not reactivate the old panel")
                root.openClipboard()
                root.step++; break
            case 10:
                if (ClipboardPickerService.searchPending || !ClipboardPickerService.canAccept) return
                PickerService.close()
                root.check(!PanelFocusService.hasTarget(ClipboardPickerService), "closed parent invalidates paste target")
                ClipboardPickerService.accept(false, false)
                root.step++; break
            case 11:
                if (ClipboardPickerService.visible) return
                root.check(!PanelFocusService.active && !PickerService.visible, "stale return target never reopens a closed parent")
                TooltipService.dismiss()
                if (!root.failed) console.log("PASS: Clipboard preserves unsaved SSH forms and bar panels, repeat opening, Escape/Copy focus return, selected-field paste, outside dismissal and stale target safety")
                Qt.quit()
            }
        }
    }
}
