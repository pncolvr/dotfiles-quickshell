pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../theme/ui" as UI
UI.PrivatePanelWindow {
    id: root
    default property alias contentData: surface.contentData
    property alias contentX: surface.contentX
    property alias contentWidth: surface.contentWidth
    property alias contentHeight: surface.contentHeight
    property alias backgroundOpacity: surface.backgroundOpacity
    readonly property real shadowBottomPadding: surface.shadowBottomPadding
    anchors.top: true
    exclusiveZone: 0
    readonly property var geometryScreen: screen
    implicitWidth: geometryScreen?.width ?? 0
    implicitHeight: surface.implicitHeight
    color: "transparent"
    mask: Region { x: surface.inputRect.x; y: surface.inputRect.y; width: surface.inputRect.width; height: surface.inputRect.height }
    property TopPanelSurface surfaceComponent: TopPanelSurface { id: surface; parent: root.contentItem; width: root.width; height: root.height }
}
