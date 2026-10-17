pragma ComponentBehavior: Bound

import "../../i18n"
import QtQuick
import "../../theme"
import "../../theme/ui" as UI

PickerPanelBase {
    id: root
    footerHint: Translations.text("picker.shortcuts.multiple", [picker.selectedIds.length,
        picker.selectedIds.length ? Translations.text("picker.shortcuts.accept",[picker.acceptLabel.toLowerCase()]) : Translations.text("picker.shortcuts.highlighted")])
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
                    label: Translations.text(root.picker.selectionToggleClears ? "picker.actions.clearSelection" : "picker.actions.selectVisible")
                    implicitWidth: 125; width: implicitWidth
                    enabled: root.picker.filteredItems.length > 0 || root.picker.selectedIds.length > 0
                    hint: Translations.text("picker.actions.selectVisibleHint")
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
