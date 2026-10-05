pragma ComponentBehavior: Bound

import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../services"
import "../../modules/system/notifications"

Scope {
    id: root
    readonly property var nativeView: nativeWindows.item
    property var cardEntry: ({emitterKey: "app:test", summary: "Test", body: "", urgency: 1, updatedAt: Date.now()})
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed() { Quickshell.inhibitReloadPopup() }
    }
    Test.TestEvent { id: mouse }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }
    Loader {
        id: nativeWindows
        active: Quickshell.env("NOTIFICATION_TEST_WAYLAND") === "1"
        source: "@NATIVE_WINDOWS@"
    }
    FloatingWindow {
        visible: true
        implicitWidth: 600
        implicitHeight: 600
        NotificationImageCache { id: imageCache }
        NotificationCard { id: card; width: 500; entry: root.cardEntry; popup: true }
        NotificationEmitterGroup { id: emitterGroup; width: 500; visible: false; group: ({emitterKey: root.cardEntry.emitterKey, count: 1}) }
        NotificationEmitterSettings { id: settings; width: 500; visible: false }
    }
    IpcHandler {
        target: "notificationstest"
        function snapshot(): string {
            return JSON.stringify({dnd: NotificationService.dndEnabled,
                focusMessage: NotificationService.focusMessage,
                emitters: NotificationEmitterRepository.emitters,
                groups: NotificationRepository.groups(100, 0),
                popups: NotificationService.popups.map(entry => ({id: entry.liveId, archiveId: entry.archiveId, summary: entry.summary, deadline: entry.deadline})),
                imageJobs: NotificationService.imageJobs,
                imageCache: {job: imageCache.job, busy: imageCache.busy, status: imageCache.status, source: imageCache.source.toString(), size: imageCache.sourceSize},
                card: {summary: card.entry.summary, icon: card.iconSource, imageIsIcon: card.usesImageAsIcon,
                    actions: card.displayActions.map(action => action.identifier), actionStates: card.displayActions,
                    buttonFound: !!root.find(card, "notificationAction_custom")},
                live: Object.values(NotificationService.liveEntries).map(entry => ({id: entry.liveId, archiveId: entry.archiveId, summary: entry.summary, deadline: entry.deadline, image: entry.image}))})
        }
        function preference(key: string, preference: string, value: bool): bool { return NotificationService.setEmitterPreference(key, preference, value) }
        function entries(key: string, limit: int, offset: int): string { return JSON.stringify(NotificationRepository.entries(key, limit, offset)) }
        function dismiss(id: int): void { const entry = NotificationService.liveEntries[id]; if (entry) NotificationService.dismiss(entry, false) }
        function clearEmitter(key: string): void { NotificationService.clearEmitter(key) }
        function clearAll(): void { NotificationService.clearAll() }
        function action(id: int, action: string): bool { return NotificationService.invoke({liveId: id}, action) }
        function activate(id: int): void { NotificationService.activate({liveId: id, emitterKey: NotificationService.liveEntries[id]?.emitterKey}) }
        function cardClick(id: int, right: bool): void {
            const entry = NotificationService.liveEntries[id]
            if (!entry) return
            root.cardEntry = entry
            card.popup = true
            mouse.mouseClick(card, card.width - 4, card.height / 2, right ? Qt.RightButton : Qt.LeftButton, Qt.NoModifier, 0)
        }
        function cardButton(id: int, name: string, history: bool): bool {
            const entry = NotificationService.liveEntries[id]
            if (!entry) return false
            const button = root.find(card, name) as Item
            return !!button && mouse.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
        }
        function prepareCard(id: int, history: bool): void {
            root.cardEntry = NotificationService.liveEntries[id] || root.cardEntry
            card.popup = !history
            card.visible = true
            settings.visible = false
        }
        function prepareHistory(id: string): bool {
            const entry = NotificationRepository.entry(id)
            if (!entry) return false
            root.cardEntry = entry
            card.popup = false
            card.visible = true
            emitterGroup.visible = false
            settings.visible = false
            return true
        }
        function historyAction(id: string, identifier: string): bool {
            const entry = NotificationRepository.entry(id)
            return !!entry && NotificationService.invoke(entry, identifier)
        }
        function historyButton(name: string): bool {
            const button = root.find(card, name) as Item
            return !!button && button.enabled && mouse.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
        }
        function historyActionSlot(name: string): bool {
            const button = root.find(card, name) as Item
            const item = button?.parent
            return !!item && mouse.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
        }
        function historyClick(): void { mouse.mouseClick(card, card.width - 4, card.height / 2, Qt.LeftButton, Qt.NoModifier, 0) }
        function twitchNotify(summary: string): void { TwitchService.notifyOnline([summary]) }
        function prepareEmitter(id: int): void {
            root.cardEntry = NotificationService.liveEntries[id] || root.cardEntry
            card.visible = false
            emitterGroup.visible = true
            settings.visible = false
        }
        function emitterButton(name: string): bool {
            const button = root.find(emitterGroup, name) as Item
            return !!button && mouse.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
        }
        function prepareSettings(filter: string): void {
            settings.filter = filter
            settings.visible = true
            card.visible = false
            emitterGroup.visible = false
        }
        function settingsButton(name: string): bool {
            const button = root.find(settings, name) as Item
            return !!button && mouse.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
        }
        function nativeUi(): string { return JSON.stringify(root.nativeView?.snapshot() || {}) }
        function preview(path: string): bool { return root.nativeView?.preview(path) || false }
        function filter(filter: string): string { settings.filter = filter; return JSON.stringify(settings.emitters.map(emitter => emitter.key)) }
        function focusFallback(): bool {
            return !WindowService.focusEmitter("unmatched.desktop", "unmatched")
        }
    }
}
