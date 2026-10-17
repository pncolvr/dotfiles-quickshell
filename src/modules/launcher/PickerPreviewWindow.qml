pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../theme"
import "../../ui" as UI

// A non-activating companion window; the list owns keyboard navigation/focus.
UI.PanelWindow {
    id: root
    required property var host
    required property var picker
    required property var previewPanel
    property bool privateWindow: false
    readonly property bool hideForCapture: previewPanel?.hideForCapture ?? false
    readonly property var requestedScreen: surface.requestedScreen
    readonly property bool requestedVisible: surface.requestedVisible
    readonly property real previewTop: surface.previewTop
    readonly property real previewWidth: surface.previewWidth
    readonly property real previewHeight: surface.previewHeight
    readonly property var previewItem: surface.previewItem
    readonly property bool transitioning: surface.transitioning
    signal captureHideRequested()
    onCaptureHideRequested: picker.close()
    UI.CaptureOverlay { host: root; requested: root.requestedVisible }
    screen: surface.displayedScreen ?? requestedScreen
    readonly property var geometryScreen: screen
    visible: surface.presented
    anchors.top: true
    exclusiveZone: 0
    implicitWidth: geometryScreen?.width ?? 800
    implicitHeight: Math.max(1, (geometryScreen?.height ?? 1080) - Theme.barHeight)
    color: "transparent"
    WlrLayershell.namespace: privateWindow ? Config.screenShareHiddenNamespace : Config.pickerNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // This window only displays an image. An input region would let Hyprland's
    // focus grab give it keyboard focus when it appears beneath the pointer,
    // even with keyboardFocus None. Keep all interaction in the list window.
    mask: Region {}
    PickerPreviewSurface { id: surface; parent: root.contentItem; anchors.fill: parent; host: root.host; picker: root.picker; previewPanel: root.previewPanel }
}
