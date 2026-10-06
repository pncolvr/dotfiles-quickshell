pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../config"
import "../../../services"

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root
    property var lastScreen: null
    property var targetScreen: null
    readonly property int shadowBlurRadius: 32
    readonly property int shadowVerticalOffset: 8
    // Keep cards 24 px from the bar and screen edge; reserve space for shadows.
    readonly property int contentPaddingLeft: shadowBlurRadius
    readonly property int contentPaddingRight: 24
    readonly property int contentPaddingTop: 24
    readonly property int contentPaddingBottom: shadowBlurRadius + shadowVerticalOffset
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
    WlrLayershell.margins.top: Theme.barHeight
    WlrLayershell.margins.right: 0
    color: "transparent"
    implicitWidth: Math.max(1, Math.min(Theme.notificationWidth + contentPaddingLeft + contentPaddingRight - 24,
        targetScreen?.width || 500))
    implicitHeight: Math.min(stack.height + contentPaddingTop + contentPaddingBottom,
        Math.max(1, (targetScreen?.height || 1080) - Theme.barHeight))
    WlrLayershell.namespace: Config.screenShareHiddenNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {
        x: root.contentPaddingLeft; y: root.contentPaddingTop
        width: stack.width
        height: Math.max(0, root.height - root.contentPaddingTop - root.contentPaddingBottom)
    }
    Item {
        x: root.contentPaddingLeft
        y: root.contentPaddingTop
        width: Math.max(1, parent.width - root.contentPaddingLeft - root.contentPaddingRight)
        height: Math.max(0, parent.height - root.contentPaddingTop - root.contentPaddingBottom)
        // Clip scrolling content first, then let its shadow fade outside the viewport.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.35
            blurMax: root.shadowBlurRadius
            shadowBlur: 0.8
            shadowVerticalOffset: root.shadowVerticalOffset
            paddingRect: Qt.rect(0, 0, 0, root.shadowVerticalOffset)
        }
        Flickable {
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: stack.height
            boundsBehavior: Flickable.StopAtBounds
            QC.ScrollBar.vertical: UI.ScrollBar {}
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
                    }
                }
            }
        }
    }
}
