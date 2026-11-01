import QtQml

QtObject {
    id: root
    property bool enabled: false
    property string screenName: ""
    property bool hovered: false
    property bool attachmentOpen: false
    // -1 forces hidden, 0 follows automatic policy, 1 forces visible.
    property int manualVisibility: 0
    property bool emptyWorkspace: false
    property bool showOnEmptyWorkspace: true
    property int hideDelay: 120
    property bool revealHeld: false
    readonly property bool shown: !enabled || revealHeld || attachmentOpen || manualVisibility > 0
        || (manualVisibility === 0 && showOnEmptyWorkspace && emptyWorkspace)

    function scheduleHide() {
        if (enabled && !hovered && !attachmentOpen) hideTimer.restart()
    }

    onHoveredChanged: {
        if (hovered) {
            hideTimer.stop()
            revealHeld = true
        } else scheduleHide()
    }
    onAttachmentOpenChanged: {
        if (attachmentOpen) hideTimer.stop()
        else scheduleHide()
    }
    onEnabledChanged: {
        hideTimer.stop()
        revealHeld = !enabled || hovered
    }

    property Timer hideTimer: Timer {
        interval: root.hideDelay
        onTriggered: root.revealHeld = false
    }
}
