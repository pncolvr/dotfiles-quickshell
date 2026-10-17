pragma ComponentBehavior: Bound
import "../../../i18n"
import "../" as UI

UI.ComboSelector {
    id: root
    property string category: "personal"
    signal categoryRequested(string category)
    compact: true
    selectedName: category
    options: [
        {name: "personal", description: Translations.text("status.modes.personal")},
        {name: "work", description: Translations.text("status.modes.work")}
    ]
    onSelected: name => root.categoryRequested(name)
}
