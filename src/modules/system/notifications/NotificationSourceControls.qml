import "../../../i18n"
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
        label: Translations.text(root.emitter?.muted ? "common.actions.hide" : "common.actions.show")
        hint: Translations.text(root.emitter?.muted ? "notifications.popups.mutedHint" : "notifications.popups.enabledHint")
        foreground: root.emitter?.muted ? Theme.accent : Theme.text
        onClicked: NotificationService.setEmitterPreference(root.emitterKey, "muted", !root.emitter?.muted)
    }
    NotificationButton {
        id: dndButton
        objectName: "notificationDndWhitelist"
        label: Translations.text(root.emitter?.allowDuringDnd ? "notifications.dnd.allowed" : "notifications.dnd.blocked")
        hint: Translations.text(root.emitter?.allowDuringDnd ? "notifications.dnd.allowedHint" : "notifications.dnd.blockedHint")
        foreground: root.emitter?.allowDuringDnd ? Theme.accent : Theme.text
        onClicked: NotificationService.setEmitterPreference(root.emitterKey, "allowDuringDnd", !root.emitter?.allowDuringDnd)
    }
    NotificationButton {
        id: historyButton
        objectName: "notificationHistoryExclude"
        label: Translations.text(root.emitter?.excludeFromHistory ? "notifications.history.disabled" : "notifications.history.enabled")
        hint: Translations.text(root.emitter?.excludeFromHistory ? "notifications.history.disabledHint" : "notifications.history.enabledHint")
        foreground: root.emitter?.excludeFromHistory ? Theme.accent : Theme.text
        onClicked: NotificationService.setEmitterPreference(root.emitterKey, "excludeFromHistory", !root.emitter?.excludeFromHistory)
    }
}
