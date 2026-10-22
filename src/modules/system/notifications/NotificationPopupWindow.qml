pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../../theme"
import "../../../ui" as UI
import "../../../services"
import "../../../config"

// qmllint disable uncreatable-type
UI.PrivatePanelWindow {
    // qmllint enable uncreatable-type
    id: root
    QtObject {
        id: samplingObstruction
        readonly property var host: root
        readonly property bool requested: root.visible
        readonly property bool presentationPending: root.visible
        Component.onCompleted: AdaptiveBarService.registerOverlay(samplingObstruction)
        Component.onDestruction: AdaptiveBarService.unregisterOverlay(samplingObstruction)
    }
    property var lastScreen: null
    property var targetScreen: null
    property bool animationsEnabled: UI.MotionPolicy.enabled
    readonly property NotificationPopupStack popupStack: stack
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
    visible: stack.cards.length > 0 && !!targetScreen
    anchors.top: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.margins.top: Theme.barHeight
    WlrLayershell.margins.right: 0
    color: "transparent"
    implicitWidth: Math.max(1, Math.min(Theme.notificationWidth + contentPaddingLeft + contentPaddingRight - 24,
        targetScreen?.width || 500))
    // Keep the native surface stable: resizing it when a lower card disappears
    // can make the compositor stretch or jump the surviving cards. Only the
    // stack and its input region change size inside this transparent surface.
    implicitHeight: Math.max(1, (targetScreen?.height || 1080) - Theme.barHeight)
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {
        x: root.contentPaddingLeft; y: root.contentPaddingTop
        width: stack.width + (popupBar.needed ? Theme.scrollbarGutter : 0)
        height: Math.min(stack.height, Math.max(0, root.height - root.contentPaddingTop - root.contentPaddingBottom))
    }
    Item {
        y: root.contentPaddingTop
        width: parent.width
        height: Math.max(0, parent.height - root.contentPaddingTop - root.contentPaddingBottom)
        // Clip scrolling content first, then let its shadow fade outside the viewport.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.tooltipShadowColor
            shadowOpacity: 0.35
            blurMax: root.shadowBlurRadius
            shadowBlur: 0.8
            shadowVerticalOffset: root.shadowVerticalOffset
            paddingRect: Qt.rect(0, 0, 0, root.shadowVerticalOffset)
        }
        Flickable {
            id: popupView
            property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: popupView }
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: stack.height
            boundsBehavior: Flickable.StopAtBounds
            QC.ScrollBar.vertical: UI.ScrollBar {
                id: popupBar
                edgeInset: Math.max(0, root.contentPaddingRight - Theme.scrollbarGutter)
            }
            NotificationPopupStack {
                id: stack
                x: root.contentPaddingLeft
                width: Math.max(1, parent.width - root.contentPaddingLeft - root.contentPaddingRight)
                entries: NotificationService.popups
                animationsEnabled: root.animationsEnabled
                edgePadding: root.contentPaddingRight
            }
        }
    }
}
