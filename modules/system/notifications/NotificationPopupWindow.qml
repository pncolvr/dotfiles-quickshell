pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../../theme"
import "../../../config"
import "../../../services"

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root
    property var lastScreen: null
    property var targetScreen: null
    function selectScreen() {
        const screens = Quickshell.screens
        const focused = screens.find(output => output.name === Hyprland.focusedMonitor?.name)
        targetScreen = focused || (screens.includes(lastScreen) ? lastScreen : screens[0]) || null
        if (targetScreen) lastScreen = targetScreen
    }
    Connections { target: Quickshell; function onScreensChanged() { root.selectScreen() } }
    Connections { target: Hyprland; function onFocusedMonitorChanged() { root.selectScreen() } }
    Component.onCompleted: selectScreen()
    screen: targetScreen
    visible: NotificationService.popups.length > 0 && !!targetScreen
    anchors.top: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.margins.top: Theme.barHeight + 12
    WlrLayershell.margins.right: 12
    color: "transparent"
    implicitWidth: Math.max(1, Math.min(Theme.notificationWidth, (targetScreen?.width || 500) - 24))
    implicitHeight: Math.min(stack.height + 24, Math.max(1, (targetScreen?.height || 1080) - Theme.barHeight - 40))
    WlrLayershell.namespace: Config.screenShareHiddenNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { x: 12; y: 12; width: root.width - 24; height: root.height - 24 }
    Flickable {
        anchors.fill: parent
        anchors.margins: 12
        clip: true
        contentWidth: width
        contentHeight: stack.height
        boundsBehavior: Flickable.StopAtBounds
        QC.ScrollBar.vertical: QC.ScrollBar { HoverHandler { cursorShape: Qt.PointingHandCursor } }
        Column {
            id: stack
            width: parent.width
            spacing: Theme.notificationSpacing
            Repeater {
                model: NotificationService.popups
                NotificationCard {
                    required property var modelData
                    entry: modelData
                    popup: true
                    width: stack.width
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "black"; shadowOpacity: 0.35; shadowBlur: 0.8; shadowVerticalOffset: 8 }
                }
            }
        }
    }
}
