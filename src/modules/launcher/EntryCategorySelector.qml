pragma ComponentBehavior: Bound
import "../../i18n"
import "../../services"
import "../../theme/ui" as UI

UI.FolderCategorySelector {
    visible: StatusService.enabled
    label: Translations.text("category.selector.label", [selectedDescription])
}
