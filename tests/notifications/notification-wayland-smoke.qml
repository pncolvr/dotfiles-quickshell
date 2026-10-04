import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../"
import "../../modules/system/notifications"
import "../../services"

Item {
    id: root
    Item { id: bell; readonly property bool notificationsModule: true }
    Component { Bar {} }
    NotificationPopupWindow { id: popup }
    NotificationManagerWindow { id: manager }
    function snapshot() {
        return {popupVisible: popup.visible, managerVisible: manager.visible,
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
