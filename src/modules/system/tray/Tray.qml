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
        onHoveredChanged: {
            tray.visible = hovered
            trayBackground.visible = hovered
        }
    }

    UI.IconText {
        text: tray.visible ? Theme.trayOpenIcon : Theme.trayClosedIcon
    }

    Rectangle {
        id: trayBackground
        visible: false
        color: Theme.expandedBackground
        radius: Theme.expandedBackgroundRadius
        implicitWidth: tray.implicitWidth + Theme.expandedBackgroundPaddingWidth * 2
        implicitHeight: tray.implicitHeight + Theme.expandedBackgroundPaddingHeight * 2

        Row {
            id: tray
            anchors.centerIn: parent

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
}