pragma ComponentBehavior: Bound
import "../../../i18n"
import "../../"
import "../" as UI

UI.ActionButton {
    id: root
    property string category: "personal"
    signal categoryRequested(string category)
    label: Translations.text(category === "work" ? "status.modes.work" : "status.modes.personal")
    foreground: category === "work" ? Theme.accent : Theme.active
    width: Theme.projectOptionButtonWidth
    hint: Translations.text("folders.actions.switchCategoryHint")
    onClicked: root.categoryRequested(category === "work" ? "personal" : "work")
}
