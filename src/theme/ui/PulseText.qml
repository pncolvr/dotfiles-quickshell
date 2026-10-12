import QtQuick
import QtQuick.Window
import "../"
import "./components" as UI

UI.Text {
    id: root
    property bool pulsing: false
    property color pulseColor: Theme.pulsingTextPulseColor
    property color baseColor: Theme.pulsingTextBaseColor
    readonly property bool pulseActive: pulsing && visible && (Window.window?.visible ?? false)

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
        fragmentShader: Qt.resolvedUrl("../shaders/pulse.frag.qsb")
        SequentialAnimation {
            running: root.pulseActive
            loops: Animation.Infinite
            UniformAnimator { target: pulseShader; uniform: "phase"; from: 0; to: 1; duration: Theme.pulsingTextDuration / 2; easing.type: Easing.InOutSine }
            UniformAnimator { target: pulseShader; uniform: "phase"; from: 1; to: 0; duration: Theme.pulsingTextDuration / 2; easing.type: Easing.InOutSine }
        }
    }
}
