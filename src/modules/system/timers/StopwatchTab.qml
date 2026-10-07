pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

TimeEntryTab {
    id: root
    empty: TimersService.timers.length === 0
    emptyMessage: "No timers"
    creationComponent: Component {
        Row {
            spacing: Theme.controlSpacing
            UI.InputField {
                id: nameField
                objectName: "timerName"
                width: parent.width - addButton.width - parent.spacing
                placeholderText: "Name (optional)"
                onAccepted: TimersService.addTimer(text)
            }
            UI.ActionButton {
                id: addButton
                objectName: "timerStart"
                glyph: Theme.addIcon
                foreground: Theme.accent
                hint: "Add timer"
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
