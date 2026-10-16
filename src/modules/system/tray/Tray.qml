pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

UI.Row {
    id: root
    required property var window
    property string moduleName: "tray"
    readonly property var tooltipScreen: window.screen
    readonly property var tooltipWindow: window
    readonly property bool centerTooltip: false
    readonly property Component tooltip: Component { TrayContents {} }
    readonly property bool expanded: hoverHandler.hovered
    height: Math.max(Theme.barHeight, implicitHeight)
    Component.onCompleted: if (moduleName) BarModuleService.register(root)
    Component.onDestruction: if (moduleName) BarModuleService.unregister(root)
    HoverHandler {
        id: hoverHandler
        parent: root
        target: root
    }

    UI.WrapperMouseArea {
        id: trigger
        visible: !root.expanded
        implicitHeight: Theme.barHeight
        leftMargin: Theme.tooltipHoverPaddingWidth
        rightMargin: Theme.tooltipHoverPaddingWidth
        resizeChild: false
        acceptedButtons: Qt.NoButton
        UI.BarIcon {
            text: Theme.trayIcon
            color: Theme.text
        }
    }

    Rectangle {
        id: trayBackground
        anchors.verticalCenter: parent.verticalCenter
        visible: root.expanded
        color: Theme.expandedBackground
        radius: Theme.expandedBackgroundRadius
        implicitWidth: tray.implicitWidth + Theme.expandedBackgroundPaddingWidth * 2
        implicitHeight: tray.implicitHeight + Theme.expandedBackgroundPaddingHeight * 2

        TrayContents {
            id: tray
            visible: root.expanded
            anchors.centerIn: parent
            window: root.window
        }
    }
}
