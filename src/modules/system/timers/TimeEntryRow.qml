pragma ComponentBehavior: Bound

import "../../../i18n"
import QtQuick
import QtQuick.Layouts
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
    property bool editable: false
    property bool editing: false
    readonly property Item editorItem: editorLoader.item as Item
    readonly property color timeColor: entry.urgency === 2 ? Theme.urgent
        : entry.urgency === 1 ? Theme.warning : Theme.text
    implicitHeight: root.editing ? editorItem?.implicitHeight ?? Theme.controlHeight : Theme.controlHeight

    UI.Text {
        objectName: "timerTitle"
        anchors.left: parent.left
        anchors.right: timeLabel.left
        anchors.rightMargin: Theme.controlSpacing
        visible: !root.editing
        text: root.entry.title
        elide: Text.ElideRight
        color: root.entry.running || root.entry.finished ? root.timeColor : Theme.inactive
    }
    UI.Text {
        id: timeLabel
        objectName: "timerTime"
        anchors.right: actions.left
        anchors.rightMargin: Theme.controlSpacing
        visible: !root.editing
        text: TimersService.formatTime(root.entry.valueMs, root.roundUp)
        color: root.timeColor
    }
    Row {
        id: actions
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.controlSpacing
        visible: !root.editing
        UI.ActionButton {
            objectName: "timerEdit"
            visible: root.editable
            glyph: Theme.editIcon
            hint: Translations.text("timers.actions.editHint")
            onClicked: root.editing = true
        }
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
            fillColor: Theme.urgentFill
            onClicked: TimersService.remove(root.entry)
        }
    }

    Loader {
        id: editorLoader
        objectName: "countdownEditor"
        anchors.fill: parent
        visible: root.editing
        active: root.editable
        sourceComponent: Component {
            RowLayout {
                spacing: Theme.controlSpacing
                visible: root.editing

                function loadEntry() {
                    editName.text = root.entry.label
                    editDuration.setDuration(root.entry.durationMs)
                }

                UI.InputField {
                    id: editName
                    objectName: "countdownEditName"
                    Layout.preferredWidth: 105
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignBottom
                    text: root.entry.label
                    placeholderText: Translations.text("timers.fields.nameRequired")
                    Accessible.name: Translations.text("timers.fields.nameRequired")
                }

                DurationFields {
                    id: editDuration
                    namePrefix: "countdownEdit"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    initialDurationMs: root.entry.durationMs
                }

                UI.EditorActions {
                    Layout.alignment: Qt.AlignBottom
                    submitObjectName: "countdownEditSave"
                    cancelObjectName: "countdownEditCancel"
                    cancelHint: Translations.text("common.actions.cancelHint")
                    submitHint: Translations.text("common.actions.saveChangesHint")
                    submitEnabled: editName.text.trim().length > 0 && editDuration.acceptableInput
                        && TimersService.validDuration(editDuration.totalSeconds)
                    onCancelled: root.editing = false
                    onSubmitted: {
                        if (TimersService.editCountdown(root.entry, editDuration.totalSeconds, editName.text))
                            root.editing = false
                    }
                }

                Component.onCompleted: loadEntry()
                onVisibleChanged: if (visible) loadEntry()
            }
        }
    }
}
