pragma ComponentBehavior: Bound
import "../../i18n"
import "../../services"
ManagedCollectionPanel {
    searchPromptKey: "webapps"
    listHintPanel: "webapps"
    id: root
    filterBrowser: true
    service: WebappService
    collectionName: Translations.text("webapps.title")
    pickerMode: PickerService.Mode.Webapps
    entryForm: WebappForm {}
}
