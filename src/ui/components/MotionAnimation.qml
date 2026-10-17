pragma ComponentBehavior: Bound
import QtQuick

NumberAnimation {
    id: root
    property int animationDuration: 250
    property bool motionEnabled: true
    duration: guard.enabled ? animationDuration : 0
    property MotionGuard guard: MotionGuard { animation: root; allowed: root.motionEnabled }
}
