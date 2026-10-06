import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../src"
import "../../src/bar"
import "../../src/modules/system/notifications"
import "../../src/services"

Item {
    id: root
    Notifications { id: bell; window: manager }
    Component { Bar {} }
    NotificationPopupWindow { id: popup }
    NotificationManagerWindow { id: manager }
    TooltipWindow { id: regularTooltip; screen: manager.screen }
    function snapshot() {
        return {popupVisible: popup.visible, managerVisible: manager.visible, regularTooltipVisible: regularTooltip.visible,
            groups: manager.groups,
            popupNamespace: popup.WlrLayershell.namespace, managerNamespace: manager.WlrLayershell.namespace,
            popupWidth: popup.width, popupHeight: popup.height,
            managerWidth: manager.width, managerHeight: manager.height,
            screenWidth: popup.screen?.width || 0, screenHeight: popup.screen?.height || 0}
    }
    function preview(path) {
        return manager.previewItem.grabToImage(result => result.saveToFile(path))
    }
    Component.onCompleted: {
        const screen = Quickshell.screens[0]
        if (screen) TooltipService.togglePin(screen.x + screen.width - 100, null, bell, false, screen)
    }
}
