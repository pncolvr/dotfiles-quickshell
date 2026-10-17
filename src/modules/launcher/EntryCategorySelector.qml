pragma ComponentBehavior: Bound
import "../../i18n"
import "../../services"
import "../../theme/ui" as UI

UI.ComboSelector {
    visible: StatusService.enabled
    compact: true
    label: Translations.text("category.selector.label", [selectedDescription])
    options: [
        {
            name: 'personal',
            description: Translations.text("status.modes.personal")
        },
        {
            name: 'work',
            description: Translations.text("status.modes.work")
        }
    ]
}
