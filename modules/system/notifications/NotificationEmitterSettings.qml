pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Column {
    id: root
    property string filter: "All"
    readonly property var emitters: Object.values(NotificationEmitterRepository.emitters)
        .filter(emitter => filter === "Hidden" ? emitter.muted : filter === "DND allowed" ? emitter.allowDuringDnd
            : filter === "History off" ? emitter.excludeFromHistory : true)
        .sort((a, b) => a.name.localeCompare(b.name))
    spacing: 12
    UI.Text {
        centerVertical: false
        width: parent.width
        text: "Defaults: show notifications, DND blocked, history on. Transient notifications are not saved. Buttons show the current state; click to change it."
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        color: Theme.inactive
    }
    Flow {
        width: parent.width
        spacing: Theme.controlSpacing
        Repeater {
            model: ["All", "Hidden", "DND allowed", "History off"]
            NotificationButton {
                required property string modelData
                label: modelData
                foreground: root.filter === modelData ? Theme.accent : Theme.text
                onClicked: root.filter = modelData
            }
        }
    }
    UI.Text { centerVertical: false; visible: !root.emitters.length; text: "No emitters in this list." }
    Repeater {
        model: root.emitters
        Rectangle {
            id: row
            required property var modelData
            width: root.width
            implicitHeight: content.height + 20
            radius: 10
            color: Theme.alternateBackground
            Column {
                id: content
                x: 10; y: 10
                width: parent.width - 20
                spacing: 8
                UI.Text { centerVertical: false; width: parent.width; text: row.modelData.name; wrapMode: Text.Wrap; textFormat: Text.PlainText }
                NotificationSourceControls { width: parent.width; emitterKey: row.modelData.key }
            }
        }
    }
}
