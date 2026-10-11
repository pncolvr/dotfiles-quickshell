pragma ComponentBehavior: Bound
import "../../"
import "../" as UI

UI.ActionButton {
    id: root
    property string category: "personal"
    signal categoryRequested(string category)
    label: category === "work" ? "Work" : "Personal"
    foreground: category === "work" ? Theme.accent : Theme.active
    width: Theme.projectOptionButtonWidth
    hint: "switch category"
    onClicked: root.categoryRequested(category === "work" ? "personal" : "work")
}
