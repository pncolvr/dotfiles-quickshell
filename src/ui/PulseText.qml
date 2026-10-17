pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import "../theme"
import "./components" as UI

UI.Text {
    id: root
    property bool pulsing: false
    property bool animationEnabled: UI.MotionPolicy.enabled
    property color pulseColor: Theme.pulsingTextPulseColor
    property color baseColor: Theme.pulsingTextBaseColor
    readonly property bool pulseActive: animationEnabled && pulsing && visible && (Window.window?.visible ?? false)
    property bool clockReady: false
    onPulseActiveChanged: if (clockReady) PulseClock.update(root, pulseActive)
    Component.onCompleted: { clockReady = true; PulseClock.update(root, pulseActive) }
    Component.onDestruction: PulseClock.update(root, false)

    color: pulseActive ? "white" : baseColor
    layer.enabled: pulseActive
    layer.smooth: UI.TextureSettings.smooth
    layer.mipmap: UI.TextureSettings.mipmap
    layer.effect: ShaderEffect {
        id: pulseShader
        property var source
        property color baseColor: root.baseColor
        property color pulseColor: root.pulseColor
        property real phase: PulseClock.phase
        fragmentShader: Qt.resolvedUrl("./shaders/pulse.frag.qsb")
    }
}
