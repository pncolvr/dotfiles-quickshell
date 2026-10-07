pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme"

Row {
    id: root
    property real initialDurationMs: 0
    property string namePrefix: ""
    readonly property real totalSeconds: hours.value * 3600 + minutes.value * 60 + seconds.value
    readonly property bool acceptableInput: hours.acceptableInput && minutes.acceptableInput && seconds.acceptableInput
    signal accepted()
    spacing: Theme.controlSpacing

    DurationField {
        id: hours
        objectName: root.namePrefix + "Hours"
        label: "Hours"
        width: (root.width - root.spacing * 2) / 3
        text: String(Math.floor(root.initialDurationMs / 3600000))
        onAccepted: root.accepted()
    }
    DurationField {
        id: minutes
        objectName: root.namePrefix + "Minutes"
        label: "Minutes"
        width: hours.width
        text: String(Math.floor(root.initialDurationMs / 60000) % 60)
        onAccepted: root.accepted()
    }
    DurationField {
        id: seconds
        objectName: root.namePrefix + "Seconds"
        label: "Seconds"
        width: hours.width
        text: String(Math.floor(root.initialDurationMs / 1000) % 60)
        onAccepted: root.accepted()
    }
}
