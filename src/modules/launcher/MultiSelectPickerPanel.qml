pragma ComponentBehavior: Bound

import "../../i18n"
import QtQuick
import "../../theme"
import "../../ui" as UI

PickerPanelBase {
    id: root
    hintPanel: "multiple"
    hintActions: ["selection.toggle", "selection.all", "selection.clear"]
    searchKeyHandler: root.handleSelectionKey
    Keys.onPressed: event => { event.accepted = root.handleSelectionKey(event,true) }

    actionButtons: Component {
        Item {
            implicitHeight: Theme.controlHeight
            Row {
                anchors.right: parent.right
                spacing: Theme.controlSpacing
                UI.ActionButton {
                    objectName: "pickerSelectVisible"
                    glyph: root.picker.selectionToggleClears ? Theme.clearIcon : Theme.selectVisibleIcon
                    enabled: root.picker.filteredItems.length > 0 || root.picker.selectedIds.length > 0
                    hint: Translations.text(root.picker.selectionToggleClears ? "picker.actions.clearSelection" : "picker.actions.selectVisible")
                        + " · " + Translations.text("picker.actions.selectVisibleHint",[UI.Keybinds.sequence("selection.all"),UI.Keybinds.sequence("selection.clear")])
                    onClicked: root.picker.toggleVisibleSelection()
                }
                UI.ActionButton {
                    objectName: "pickerAccept"
                    glyph: Theme.openLinksIcon
                    hint: root.picker.acceptLabel
                    enabled: root.picker.canAccept
                    fillColor: Theme.accent
                    onClicked: root.picker.accept(false, false)
                }
            }
        }
    }
}
