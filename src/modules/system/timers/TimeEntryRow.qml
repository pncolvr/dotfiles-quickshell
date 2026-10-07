import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Item {
    id: root
    required property var entry
    property bool roundUp: false
    readonly property color timeColor: entry.urgency === 2 ? Theme.urgent
        : entry.urgency === 1 ? Theme.warning : Theme.text
    implicitHeight: Theme.controlHeight

    UI.Text {
        objectName: "timerTitle"
        anchors.left: parent.left
        anchors.right: timeLabel.left
        anchors.rightMargin: Theme.controlSpacing
        text: root.entry.title
        elide: Text.ElideRight
        color: root.entry.running || root.entry.finished ? root.timeColor : Theme.inactive
    }
    UI.Text {
        id: timeLabel
        objectName: "timerTime"
        anchors.right: actions.left
        anchors.rightMargin: Theme.controlSpacing
        text: TimersService.formatTime(root.entry.valueMs, root.roundUp)
        color: root.timeColor
    }
    Row {
        id: actions
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.controlSpacing
        UI.ActionButton {
            objectName: "timerPause"
            glyph: root.entry.running ? Theme.pauseIcon : Theme.playIcon
            hint: root.entry.finished ? "Start again" : root.entry.running ? "Pause"
                : root.entry.elapsedMs === 0 ? "Start" : "Resume"
            foreground: root.entry.running ? Theme.text : Theme.ok
            onClicked: TimersService.togglePause(root.entry)
        }
        UI.ActionButton {
            objectName: "timerReset"
            glyph: Theme.refreshIcon
            hint: "Reset"
            onClicked: TimersService.reset(root.entry)
        }
        UI.ActionButton {
            objectName: "timerDelete"
            glyph: Theme.deleteIcon
            hint: "Stop and delete"
            fillColor: Theme.urgent
            onClicked: TimersService.remove(root.entry)
        }
    }
}
