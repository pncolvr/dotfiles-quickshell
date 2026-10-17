pragma ComponentBehavior: Bound
import QtQuick

UniformAnimator {
    id: root
    property int animationDuration: 250
    property bool motionEnabled: true
    property bool policyEnabled: MotionPolicy.enabled
    duration: guard.enabled ? animationDuration : 0
    property MotionGuard guard: MotionGuard {
        animation: root
        allowed: root.motionEnabled
        policyEnabled: root.policyEnabled
    }
}
