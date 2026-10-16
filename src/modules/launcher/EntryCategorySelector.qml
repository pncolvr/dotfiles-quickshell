pragma ComponentBehavior: Bound
import "../../services"
import "../../theme/ui" as UI

UI.ComboSelector {
    visible: StatusService.enabled
    compact: true
    labelPrefix: 'Category: '
    options: [
        {
            name: 'personal',
            description: 'Personal'
        },
        {
            name: 'work',
            description: 'Work'
        }
    ]
}
