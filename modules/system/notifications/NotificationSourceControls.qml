import QtQuick
import "../../../theme"
import "../../../services"

Flow {
    id: root
    required property string emitterKey
    readonly property var emitter: NotificationEmitterRepository.emitters[emitterKey]
    spacing: Theme.controlSpacing
    readonly property real naturalWidth: muteButton.implicitWidth + dndButton.implicitWidth + historyButton.implicitWidth + spacing * 2
    width: naturalWidth
    NotificationButton {
        id: muteButton
        objectName: "notificationMute"
        label: root.emitter?.muted ? "Hide" : "Show"
        hint: root.emitter?.muted ? "Popups are muted. Click to show future popups; DND still applies."
            : "Popups are enabled. Click to mute future popups; history is unaffected."
        foreground: root.emitter?.muted ? Theme.accent : Theme.text
        onClicked: NotificationService.setEmitterPreference(root.emitterKey, "muted", !root.emitter?.muted)
    }
    NotificationButton {
        id: dndButton
        objectName: "notificationDndWhitelist"
        label: root.emitter?.allowDuringDnd ? "DND allowed" : "DND blocked"
        hint: root.emitter?.allowDuringDnd ? "This emitter can show popups during DND. Click to block it; mute still takes precedence."
            : "This emitter is blocked during DND. Click to add it to the whitelist; history is unaffected."
        foreground: root.emitter?.allowDuringDnd ? Theme.accent : Theme.text
        onClicked: NotificationService.setEmitterPreference(root.emitterKey, "allowDuringDnd", !root.emitter?.allowDuringDnd)
    }
    NotificationButton {
        id: historyButton
        objectName: "notificationHistoryExclude"
        label: root.emitter?.excludeFromHistory ? "History off" : "History on"
        hint: root.emitter?.excludeFromHistory ? "Future notifications are not saved. Click to resume saving; transient notifications remain excluded."
            : "Future notifications are saved at every urgency. Click to stop saving; existing history is kept."
        foreground: root.emitter?.excludeFromHistory ? Theme.accent : Theme.text
        onClicked: NotificationService.setEmitterPreference(root.emitterKey, "excludeFromHistory", !root.emitter?.excludeFromHistory)
    }
}
