pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Services.Notifications

Scope {
    id: root
    required property var service
    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: false
        onNotification: notification => {
            notification.tracked = true
            root.service.receive(notification, notification.lastGeneration)
        }
    }
    Instantiator {
        model: server.trackedNotifications
        delegate: Scope {
            id: watcher
            required property Notification modelData
            readonly property int liveId: modelData.id
            Timer { id: updateTimer; interval: 0; onTriggered: root.service.updateLive(watcher.liveId) }
            Connections {
                target: watcher.modelData
                function onClosed() { updateTimer.stop(); root.service.closed(watcher.liveId) }
                function onSummaryChanged() { updateTimer.restart() }
                function onBodyChanged() { updateTimer.restart() }
                function onAppNameChanged() { updateTimer.restart() }
                function onAppIconChanged() { updateTimer.restart() }
                function onDesktopEntryChanged() { updateTimer.restart() }
                function onImageChanged() { updateTimer.restart() }
                function onUrgencyChanged() { updateTimer.restart() }
                function onExpireTimeoutChanged() { updateTimer.restart() }
                function onActionsChanged() { updateTimer.restart() }
                function onHintsChanged() { updateTimer.restart() }
            }
        }
    }
}
