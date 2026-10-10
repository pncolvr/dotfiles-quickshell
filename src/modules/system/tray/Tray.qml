pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

UI.Row {
    id: root
    required property var window
    property string moduleName: ""
    readonly property var tooltipScreen: window.screen
    readonly property var tooltipWindow: window
    readonly property var tooltip: null
    readonly property Item modulePointerTarget: trigger
    property bool pointerHovered: false
    readonly property bool expanded: hoverHandler.hovered || pointerHovered
    height: Math.max(Theme.barHeight, implicitHeight)
    Component.onCompleted: if (moduleName) BarModuleService.register(root)
    Component.onDestruction: if (moduleName) BarModuleService.unregister(root)
    HoverHandler {
        id: hoverHandler
        parent: root
        target: root
        onHoveredChanged: if (hovered) BarModuleService.releasePointerHover(root)
    }

    UI.WrapperMouseArea {
        id: trigger
        implicitHeight: Theme.barHeight
        leftMargin: Theme.tooltipHoverPaddingWidth
        rightMargin: Theme.tooltipHoverPaddingWidth
        resizeChild: false
        acceptedButtons: Qt.NoButton
        UI.IconText { text: root.expanded ? Theme.trayOpenIcon : Theme.trayClosedIcon }
    }

    Rectangle {
        id: trayBackground
        visible: root.expanded
        color: Theme.expandedBackground
        radius: Theme.expandedBackgroundRadius
        implicitWidth: tray.implicitWidth + Theme.expandedBackgroundPaddingWidth * 2
        implicitHeight: tray.implicitHeight + Theme.expandedBackgroundPaddingHeight * 2

        Row {
            id: tray
            visible: root.expanded
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
