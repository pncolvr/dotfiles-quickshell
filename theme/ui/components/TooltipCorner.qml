import QtQuick
import QtQuick.Shapes
import "../../"

Shape {
    id: root

    enum Side { Left, Right }

    required property int side
    width: Theme.tooltipRadius
    height: Theme.tooltipRadius

    rotation: side === TooltipCorner.Side.Left ? 0 : -90

    ShapePath {
        fillColor: Theme.background
        strokeWidth: 0
        startX: 0; startY: 0
        PathArc {
            x: root.width; y: root.height
            radiusX: root.width
            radiusY: root.height
            direction: PathArc.Clockwise
        }
        PathLine { x: root.width; y: 0 }
    }
}
