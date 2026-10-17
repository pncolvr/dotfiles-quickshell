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

    color: pulseActive ? "white" : baseColor
    layer.enabled: pulseActive
    layer.smooth: UI.TextureSettings.smooth
    layer.mipmap: UI.TextureSettings.mipmap
    layer.effect: ShaderEffect {
        id: pulseShader
        property var source
        property color baseColor: root.baseColor
        property color pulseColor: root.pulseColor
        property real phase: 0
        property real phaseOffset: PulseClock.offset(Theme.pulsingTextDuration)
        property bool active: root.pulseActive
        property bool awaitingSync: true
        onActiveChanged: if (active) awaitingSync = true
        fragmentShader: Qt.resolvedUrl("./shaders/pulse.frag.qsb")
        Connections {
            target: root.pulseActive && pulseShader.awaitingSync ? root.Window.window : null
            function onFrameSwapped() {
                // Window exposure and texture creation can delay the first rendered frame.
                pulseShader.phaseOffset = PulseClock.offset(Theme.pulsingTextDuration)
                pulseShader.awaitingSync = false
            }
        }
        UI.MotionUniformAnimator {
            target: pulseShader
            uniform: "phase"
            from: 0
            to: 1
            animationDuration: Theme.pulsingTextDuration
            policyEnabled: root.animationEnabled
            running: root.pulseActive && !pulseShader.awaitingSync
            loops: Animation.Infinite
        }
    }
}
