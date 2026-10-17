pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import "../../services"
import "../../theme"
import "../../ui" as UI

ManagedCollectionPanel {
    listHintPanel: "n8n"
    filterBrowser: true
    id: root
    service:N8nService
    collectionName:'n8n'
    pickerMode:PickerService.Mode.N8n
    entryForm:N8nInstanceForm {}
    managementMessage: N8nService.error || N8nService.refreshStatus
    refreshHintEnabled: refreshAll.enabled
    managementToolbarContent: [
        UI.ActionButton {
            id: refreshAll
            objectName: "n8nRefreshAll"
            glyph: Theme.refreshIcon
            keyAction: "refresh"
            enabled: !root.showForm && !N8nService.refreshing && N8nService.entries.some(entry => entry.enabled)
            hint: Translations.text("n8n.actions.refreshAllHint")
            onClicked: N8nService.refresh()
        }
    ]
    detailActionContent: [
        UI.ActionButton {
            objectName: "n8nRefresh"
            glyph: Theme.refreshIcon
            enabled: !N8nService.refreshing && !!root.selectedEntry?.enabled
            hint: Translations.text("n8n.actions.refreshHint")
            onClicked: N8nService.refresh(root.selectedEntry.id)
        }
    ]
}
