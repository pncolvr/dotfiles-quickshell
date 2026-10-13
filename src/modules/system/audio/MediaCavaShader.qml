pragma ComponentBehavior: Bound
import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI

Item {
    id: root
    required property string preset
    required property var bands
    property bool active: false
    property bool playing: false
    readonly property bool animated: ["eye_of_phi", "orion_circle_rotate"].includes(preset)
    readonly property bool animating: active && playing && animated && bands.some(value => value > 0)
    readonly property int status: shader.status
    function updateHistory() {
        if (active && playing && preset === "spectrogram") history.scheduleUpdate();
    }
    onBandsChanged: Qt.callLater(updateHistory)
    onActiveChanged: Qt.callLater(updateHistory)
    onPresetChanged: Qt.callLater(updateHistory)

    // Upload band values as native geometry into a tiny GPU texture, not a CPU bitmap.
    Row {
        id: pixels
        width: root.bands.length
        height: 1
        visible: false
        Repeater {
            model: root.bands.length
            delegate: Rectangle {
                required property int index
                width: 1
                height: 1
                color: Qt.rgba(root.bands[index], root.bands[index], root.bands[index], 1)
            }
        }
    }
    UI.ScaledTexture {
        id: dataTexture
        sourceItem: root.active ? pixels : null
        textureSize: Qt.size(root.bands.length, 1)
        live: root.active
        hideSource: true
        smooth: false
        mipmap: false
        visible: false
    }
    UI.ScaledTexture {
        id: history
        sourceItem: root.active && root.preset === "spectrogram" ? shader : null
        textureSize: Qt.size(512, root.bands.length)
        recursive: true
        live: false
        smooth: false
        mipmap: false
        visible: false
    }
    ShaderEffect {
        id: shader
        objectName: "mediaCavaShader"
        anchors.fill: parent
        property color foreground: Theme.accent
        property vector3d u_resolution: Qt.vector3d(width, height, 0)
        property real shader_time: 0
        property int bars_count: root.bands.length
        property int bar_width: Math.max(1, Math.floor(width / bars_count) - 2)
        property int bar_spacing: 2
        property var audioData: dataTexture
        property var inputTexture: history
        vertexShader: Qt.resolvedUrl("../../../theme/shaders/cava/pass_through.vert.qsb")
        fragmentShader: Qt.resolvedUrl("../../../theme/shaders/cava/" + root.preset + ".frag.qsb")
    }
    UniformAnimator {
        target: shader
        uniform: "shader_time"
        from: 0
        to: 4096
        duration: 4096000
        loops: Animation.Infinite
        running: root.animating
    }
}
