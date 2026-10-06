import QtQuick
import Quickshell
import "../../src/modules/system/totp"
import "../../src/services"

Scope {
    id: root
    property int step: 0
    property int ticks: 0
    property bool receivedEditor: false
    property string firstId: ""
    property string addedId: ""
    property real previousHeight: 0
    property var draftField: null
    property int scrollCheck: 0
    property int pinCheckTicks: 0

    QtObject { id: origin; readonly property bool totpModule: true }
    QtObject { id: otherOrigin }
    Component { id: content; Item {} }

    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const result = find(child, name)
            if (result) return result
        }
        return null
    }

    function check(condition, message) {
        if (condition) return true
        console.error("TOTP SMOKE FAIL: " + message)
        ticker.stop()
        Qt.quit()
        return false
    }

    FloatingWindow {
        visible: true
        implicitWidth: 520
        implicitHeight: 700
        TotpTooltip { id: popup; x: 20; y: 20 }
    }

    Component.onCompleted: TooltipService.show(240, content, origin, false)
    Connections {
        target: TotpService
        function onEditorLoaded(entryId, name, token) { root.receivedEditor = true }
    }

    Timer {
        id: ticker
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            root.ticks++
            if (!root.check(root.ticks < 150, "timed out at step " + root.step)) return
            if (!root.check(!TotpService.error, "backend reported an error")) return
            switch (root.step) {
            case 0:
                if (!TotpService.ready) return
                if (!root.check(TotpService.entries.count === 1, "initial list")) return
                popup.searchText = " bEtA "
                root.find(popup, "totpList").forceLayout()
                if (!root.check(root.find(popup, "totpList").count === 1, "case-insensitive token search")) return
                popup.searchText = "no matching name"
                root.find(popup, "totpList").forceLayout()
                if (!root.check(root.find(popup, "totpList").count === 0
                    && root.find(popup, "totpSearchEmpty").visible, "empty search results")) return
                popup.searchText = ""
                if (root.pinCheckTicks === 0) {
                    TooltipService.togglePin(240, content, origin, false)
                    TooltipService.hide()
                    root.pinCheckTicks = root.ticks
                    return
                }
                if (root.ticks - root.pinCheckTicks < 3) return
                if (!root.check(TooltipService.visible && TooltipService.pinned, "pinned panel closed on exit")) return
                TooltipService.show(300, content, otherOrigin, false)
                if (!root.check(TooltipService.source === origin, "hover replaced pinned panel")) return
                TooltipService.togglePin(240, content, origin, false)
                if (!root.check(!TooltipService.pinned && TooltipService.visible, "second click did not unpin")) return
                root.firstId = TotpService.entries.get(0).entryId
                const list = root.find(popup, "totpList")
                list.forceLayout()
                const codeDisplay = root.find(list.itemAtIndex(0), "totpCode") as TotpCode
                const currentCode = TotpService.entries.get(0).code
                TotpService.entries.setProperty(0, "code", currentCode === "123456" ? "654321" : "123456")
                if (!root.check(codeDisplay.spinning, "visible code rollover does not animate")) return
                popup.editingId = root.firstId
                if (!root.check(!codeDisplay.spinning, "editing did not stop code animation")) return
                TotpService.edit(root.firstId)
                root.step++
                break
            case 1:
                if (!root.receivedEditor || TotpService.busy) return
                root.draftField = root.find(popup, "totpNameField")
                if (!root.check(root.draftField && root.draftField.text === "Beta", "edit prefill")) return
                root.draftField.text = "Draft preserved"
                popup.searchText = "no matching name"
                root.find(popup, "totpList").forceLayout()
                if (!root.check(root.find(popup, "totpList").count === 1, "search hid the active editor")) return
                TotpService.request({action: "refresh"})
                root.step++
                break
            case 2:
                if (TotpService.busy) return
                if (root.scrollCheck === 0) {
                    if (!root.check(root.draftField.text === "Draft preserved", "rollover replaced edit draft")) return
                    popup.searchText = ""
                    const original = TotpService.entries.get(0)
                    const rows = [{id: original.entryId, name: original.name, code: original.code, expiresAt: original.expiresAt}]
                    for (let i = 0; i < 80; ++i)
                        rows.push({id: "test-row-" + i, name: "Other " + i, code: "123456", expiresAt: original.expiresAt})
                    root.draftField.focus = false
                    TotpService.updateEntries(rows)
                    const list = root.find(popup, "totpList")
                    list.forceLayout()
                    if (!root.check(list.contentHeight > list.height, "list does not scroll")) return
                    list.positionViewAtEnd()
                    root.scrollCheck++
                    return
                }
                if (root.scrollCheck === 1) {
                    if (!root.check(popup.draftName === "Draft preserved", "scroll lost edit draft")) return
                    root.find(popup, "totpList").positionViewAtBeginning()
                    root.scrollCheck++
                    return
                }
                if (root.scrollCheck === 2) {
                    const restored = root.find(popup, "totpNameField")
                    if (!restored) return
                    if (!root.check(restored.text === "Draft preserved", "scroll restored empty editor")) return
                    TotpService.request({action: "refresh"})
                    root.scrollCheck++
                    return
                }
                popup.cancelEditor()
                popup.searchText = ""
                root.previousHeight = popup.height
                popup.adding = true
                root.step++
                break
            case 3: {
                const editor = root.find(popup, "totpEditor")
                if (!editor) return
                if (!root.check(popup.height === root.previousHeight, "add form resized popup")) return
                root.find(editor, "totpNameField").text = "Alpha test"
                root.find(editor, "totpTokenField").text = "JBSWY3DPEHPK3PXP"
                editor.submit()
                root.step++
                break
            }
            case 4:
                if (TotpService.busy) return
                if (!root.check(TotpService.entries.count === 2 && !popup.adding, "inline add")) return
                if (!root.check(TotpService.entries.get(0).name === "Alpha test", "alphabetical model")) return
                root.addedId = TotpService.entries.get(0).entryId
                popup.searchText = " ALPHA "
                root.find(popup, "totpList").forceLayout()
                if (!root.check(root.find(popup, "totpList").count === 1, "filter after adding")) return
                popup.adding = true
                root.find(popup, "totpList").forceLayout()
                if (!root.check(root.find(popup, "totpList").count === 2
                    && !root.find(popup, "totpSearchField").visible, "adding did not suspend search")) return
                popup.cancelEditor()
                if (!root.check(popup.searchText === " ALPHA " && root.find(popup, "totpList").count === 1,
                    "search was not restored after adding")) return
                TotpService.copy(root.addedId)
                root.step++
                break
            case 5:
                if (TotpService.busy) return
                if (!root.check(TotpService.copiedId === root.addedId && /^\d{6}$/.test(Quickshell.clipboardText), "copy")) return
                TotpService.remove(root.addedId)
                root.step++
                break
            case 6:
                if (TotpService.busy) return
                if (!root.check(TotpService.entries.count === 1, "delete")) return
                // Moving the mouse restores hover dismissal after editing/typing.
                TooltipService.observePointer(0, 0, true)
                TooltipService.observePointer(1, 0, true)
                TooltipService.hide()
                root.step++
                break
            case 7:
                if (TotpService.active) return
                if (!root.check(!TotpService.ready && TotpService.entries.count === 0, "hidden state not cleared")) return
                if (!root.check(popup.searchText === "", "search persisted after closing")) return
                TooltipService.show(240, content, origin, false)
                root.step++
                break
            case 8:
                if (!TotpService.ready) return
                if (!root.check(TotpService.entries.count === 1 && TotpService.entries.get(0).name === "Beta", "reopen after shutdown")) return
                console.log("PASS: QML inline add/edit, pin/unpin, scroll and refresh preserve drafts, clipboard, delete, hover shutdown, and reopen")
                ticker.stop()
                Qt.quit()
                break
            }
        }
    }
}
