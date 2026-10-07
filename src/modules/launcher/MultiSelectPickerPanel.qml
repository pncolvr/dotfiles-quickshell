pragma ComponentBehavior: Bound

import QtQuick
import "../../theme"
import "../../theme/ui" as UI

PickerPanelBase {
    id: root
    footerHint: picker.selectedIds.length + " selected · Arrows to move · Ctrl+Space toggle\n"
        + "Ctrl+A select visible / clear all · Enter to " + picker.acceptLabel.toLowerCase()

    Keys.onPressed: event => {
        switch (event.key) {
            case Qt.Key_Space:
                if (root.searchHasFocus && !(event.modifiers & Qt.ControlModifier)) { event.accepted = false; return }
                root.picker.select(root.picker.currentIndex, true)
                break
            case Qt.Key_A:
                if (!(event.modifiers & Qt.ControlModifier)) { event.accepted = false; return }
                if (event.modifiers & Qt.ShiftModifier) root.picker.deselectAll()
                else root.picker.toggleVisibleSelection()
                break
            default: event.accepted = false; return
        }
        event.accepted = true
    }

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
