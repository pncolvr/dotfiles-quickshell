pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import "../../theme"

QC.ScrollBar {
    id: root
    readonly property bool needed: size > 0 && size < 1
    readonly property Flickable scrollHost: (parent as Flickable)
        ?? ((parent as QC.ScrollView)?.contentItem as Flickable)
    readonly property bool interacting: active || hovered || pressed || viewportHover.hovered
    // Extra inset for viewports that include shadows or other outer space.
    property real edgeInset: 0
    readonly property real gutterInset: edgeInset + (Theme.scrollbarGutter - thickness) / 2
    property real thickness: hovered || pressed ? Theme.scrollbarHoverWidth : Theme.scrollbarWidth

    function noteMovement() { if (visible && needed) hold.restart() }
    onInteractingChanged: {
        if (interacting) hold.stop()
        else if (visible) hold.restart()
    }
    onVisibleChanged: if (!visible) hold.stop()
    policy: QC.ScrollBar.AsNeeded
    visible: policy !== QC.ScrollBar.AlwaysOff && (policy === QC.ScrollBar.AlwaysOn || needed)
    hoverEnabled: true
    z: 1
    padding: 0
    implicitWidth: thickness
    implicitHeight: thickness
    anchors.right: orientation === Qt.Vertical ? parent?.right : undefined
    anchors.top: orientation === Qt.Vertical ? parent?.top : undefined
    anchors.left: orientation === Qt.Horizontal ? parent?.left : undefined
    anchors.bottom: orientation === Qt.Horizontal ? parent?.bottom : undefined
    anchors.rightMargin: orientation === Qt.Vertical ? gutterInset : 0
    anchors.bottomMargin: orientation === Qt.Horizontal ? gutterInset : 0
    width: orientation === Qt.Vertical ? implicitWidth : (parent?.width ?? 0)
    height: orientation === Qt.Vertical ? (parent?.height ?? 0) : implicitHeight
    minimumSize: Math.min(1, Theme.scrollbarMinimumLength / Math.max(1, orientation === Qt.Vertical ? height : width))
    background: null

    MotionBehavior on thickness {
        NumberAnimation { duration: Theme.scrollbarGrowDuration; easing.type: Easing.OutCubic }
    }
    HoverHandler { id: viewportHover; parent: root.parent; target: null }
    Timer { id: hold; interval: Theme.scrollbarHideDelay }
    Connections {
        target: root.scrollHost
        function onContentXChanged() { if (root.orientation === Qt.Horizontal) root.noteMovement() }
        function onContentYChanged() { if (root.orientation === Qt.Vertical) root.noteMovement() }
    }
    contentItem: Rectangle {
        radius: Math.min(Theme.scrollbarWidth, width, height) / 2
        color: Theme.accent
        opacity: 0
        states: State {
            name: "active"
            when: root.visible && (root.policy === QC.ScrollBar.AlwaysOn || root.interacting || hold.running)
            PropertyChanges { root.contentItem.opacity: 1 }
        }
        transitions: Transition {
            from: "active"
            MotionAnimation { property: "opacity"; to: 0; animationDuration: Theme.scrollbarFadeDuration }
        }
    }
    HoverHandler {
        objectName: "scrollbarGrip"
        cursorShape: root.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }
}
