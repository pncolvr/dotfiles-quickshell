pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import "../../../theme"
import "../../../config"

QC.Slider {
    id: root
    property real volume: 0
    property bool muted: false
    signal volumeMoved(real volume)
    height: Theme.audioButtonHeight
    from: 0
    to: Config.audioMaxVolume
    stepSize: Config.audioVolumeStep
    wheelEnabled: true
    onMoved: root.volumeMoved(value)
    HoverHandler {
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }
    Binding {
        target: root
        property: "value"
        value: root.volume
        when: !root.pressed
        restoreMode: Binding.RestoreNone
    }
    background: Rectangle {
        x: root.leftPadding
        y: (root.height - height) / 2
        width: root.availableWidth
        height: Theme.audioSliderTrackHeight
        radius: height / 2
        color: Theme.empty
        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: root.muted ? Theme.inactive : Theme.accent
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: (root.height - height) / 2
        width: Theme.audioSliderHandleSize
        height: width
        radius: width / 2
        color: root.pressed || root.activeFocus ? Theme.accent : Theme.text
        border.color: Theme.accent
        border.width: root.activeFocus ? 2 : 0
    }
}
