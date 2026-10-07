import QtQuick
import QtQuick.Shapes
import "../../"

// One outline keeps the concave bar joins and rounded bottom corners seamless.
Shape {
    id: root

    required property real panelWidth
    property real backgroundOpacity: 1
    readonly property real curveRadius: Math.max(0, Math.min(Theme.tooltipRadius, panelWidth / 2, height / 2))
    width: panelWidth + curveRadius * 2
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: Qt.rgba(Theme.tooltipBackground.r, Theme.tooltipBackground.g, Theme.tooltipBackground.b,
            Theme.tooltipBackground.a * Math.max(0, Math.min(1, root.backgroundOpacity)))
        strokeColor: "transparent"
        strokeWidth: -1
        startX: 0
        startY: 0
        PathLine { x: root.width; y: 0 }
        PathArc {
            x: root.width - root.curveRadius; y: root.curveRadius
            radiusX: root.curveRadius; radiusY: radiusX
            direction: PathArc.Counterclockwise
        }
        PathLine { x: root.width - root.curveRadius; y: root.height - root.curveRadius }
        PathArc {
            x: root.panelWidth; y: root.height
            radiusX: root.curveRadius; radiusY: radiusX
            direction: PathArc.Clockwise
        }
        PathLine { x: root.curveRadius * 2; y: root.height }
        PathArc {
            x: root.curveRadius; y: root.height - root.curveRadius
            radiusX: root.curveRadius; radiusY: radiusX
            direction: PathArc.Clockwise
        }
        PathLine { x: root.curveRadius; y: root.curveRadius }
        PathArc {
            x: 0; y: 0
            radiusX: root.curveRadius; radiusY: radiusX
            direction: PathArc.Counterclockwise
        }
    }
}
