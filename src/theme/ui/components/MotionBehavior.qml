pragma ComponentBehavior: Bound
import QtQuick

Behavior {
    id: root
    property bool motionEnabled: true
    property bool settling: false
    property var destinationValue
    enabled: motionEnabled && MotionPolicy.enabled
    // Behavior owns its animation, so Animation.complete() cannot finish it.
    // Temporarily apply its destination with Binding to cancel the interpolation
    // while preserving the original binding and future data updates.
    onEnabledChanged: if (!enabled && targetProperty.object) {
        destinationValue = targetValue
        settling = true
        settling = false
    }
    property Binding destination: Binding {
        when: root.settling
        target: root.targetProperty.object
        property: root.targetProperty.name
        value: root.destinationValue
        restoreMode: Binding.RestoreBindingOrValue
    }
}
