pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import "../../../theme"
import "../../../theme/ui" as UI

UI.Row {
    id: root
    required property var window
    HoverHandler {
        id: hoverHandler
        target: root
        onHoveredChanged: tray.visible = hovered
    }

    UI.IconText {
        text: tray.visible ? Theme.trayOpenIcon : Theme.trayClosedIcon
    }

    Row {
        id: tray
        visible: false

        Repeater {
            id: itemsRepeater
            model: SystemTray.items
            delegate: TrayItem {
                required property var modelData
                item: modelData
                window: root.window
            }
        }
    }
}