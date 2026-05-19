import QtQuick
import Quickshell
import "../theme"
import "../theme/ui" as UI

PanelWindow {
    id: root

    default property alias contentData: panel.data
    property alias contentX: panel.x
    property alias contentWidth: panel.width
    property alias contentHeight: panel.height

    anchors.top: true
    exclusiveZone: 0
    implicitWidth: screen.width
    implicitHeight: panel.height
    color: "transparent"

    Rectangle {
        id: panel
        y: 0
        color: Theme.tooltipBackground
        bottomLeftRadius: Theme.tooltipRadius
        bottomRightRadius: Theme.tooltipRadius
    }

    UI.TooltipCorner {
        x: panel.x - width + 1
        y: panel.y
        side: UI.TooltipCorner.Side.Left
    }

    UI.TooltipCorner {
        x: panel.x + panel.width - 1
        y: panel.y
        side: UI.TooltipCorner.Side.Right
    }
}
