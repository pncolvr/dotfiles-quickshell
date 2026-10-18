pragma ComponentBehavior: Bound
import QtQuick
import ".." as UI
import "../../theme"

Item {
    id: root
    property bool islands: false
    property color background: Theme.background
    property rect leftBounds
    property rect centerBounds
    property rect rightBounds
    property var bridges: []
    property real islandFraction: islands ? 1 : 0
    UI.MotionBehavior on islandFraction { UI.MotionAnimation { animationDuration: Theme.panelResizeDuration } }
    Rectangle { anchors.fill: parent; color: root.background; opacity: 1 - root.islandFraction }
    Rectangle {
        x: root.leftBounds.x; width: root.leftBounds.width; height: parent.height
        color: root.background
        bottomRightRadius: Theme.tooltipRadius
        antialiasing: true
    }
    Rectangle {
        x: root.centerBounds.x; width: root.centerBounds.width; height: parent.height
        color: root.background
        bottomLeftRadius: Theme.tooltipRadius; bottomRightRadius: Theme.tooltipRadius
        antialiasing: true
    }
    Rectangle {
        x: root.rightBounds.x; width: root.rightBounds.width; height: parent.height
        color: root.background
        bottomLeftRadius: Theme.tooltipRadius
        antialiasing: true
    }
    Repeater {
        model: root.bridges
        delegate: Rectangle {
            required property var modelData
            x: modelData.x; width: modelData.width; height: root.height
            color: root.background; opacity: modelData.opacity * root.islandFraction
        }
    }
}
