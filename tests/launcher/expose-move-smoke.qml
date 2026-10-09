import QtQuick
import Quickshell
import "../../src/services"

Scope {
    id: root
    property var windowSource: WindowService
    property var snapshot: null
    property int step: 0
    property bool failed: false
    function check(ok, message) {
        if (!ok) { failed = true; console.error("EXPOSE FAIL:", message) }
    }
    function clients(firstWorkspace, secondWorkspace) {
        return [firstWorkspace, secondWorkspace].map((workspace, index) => ({
            address: "0x" + (index + 1), title: "Window " + index, class: "test", mapped: true,
            workspace: {id: workspace, name: String(workspace)}, at: [index * 400, 0], size: [400, 300],
            focusHistoryID: index
        }))
    }
    function checkWorkspaceOrder() {
        const windows = [
            {address: "0x3", title: "Cache", class: "com.mitchellh.ghostty", at: [1283, 738], size: [1275, 700], focusHistoryID: 0},
            {address: "0x2", title: "Files", class: "pcmanfm-qt", at: [1283, 32], size: [1275, 700], focusHistoryID: 1},
            {address: "0x1", title: "Theme.qml", class: "com.microsoft.VSCode", at: [2, 32], size: [1275, 1406], focusHistoryID: 2}
        ].map(client => Object.assign({}, client, {mapped: true, workspace: {id: 4, name: "4"}, grouped: [client.address]}))
        root.windowSource.allWindows = windows
        const order = PickerService.windowItems("all", true).map(entry => entry.client.class)
        root.check(order.join(",") === "com.microsoft.VSCode,pcmanfm-qt,com.mitchellh.ghostty",
            "special workspace follows desktop order: Code left, file manager top right, terminal bottom right")
        root.check(PickerService.windowItems("all")[0].id === "0x3",
            "regular window picker retains focus-history order")
        root.windowSource.allWindows = windows.slice(0, 2).map(client => Object.assign({}, client, {
            at: [1283, 32], grouped: ["0x2", "0x3"]
        }))
        root.check(PickerService.windowItems("all", true).map(entry => entry.id).join(",") === "0x3,0x2",
            "tabs sharing a window group retain alphabetical display-name order")
    }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (root.step === 0) {
                PickerService.begin("windows", "Windows")
                PickerService.layout = "expose"
                PickerService.selectExposeWorkspace(0)
                PickerService.show()
                root.windowSource.allWindows = root.clients(1, 1)
                root.snapshot = PickerService.items
                PickerService.exposeDragging = true
                root.check(PickerService.moveExposeWindow("0x1", 2), "valid move is accepted")
            } else if (root.step === 1) {
                root.windowSource.allWindows = root.clients(1, 1)
                PickerService.exposeDragging = false
                root.check(PickerService.items === root.snapshot && PickerService.exposePendingMoves["0x1"] === 2,
                    "stale snapshot remains frozen after the drag ends")
            } else if (root.step === 2) {
                root.windowSource.allWindows = root.clients(2, 1)
                root.check(PickerService.items !== root.snapshot
                    && PickerService.items.find(item => item.id === "0x1").workspaceId === 2
                    && !Object.keys(PickerService.exposePendingMoves).length,
                    "confirmed move publishes the destination snapshot")
                root.snapshot = PickerService.items
                root.check(PickerService.moveExposeWindow("0x2", 3), "second move is accepted")
                root.windowSource.allWindows = root.clients(2, 1)
            } else if (root.step === 3) {
                root.check(PickerService.items === root.snapshot, "unconfirmed move does not publish old grid data")
            } else if (root.step === 13) {
                root.check(PickerService.items !== root.snapshot
                    && !Object.keys(PickerService.exposePendingMoves).length,
                    "unconfirmed move times out and restores a usable grid")
                root.snapshot = PickerService.items
                PickerService.moveExposeWindow("0x1", 3)
                PickerService.moveExposeWindow("0x2", 2)
                root.windowSource.allWindows = root.clients(3, 1)
                root.check(PickerService.items === root.snapshot, "multiple moves wait for every destination")
                root.windowSource.allWindows = root.clients(3, 2)
                root.check(PickerService.items !== root.snapshot && !Object.keys(PickerService.exposePendingMoves).length,
                    "multiple confirmed moves publish together")
                root.check(!PickerService.moveExposeWindow("0x1", 3)
                    && !Object.keys(PickerService.exposePendingMoves).length, "same-workspace drop does not freeze the grid")
                PickerService.moveExposeWindow("0x1", 2)
                root.windowSource.allWindows = root.clients(3, 2).slice(1)
                root.check(PickerService.items.length === 1 && !Object.keys(PickerService.exposePendingMoves).length,
                    "closed dragged window releases the pending update")
                PickerService.moveExposeWindow("0x2", 1)
                PickerService.close()
                root.check(!Object.keys(PickerService.exposePendingMoves).length, "closing clears pending moves")
                root.checkWorkspaceOrder()
                console.log(root.failed ? "EXPOSE FAIL: move synchronization"
                    : "PASS: Exposé spatial ordering, grouped tabs, stale snapshots, confirmed moves, timeout recovery, multiple moves and closed windows")
                stop()
                Qt.quit()
            }
            root.step++
        }
    }
}
