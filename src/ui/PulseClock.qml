pragma Singleton

import QtQuick
import Quickshell
import "../theme"

Singleton {
    id: root
    property real phase: 0
    property var consumers: []
    readonly property bool active: consumers.length > 0

    function update(consumer, enabled) {
        const index = consumers.indexOf(consumer)
        if (enabled && index < 0) consumers = consumers.concat([consumer])
        else if (!enabled && index >= 0) consumers = consumers.filter(item => item !== consumer)
    }
    NumberAnimation on phase {
        from: 0
        to: 1
        duration: Theme.pulsingTextDuration
        loops: Animation.Infinite
        running: root.active
    }
}
