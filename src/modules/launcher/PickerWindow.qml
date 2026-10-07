pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../theme"
import "../../theme/ui" as UI
import "../../services"
import "../../config"

UI.PanelWindow {
    id: root
    property var picker: PickerService
    readonly property Item previewItem: frame
    readonly property bool gridMode: picker.layout === "grid"
    readonly property int shadowBlurRadius: Math.max(2, Math.min(64, Theme.tooltipShadowBlurRadius))
    readonly property real shadowPaddingX: Theme.tooltipShadowEnabled
        ? shadowBlurRadius + Math.abs(Theme.tooltipShadowHorizontalOffset) : 0
    readonly property real shadowPaddingY: Theme.tooltipShadowEnabled
        ? shadowBlurRadius + Math.abs(Theme.tooltipShadowVerticalOffset) : 0
    screen: Quickshell.screens.includes(picker.targetScreen) ? picker.targetScreen : Quickshell.screens[0] ?? null
    visible: picker.visible && !!picker.targetScreen
    implicitWidth: Math.min((gridMode ? Theme.pickerWidth * 1.5 : Theme.pickerWidth) + shadowPaddingX * 2,
        (screen?.width || 800) - 40)
    implicitHeight: Math.min((screen?.height || 1080) * 0.75, panel.implicitHeight + shadowPaddingY * 2)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // The shadow stays outside the input region, like the bar tooltips.
    mask: Region { x: panel.x; y: panel.y; width: panel.width; height: panel.height }
    WlrLayershell.namespace: Config.pickerNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) Qt.callLater(() => { panel.focusSearch(); grab.active = true })
    HyprlandFocusGrab {
        id: grab
        windows: [root]
        onCleared: if (root.visible) root.picker.close()
    }
    Connections {
        target: root.picker
        function onVisibleChanged() { if (!root.picker.visible) grab.active = false }
    }
    Component.onCompleted: ClipboardService.initialize()

    Item {
        id: frame
        anchors.fill: parent
        Rectangle {
            id: shadowSource
            x: panel.x; y: panel.y
            width: panel.width; height: panel.height
            radius: panel.radius
            color: Theme.tooltipBackground
            visible: false
        }
        // Blur only the rounded silhouette; render text and controls directly.
        MultiEffect {
            source: shadowSource
            x: shadowSource.x + Theme.tooltipShadowHorizontalOffset
            y: shadowSource.y + Theme.tooltipShadowVerticalOffset
            width: shadowSource.width; height: shadowSource.height
            visible: Theme.tooltipShadowEnabled
            blurEnabled: true
            blurMax: root.shadowBlurRadius
            blur: 1
            colorization: 1
            colorizationColor: Theme.tooltipShadowColor
            opacity: Theme.tooltipShadowOpacity * Theme.tooltipShadowColor.a
        }
        PickerPanel {
            id: panel
            anchors.fill: parent
            anchors.leftMargin: root.shadowPaddingX
            anchors.rightMargin: root.shadowPaddingX
            anchors.topMargin: root.shadowPaddingY
            anchors.bottomMargin: root.shadowPaddingY
            picker: root.picker
        }
    }
}
