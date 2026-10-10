pragma ComponentBehavior: Bound

import QtQuick
import "../../theme"
import "../../theme/ui" as UI

PickerPanelBase {
    id: root
    footerHint: picker.selectedIds.length + " selected · Arrows to move · Shift+Space toggle + next\n"
        + "Ctrl+A select visible / clear all · "
        + (picker.selectedIds.length ? "Enter to " + picker.acceptLabel.toLowerCase() : "Enter uses highlighted row")

    searchKeyHandler: root.handleSelectionKey
    Keys.onPressed: event => { event.accepted = root.handleSelectionKey(event,true) }

    actionButtons: Component {
        Item {
            implicitHeight: Theme.controlHeight
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.controlSpacing
                UI.ActionButton {
                    objectName: "pickerSelectVisible"
                    label: root.picker.selectionToggleClears ? "Deselect all" : "Select visible"
                    implicitWidth: 125; width: implicitWidth
                    enabled: root.picker.filteredItems.length > 0 || root.picker.selectedIds.length > 0
                    hint: "Ctrl+A: select visible / clear all · Ctrl+Shift+A: clear all"
                    onClicked: root.picker.toggleVisibleSelection()
                }
                UI.ActionButton {
                    objectName: "pickerAccept"
                    label: root.picker.acceptLabel; implicitWidth: 115; width: implicitWidth
                    enabled: root.picker.canAccept
                    fillColor: Theme.accent
                    onClicked: root.picker.accept(false, false)
                }
            }
        }
    }
}
