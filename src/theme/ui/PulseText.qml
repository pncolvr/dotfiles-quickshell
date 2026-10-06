import QtQuick
import "../"
import "./components" as UI

UI.Text {
    id: root
    property bool pulsing: false
    property color pulseColor: Theme.pulsingTextPulseColor
    property color baseColor: Theme.pulsingTextBaseColor

    color: {
        if (!pulsing) return baseColor
        const t = Theme.pulsePhase
        return Qt.rgba(
            baseColor.r + (pulseColor.r - baseColor.r) * t,
            baseColor.g + (pulseColor.g - baseColor.g) * t,
            baseColor.b + (pulseColor.b - baseColor.b) * t,
            baseColor.a + (pulseColor.a - baseColor.a) * t
        )
    }
}
