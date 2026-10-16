pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// The bar expansion and keyboard-opened tray use the same native app items.
Row {
    id: root
    property var window: root.QsWindow.window
    readonly property bool nativeDialogOpen: {
        for (let index = 0; index < items.count; index++)
            if ((items.itemAt(index) as TrayItem)?.nativeDialogOpen) return true
        return false
    }
    Repeater {
        id: items
        model: SystemTray.items
        TrayItem {
            required property var modelData
            item: modelData
            window: root.window
        }
    }
}
