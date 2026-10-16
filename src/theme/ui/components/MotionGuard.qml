pragma ComponentBehavior: Bound
import QtQuick

// All finite animations settle immediately when policy changes. Infinite effects
// stop at their current frame; their owner's running binding resumes them later.
QtObject {
    id: root
    required property Animation animation
    property bool allowed: true
    property bool policyEnabled: MotionPolicy.enabled
    readonly property bool enabled: allowed && policyEnabled
    function settle() {
        if (enabled || !animation.running) return
        if (animation.loops < 0) animation.stop()
        else animation.complete()
    }
    onEnabledChanged: settle()
    property Connections runningConnection: Connections {
        target: root.animation
        function onRunningChanged() { root.settle() }
    }
}
