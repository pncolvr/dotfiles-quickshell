pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

TimeEntryTab {
    id: root
    empty: TimersService.countdowns.length === 0
    emptyMessage: "No countdowns"
    creationComponent: Component {
        Column {
            id: creator
            spacing: Theme.controlSpacing
            function addCountdown() {
                if (duration.acceptableInput && duration.totalSeconds > 0)
                    TimersService.addCountdown(duration.totalSeconds, nameField.text)
            }
            UI.InputField {
                id: nameField
                objectName: "countdownName"
                width: parent.width
                placeholderText: "Name (optional)"
                onAccepted: creator.addCountdown()
            }
            Row {
                width: parent.width
                spacing: Theme.controlSpacing
                DurationFields {
                    id: duration
                    namePrefix: "countdown"
                    initialDurationMs: 300000
                    width: parent.width - addButton.width - parent.spacing
                    onAccepted: creator.addCountdown()
                }
                UI.ActionButton {
                    id: addButton
                    objectName: "countdownStart"
                    anchors.bottom: parent.bottom
                    glyph: Theme.addIcon
                    foreground: Theme.accent
                    hint: "Add countdown"
                    enabled: duration.acceptableInput && duration.totalSeconds > 0
                    onClicked: creator.addCountdown()
                }
            }
        }
    }
    listContent: Repeater {
        objectName: "countdownRows"
        model: TimersService.countdowns
        CountdownRow { required property var modelData; entry: modelData; width: root.width }
    }
}
