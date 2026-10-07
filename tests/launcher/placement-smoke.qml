pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../src/modules/launcher"
import "../../src/services"
import "../../src/theme"
import "../../src/theme/ui" as UI

Scope {
    id: root
    property int step: 0
    property bool failed: false
    readonly property var modes: ["menu", "grid", "clipboard", "multiple"]
    PickerWindow { id: popup; visible: false }

    function find(item: Item, name: string): Item {
        if (item.objectName === name) return item
        for (const child of item.children) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }
    function check(condition, message) {
        if (!condition) { failed = true; console.error("PICKER FAIL: " + message) }
    }
    function prepare(mode) {
        PickerService.begin(mode === "clipboard" ? mode : "menu", "Visible test prompt")
        PickerService.items = [{id:"0",title:"First",result:"first"}, {id:"1",title:"Second",result:"second"}]
        PickerService.layout = mode === "grid" ? "grid" : "list"
        PickerService.multiple = mode === "multiple"
        PickerService.opened()
    }
    function checkPlacement() {
        const search = find(popup.contentItem, "pickerSearch") as UI.SearchField
        check(!!search, "picker search exists")
        if (!search) return
        const position = search.mapToItem(popup.contentItem, 0, 0)
        check(popup.anchors.top && Math.abs(popup.contentX - (popup.width - popup.contentWidth) / 2) < 0.01,
            "picker is top anchored and horizontally centered")
        check(position.y === Theme.tooltipPaddingHeight, "search stays directly below the bar")
        check(popup.contentWidth > 0 && popup.contentHeight > 0, "picker has content geometry")
        check(popup.backgroundOpacity === Theme.pickerBackgroundOpacity, "tooltip shape preserves picker transparency")
        check(!popup.visible && !PickerService.visible, "placement test never displays or focuses a picker")
    }
    Timer {
        interval: 75
        repeat: true
        running: true
        onTriggered: {
            if (root.step < root.modes.length * 2) {
                if (root.step % 2 === 0) root.prepare(root.modes[root.step / 2])
                else root.checkPlacement()
            } else if (root.step === root.modes.length * 2) {
                PickerService.query = "no matching entry"
            } else {
                root.checkPlacement()
                if (!root.failed) console.log("PASS: picker placement")
                Qt.quit()
            }
            root.step++
        }
    }
}
