pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../theme"
import "../theme/ui" as UI
// qmllint disable uncreatable-type
PanelWindow {
    id: root
    property var capturePanel: null
    property bool hideForCapture: capturePanel?.hideForCapture ?? false
    signal captureHideRequested()
    UI.CaptureOverlay { host: root; requested: root.requestedVisible }
    default property alias contentData: surface.contentData
    property alias contentKey: surface.contentKey
    property alias contentX: surface.contentX
    property alias contentWidth: surface.contentWidth
    property alias contentHeight: surface.contentHeight
    property alias requestedVisible: surface.requestedVisible
    property alias continuousGeometry: surface.continuousGeometry
    property alias reservedContentHeight: surface.reservedContentHeight
    property alias requestedScreen: surface.requestedScreen
    readonly property bool transitioning: surface.motion.transitioning
    readonly property real layoutContentWidth: surface.motion.layoutWidth
    readonly property real layoutContentHeight: surface.motion.layoutHeight
    requestedScreen: Quickshell.screens[0] ?? null
    visible: surface.presented && surface.motion.reservedHeight > 0 && surface.motion.displayedWidth > 0
    screen: surface.motion.displayedScreen ?? requestedScreen
    property alias backgroundOpacity: surface.backgroundOpacity
    readonly property real shadowBottomPadding: surface.shadowBottomPadding
    anchors.top: true
    exclusiveZone: 0
    readonly property var geometryScreen: screen
    implicitWidth: geometryScreen?.width ?? 0
    // Keep the native buffer stable while mapped. A compositor can briefly
    // stretch a new, shorter buffer during a layer-surface resize, even with
    // our animations disabled. Geometry and input stay inside the surface.
    implicitHeight: Math.max(1, (geometryScreen?.height ?? 1080) - Theme.barHeight)
    color: "transparent"
    mask: Region { x: surface.inputRect.x; y: surface.inputRect.y; width: surface.inputRect.width; height: surface.inputRect.height }
    property TopPanelSurface surfaceComponent: TopPanelSurface { id: surface; parent: root.contentItem; width: root.width; height: root.height }
}
