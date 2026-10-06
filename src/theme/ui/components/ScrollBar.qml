import QtQuick
import QtQuick.Controls as QC
import "../../"

QC.ScrollBar {
    id: root
    readonly property bool needed: size > 0 && size < 1

    policy: QC.ScrollBar.AsNeeded
    visible: policy !== QC.ScrollBar.AlwaysOff && (policy === QC.ScrollBar.AlwaysOn || needed)
    hoverEnabled: true
    padding: 0
    implicitWidth: Theme.scrollbarWidth
    implicitHeight: Theme.scrollbarWidth
    x: orientation === Qt.Vertical ? (parent?.width ?? 0) - width : 0
    y: orientation === Qt.Horizontal ? (parent?.height ?? 0) - height : 0
    width: orientation === Qt.Vertical ? implicitWidth : (parent?.width ?? 0)
    height: orientation === Qt.Vertical ? (parent?.height ?? 0) : implicitHeight
    minimumSize: Math.min(1, Theme.scrollbarWidth / Math.max(1, orientation === Qt.Vertical ? height : width))
    background: null

    contentItem: Rectangle {
        radius: Math.min(width, height) / 2
        color: Theme.accent
        opacity: 0
        states: State {
            name: "active"
            when: root.policy === QC.ScrollBar.AlwaysOn || root.active || root.hovered || root.pressed
            PropertyChanges { root.contentItem.opacity: 1 }
        }
        transitions: Transition {
            from: "active"
            SequentialAnimation {
                PauseAnimation { duration: Theme.scrollbarHideDelay }
                NumberAnimation { property: "opacity"; to: 0; duration: Theme.scrollbarFadeDuration }
            }
        }
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
