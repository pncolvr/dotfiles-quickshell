pragma ComponentBehavior: Bound

import "../../../i18n"
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

    function setDuration(milliseconds) {
        hours.text = String(Math.floor(milliseconds / 3600000))
        minutes.text = String(Math.floor(milliseconds / 60000) % 60)
        seconds.text = String(Math.floor(milliseconds / 1000) % 60)
    }

    DurationField {
        id: hours
        objectName: root.namePrefix + Translations.text("timers.duration.hours")
        label: Translations.text("timers.duration.hours")
        width: (root.width - root.spacing * 2) / 3
        text: String(Math.floor(root.initialDurationMs / 3600000))
        onAccepted: root.accepted()
    }
    DurationField {
        id: minutes
        objectName: root.namePrefix + Translations.text("timers.duration.minutes")
        label: Translations.text("timers.duration.minutes")
        width: hours.width
        text: String(Math.floor(root.initialDurationMs / 60000) % 60)
        onAccepted: root.accepted()
    }
    DurationField {
        id: seconds
        objectName: root.namePrefix + Translations.text("timers.duration.seconds")
        label: Translations.text("timers.duration.seconds")
        width: hours.width
        text: String(Math.floor(root.initialDurationMs / 1000) % 60)
        onAccepted: root.accepted()
    }
}
