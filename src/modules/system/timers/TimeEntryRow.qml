import "../../../i18n"
import QtQuick
import "../../../theme"
import "../../../ui" as UI
import "../../../services"

Rectangle {
    id: root
    radius: Theme.iconButtonRadius
    color: rowHover.hovered ? Theme.alternateBackground : "transparent"

    HoverHandler { id: rowHover }
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
            hint: root.entry.finished ? Translations.text("timers.actions.restart") : root.entry.running ? Translations.text("media.actions.pause")
                : Translations.text(root.entry.elapsedMs === 0 ? "timers.actions.start" : "timers.actions.resume")
            foreground: root.entry.running ? Theme.text : Theme.ok
            onClicked: TimersService.togglePause(root.entry)
        }
        UI.ActionButton {
            objectName: "timerReset"
            glyph: Theme.refreshIcon
            hint: Translations.text("common.actions.reset")
            onClicked: TimersService.reset(root.entry)
        }
        UI.ActionButton {
            objectName: "timerDelete"
            glyph: Theme.deleteIcon
            hint: Translations.text("timers.actions.deleteHint")
            fillColor: Theme.urgent
            onClicked: TimersService.remove(root.entry)
        }
    }
}
