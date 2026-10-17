pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import "../../services"
import "../../theme"
import "../../theme/ui" as UI

ManagedCollectionPanel {
    filterBrowser: true
    id: root
    service:N8nService
    collectionName:'n8n'
    pickerMode:PickerService.Mode.N8n
    entryForm:N8nInstanceForm {}
    listActionButtons: Component {
        Row {
            spacing:Theme.controlSpacing
            UI.ActionButton {
                id: refresh
                objectName:'n8nRefresh'; glyph:Theme.refreshIcon; label:Translations.text("common.actions.refresh")
                keyAction: "refresh"
                enabled:!N8nService.refreshing && !!N8nService.availableEntries.length
                hint:Translations.text("n8n.actions.refreshHint")
                onClicked:N8nService.refresh()
            }
            UI.ColumnText {
                width:Math.max(0,parent.width-refresh.width-Theme.controlSpacing)
                text:N8nService.refreshStatus; color:Theme.inactive
                anchors.verticalCenter:parent.verticalCenter; elide:Text.ElideRight
            }
        }
    }
}
