pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import ".." as UI

// The bottom padding belongs to hints or one short-lived feedback message.
UI.ShortcutHints {
    id: root
    property string message: ""
    property int messageDuration: 8000
    property bool hintsEnabled: true
    property color hintColor: Theme.inactive
    property color messageColor: Theme.warning
    readonly property int effectiveMessageDuration: Math.max(1, Math.min(10000, messageDuration))
    readonly property bool showingMessage: feedbackState.showing
    visible: true
    height: Math.max(Theme.scrollbarGutter, hintsEnabled ? naturalHintsHeight : 0, implicitHeight)
    text: showingMessage ? message.replace(/\s+/g, " ").trim() : hintsEnabled ? formattedHints : ""
    color: showingMessage ? messageColor : hintColor
    elide: Text.ElideRight

    function showMessage() {
        feedbackState.showing = visible && message.trim().length > 0
        if (feedbackState.showing) expiry.restart()
        else expiry.stop()
    }
    onMessageChanged: showMessage()
    onVisibleChanged: showMessage()
    Component.onCompleted: showMessage()
    QtObject { id: feedbackState; property bool showing: false }
    Timer {
        id: expiry
        interval: root.effectiveMessageDuration
        onTriggered: feedbackState.showing = false
    }
    UI.HoverTooltip { text: root.showingMessage ? root.message : "" }
}
