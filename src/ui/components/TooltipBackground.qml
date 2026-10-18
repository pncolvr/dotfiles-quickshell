import QtQuick
import QtQuick.Shapes
import "../../theme"

// One outline keeps the concave bar joins and rounded bottom corners seamless.
Shape {
    id: root

    required property real panelWidth
    property real backgroundOpacity: 1
    property color backgroundColor: Theme.tooltipBackground
    property bool barJoin: true
    readonly property real curveRadius: Math.max(0, Math.min(Theme.tooltipRadius, panelWidth / 2, height / 2))
    readonly property real joinRadius: barJoin ? curveRadius : 0
    width: panelWidth + joinRadius * 2
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: Qt.rgba(root.backgroundColor.r, root.backgroundColor.g, root.backgroundColor.b,
            root.backgroundColor.a * Math.max(0, Math.min(1, root.backgroundOpacity)))
        strokeColor: "transparent"
        strokeWidth: -1
        startX: 0
        startY: 0
        PathLine { x: root.width; y: 0 }
        PathArc {
            x: root.width - root.joinRadius; y: root.joinRadius
            radiusX: root.joinRadius; radiusY: radiusX
            direction: PathArc.Counterclockwise
        }
        PathLine { x: root.width - root.joinRadius; y: root.height - root.curveRadius }
        PathArc {
            x: root.width - root.joinRadius - root.curveRadius; y: root.height
            radiusX: root.curveRadius; radiusY: radiusX
            direction: PathArc.Clockwise
        }
        PathLine { x: root.joinRadius + root.curveRadius; y: root.height }
        PathArc {
            x: root.joinRadius; y: root.height - root.curveRadius
            radiusX: root.curveRadius; radiusY: radiusX
            direction: PathArc.Clockwise
        }
        PathLine { x: root.joinRadius; y: root.joinRadius }
        PathArc {
            x: 0; y: 0
            radiusX: root.joinRadius; radiusY: radiusX
            direction: PathArc.Counterclockwise
        }
    }
}
