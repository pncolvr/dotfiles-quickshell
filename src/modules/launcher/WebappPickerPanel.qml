pragma ComponentBehavior: Bound
import "../../i18n"
import "../../services"
ManagedCollectionPanel {
    service: WebappService
    collectionName: Translations.text("webapps.title")
    pickerMode: PickerService.Mode.Webapps
    entryForm: WebappForm {}
}
