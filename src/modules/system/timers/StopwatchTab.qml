pragma ComponentBehavior: Bound

import "../../../i18n"
import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

TimeEntryTab {
    id: root
    empty: TimersService.timers.length === 0
    emptyMessage: Translations.text("timers.stopwatches.empty")
    creationComponent: Component {
        Row {
            spacing: Theme.controlSpacing
            UI.InputField {
                id: nameField
                objectName: "timerName"
                width: parent.width - addButton.width - parent.spacing
                placeholderText: Translations.text("timers.fields.nameOptional")
                onAccepted: TimersService.addTimer(text)
            }
            UI.ActionButton {
                id: addButton
                objectName: "timerStart"
                    keyAction: "add"
                glyph: Theme.addIcon
                foreground: Theme.accent
                hint: Translations.text("timers.stopwatches.add")
                onClicked: TimersService.addTimer(nameField.text)
            }
        }
    }
    listContent: Repeater {
        objectName: "stopwatchRows"
        model: TimersService.timers
        StopwatchRow { required property var modelData; entry: modelData; width: root.width }
    }
}
