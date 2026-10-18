import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../src/ui/bar"
import "../../src/ui/panels"
import "../../src/modules/system/notifications"
import "../../src/services"

Item {
    id: root
    Notifications { id: bell; window: manager }
    Component { Bar {} }
    NotificationPopupWindow { id: popup }
    NotificationManagerWindow { id: manager }
    readonly property Item managerContent: manager.previewItem
    TooltipWindow { id: regularTooltip; screen: manager.screen }
    function popupCard(id) { return popup.popupStack.cards.find(card => card.entry.liveId === id && !card.closing) ?? null }
    function snapshot() {
        return {popupVisible: popup.visible, managerVisible: manager.visible, regularTooltipVisible: regularTooltip.visible,
            groups: manager.groups, managerTab: manager.tab,
            popupNamespace: popup.WlrLayershell.namespace, managerNamespace: manager.WlrLayershell.namespace,
            popupWidth: popup.width, popupHeight: popup.height,
            managerWidth: manager.width, managerHeight: manager.height,
            screenWidth: popup.targetScreen?.width || 0, screenHeight: popup.targetScreen?.height || 0}
    }
    function preview(path) {
        return manager.previewItem.grabToImage(result => result.saveToFile(path))
    }
    Component.onCompleted: {
        const screen = Quickshell.screens[0]
        if (screen) TooltipService.togglePin(screen.x + screen.width - 100, null, bell, false, screen)
    }
}
