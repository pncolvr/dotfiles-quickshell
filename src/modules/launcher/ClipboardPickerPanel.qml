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
    footerHint: "Enter to paste · Ctrl+Enter to copy · Del to delete"

    function sizeListForOpening() {
        const entries = picker.items.slice(0, Config.pickerMaxRows)
        openedListHeight = entries.length ? entries.reduce((height, entry) => height + Theme.clipboardRowHeight
            + (entry.image ? Theme.clipboardImagePreviewHeight + Theme.controlSpacing : 0), 0)
            + (entries.length - 1) * Theme.controlSpacing : Theme.clipboardRowHeight
    }

    function deleteCurrentEntry() {
        if (picker.currentItem) ClipboardService.remove(picker.currentItem.id)
    }
    function acceptSelection(modifiers) {
        const copyOnly = (modifiers & Qt.ControlModifier) !== 0
        picker.accept(copyOnly, copyOnly)
    }
    Keys.onDeletePressed: event => { root.deleteCurrentEntry(); event.accepted = true }

    actionButtons: Component {
        Item {
            implicitHeight: Theme.controlHeight
            Row {
                anchors.right: parent.right
                spacing: Theme.controlSpacing
                UI.ActionButton {
                    glyph: Theme.deleteIcon
                    fillColor: Theme.urgent
                    hint: "Remove the highlighted entry from history (Delete)"
                    enabled: !!root.picker.currentItem
                    onClicked: root.deleteCurrentEntry()
                }
                UI.ActionButton {
                    label: "Clear history"; implicitWidth: 115; width: implicitWidth
                    fillColor: Theme.urgent
                    hint: "Remove all saved clipboard entries"
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
