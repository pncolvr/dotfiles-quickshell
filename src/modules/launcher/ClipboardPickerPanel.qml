pragma ComponentBehavior: Bound

import QtQuick
import "../../theme"
import "../../theme/ui" as UI
import "../../services"
import "../../config"

PickerPanelBase {
    id: root
    searchPlaceholder: "Search clipboard"
    panelError: picker.error || ClipboardService.error
    minimumRowHeight: Theme.clipboardRowHeight
    readonly property bool pinnedOnly: picker.itemCriteria.pinned === true
    footerHint: "Enter to paste · Ctrl+Enter to copy · Del to delete\n"
        + "Ctrl+P pin/unpin · Ctrl+Shift+P pinned only"

    function sizeListForOpening() {
        const entries = picker.items.slice(0, Config.pickerMaxRows)
        openedListHeight = entries.length ? entries.reduce((height, entry) => height + (entry.image
            ? Theme.clipboardImagePreviewHeight + Theme.pickerRowPadding * 2 : Theme.clipboardRowHeight), 0)
            + (entries.length - 1) * Theme.controlSpacing : Theme.clipboardRowHeight
    }

    function deleteCurrentEntry() {
        if (picker.currentItem) ClipboardService.remove(picker.currentItem.id)
    }
    function toggleCurrentPin() {
        if (picker.currentItem) ClipboardService.togglePin(picker.currentItem.result)
    }
    function togglePinnedOnly() {
        picker.itemCriteria = pinnedOnly ? ({}) : ({pinned: true})
        picker.currentIndex = 0
    }
    function acceptSelection(modifiers) {
        const copyOnly = (modifiers & Qt.ControlModifier) !== 0
        picker.accept(copyOnly, copyOnly)
    }
    Keys.onDeletePressed: event => { root.deleteCurrentEntry(); event.accepted = true }
    Keys.onPressed: event => {
        if (event.key !== Qt.Key_P) { event.accepted = false; return }
        if (event.modifiers === (Qt.ControlModifier | Qt.ShiftModifier)) root.togglePinnedOnly()
        else if (event.modifiers === Qt.ControlModifier) root.toggleCurrentPin()
        else { event.accepted = false; return }
        event.accepted = true
    }

    actionButtons: Component {
        Item {
            implicitHeight: Theme.controlHeight
            Row {
                anchors.right: parent.right
                spacing: Theme.controlSpacing
                UI.ActionButton {
                    objectName: "clipboardPinnedOnly"
                    label: "Pinned only"; implicitWidth: 100; width: implicitWidth
                    foreground: root.pinnedOnly ? Theme.accent : Theme.text
                    hint: root.pinnedOnly ? "Show all clipboard entries (Ctrl+Shift+P)" : "Show only pinned entries (Ctrl+Shift+P)"
                    onClicked: root.togglePinnedOnly()
                }
                UI.ActionButton {
                    objectName: "pinClipboardEntry"
                    glyph: Theme.filePinIcon
                    foreground: root.picker.currentItem?.pinned ? Theme.accent : Theme.inactive
                    hint: root.picker.currentItem?.pinned ? "Unpin entry (Ctrl+P)" : "Pin entry (Ctrl+P)"
                    enabled: !!root.picker.currentItem
                    onClicked: root.toggleCurrentPin()
                }
                UI.ActionButton {
                    glyph: Theme.deleteIcon
                    fillColor: Theme.urgent
                    hint: "Remove the highlighted entry from history (Delete)"
                    enabled: !!root.picker.currentItem
                    onClicked: root.deleteCurrentEntry()
                }
                UI.ActionButton {
                    objectName: "clearClipboardHistory"
                    label: "Clear history"; implicitWidth: 115; width: implicitWidth
                    fillColor: Theme.urgent
                    hint: "Remove unpinned clipboard entries; keep pinned entries"
                    onClicked: ClipboardService.clear()
                }
                UI.ActionButton {
                    label: "Paste"; implicitWidth: 90; width: implicitWidth
                    enabled: !!root.picker.currentItem && root.picker.destination.length > 0
                    fillColor: Theme.accent
                    hint: "Paste into the original window (Enter)"
                    onClicked: root.picker.accept(false, false)
                }
            }
        }
    }
}
