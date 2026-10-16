pragma ComponentBehavior: Bound
import "../../services"
ManagedCollectionPanel {
    service: WebappService
    collectionName: 'Webapps'
    pickerMode: PickerService.Mode.Webapps
    entryForm: WebappForm {}
}
