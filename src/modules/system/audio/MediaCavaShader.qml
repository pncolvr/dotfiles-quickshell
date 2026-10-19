pragma ComponentBehavior: Bound
import QtQuick
import "../../../theme"
import "../../../ui" as UI

Item {
    id: root
    required property string preset
    required property var bands
    property bool active: false
    property bool playing: false
    readonly property bool animated: ["eye_of_phi", "orion_circle_rotate"].includes(preset)
    readonly property bool animating: UI.MotionPolicy.mediaVisualizerEnabled && active && playing && animated && bands.some(value => value > 0)
    readonly property int status: shader.status
    property var previousBands: []
    property var targetBands: []
    property real blendStarted: 0
    property bool disposing: false
    function updateBands() {
        if (disposing || !active) return;
        const now = Date.now();
        const progress = Math.min(1, (now - blendStarted) / Theme.mediaVisualizerInterval);
        const next = bands.slice();
        // Retarget from the currently displayed levels when frames arrive early.
        const current = next.map((value, index) => {
            const target = targetBands[index] ?? value;
            return (previousBands[index] ?? target) * (1 - progress) + target * progress;
        });
        bandBlend.stop();
        previousBands = current;
        targetBands = next;
        blendStarted = now;
        dataTexture.scheduleUpdate();
        if (UI.MotionPolicy.mediaVisualizerEnabled && playing && preset !== "spectrogram" && next.some((value, index) => value !== current[index])) {
            shader.band_blend = 0;
            bandBlend.start();
        } else shader.band_blend = 1;
        if (active && playing && preset === "spectrogram") history.scheduleUpdate();
    }
    onBandsChanged: Qt.callLater(updateBands)
    onActiveChanged: {
        if (active) Qt.callLater(updateBands);
        else { bandBlend.stop(); shader.band_blend = 1; }
    }
    onPlayingChanged: {
        if (playing) Qt.callLater(updateBands);
        else { bandBlend.stop(); shader.band_blend = 1; }
    }
    onPresetChanged: Qt.callLater(updateBands)
    Component.onCompleted: Qt.callLater(updateBands)
    Component.onDestruction: disposing = true

    // Upload band values as native geometry into a tiny GPU texture, not a CPU bitmap.
    Row {
        id: pixels
        width: root.bands.length
        height: 1
        // Keep the Row laid out; hideSource prevents it appearing on the card.
        visible: root.active
        Repeater {
            model: root.bands.length
            delegate: Rectangle {
                required property int index
                width: 1
                height: 1
                // One upload per audio frame; interpolate these channels on the GPU.
                color: Qt.rgba(root.previousBands[index] ?? 0, root.targetBands[index] ?? 0, 0, 1)
            }
        }
    }
    UI.ScaledTexture {
        id: dataTexture
        sourceItem: root.active ? pixels : null
        textureSize: Qt.size(root.bands.length, 1)
        live: false
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
        property real band_blend: 1
        property var audioData: dataTexture
        property var inputTexture: history
        vertexShader: Qt.resolvedUrl("../../../ui/shaders/cava/pass_through.vert.qsb")
        fragmentShader: Qt.resolvedUrl("../../../ui/shaders/cava/" + root.preset + ".frag.qsb")
    }
    UI.MotionUniformAnimator {
        id: bandBlend
        policyEnabled: UI.MotionPolicy.mediaVisualizerEnabled
        objectName: "mediaCavaBandBlend"
        target: shader
        uniform: "band_blend"
        from: 0
        to: 1
        animationDuration: Theme.mediaVisualizerInterval
    }
    UI.MotionUniformAnimator {
        policyEnabled: UI.MotionPolicy.mediaVisualizerEnabled
        objectName: "mediaCavaTime"
        target: shader
        uniform: "shader_time"
        from: 0
        to: 4096
        animationDuration: 4096000
        loops: Animation.Infinite
        running: root.animating
    }
}
