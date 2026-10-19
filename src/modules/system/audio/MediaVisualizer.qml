pragma ComponentBehavior: Bound
import "../../../i18n"
import QtQuick
import QtQuick.Shapes
import QtQml.Models
import Quickshell.Services.Pipewire
import "../../../ui" as UI
import "../../../theme"
import "../../../services"

Item {
    id: root
    // Decorative pixels do not constrain the shared bar/panel text background.
    readonly property bool adaptiveContrastExcluded: true
    property var nodes: []
    property bool active: false
    property bool playing: false
    property string appId: ""
    readonly property string effectPreferenceKey: appId ? "media.visualizer.effect.app." + encodeURIComponent(appId) : ""
    readonly property string effect: {
        const previous = PreferencesRepository.value("media.visualizer.effect", "wave");
        const saved = PreferencesRepository.value(effectPreferenceKey, previous);
        return effects.some(option => option.name === saved) ? saved : "wave";
    }
    function selectEffect(name) {
        if (!effectPreferenceKey || !effects.some(option => option.name === name)) return false;
        return PreferencesRepository.value(effectPreferenceKey, null) === name
            || PreferencesRepository.setValue(effectPreferenceKey, name);
    }
    readonly property var audioNodes: nodes.filter(node => node instanceof PwNode && node.ready && node.audio)
    readonly property bool hasStreams: audioNodes.length > 0
    readonly property bool rendering: UI.MotionPolicy.mediaVisualizerEnabled && active && playing
    readonly property bool capturing: rendering && hasStreams
    readonly property bool sampling: capturing && workers.count > 0
    property var bands: {
        const combined = Array(Theme.mediaVisualizerPoints).fill(0);
        if (!capturing) return combined;
        for (let i = 0; i < workers.count; i++) {
            const worker = workers.objectAt(i) as MediaSpectrumWorker;
            if (!worker || worker.modelData.audio?.muted) continue;
            for (let band = 0; band < combined.length; band++)
                combined[band] = Math.max(combined[band], worker.frame[band] ?? 0);
        }
        return combined;
    }
    readonly property string error: {
        for (let i = 0; i < workers.count; i++) {
            const worker = workers.objectAt(i) as MediaSpectrumWorker;
            if (worker?.error) return worker.error;
        }
        return "";
    }
    property var waveform: {
        const combined = Array(Theme.mediaVisualizerPoints).fill(0);
        if (!capturing) return combined;
        for (let i = 0; i < workers.count; i++) {
            const worker = workers.objectAt(i) as MediaSpectrumWorker;
            if (!worker || worker.modelData.audio?.muted) continue;
            for (let point = 0; point < combined.length; point++)
                combined[point] = Math.max(-1, Math.min(1, combined[point] + (worker.waveform[point] ?? 0)));
        }
        return combined;
    }
    readonly property string cavaPreset: effects.find(option => option.name === effect)?.shader ?? ""
    readonly property var effects: [
        {name: "wave", description: Translations.text("media.visualizers.wave"), available: true},
        {name: "bars", description: Translations.text("media.visualizers.bars"), available: true},
        {name: "mirror", description: Translations.text("media.visualizers.mirror"), available: true},
        {name: "ribbon", description: Translations.text("media.visualizers.ribbon"), available: true},
        {name: "bars_top", description: Translations.text("media.visualizers.barsTop"), available: true},
        {name: "bars_left", description: Translations.text("media.visualizers.barsLeft"), available: true},
        {name: "bars_right", description: Translations.text("media.visualizers.barsRight"), available: true},
        {name: "waveform", description: Translations.text("media.visualizers.waveform"), available: true},
        {name: "cava_bar_spectrum", description: Translations.text("media.visualizers.cava"), shader: "bar_spectrum", available: true},
        {name: "cava_winamp_line", description: Translations.text("media.visualizers.winamp"), shader: "winamp_line_style_spectrum", available: true},
        {name: "cava_northern_lights", description: Translations.text("media.visualizers.aurora"), shader: "northern_lights", available: true},
        {name: "cava_eye_of_phi", description: Translations.text("media.visualizers.eye"), shader: "eye_of_phi", available: true},
        {name: "cava_orion_circle", description: Translations.text("media.visualizers.circle"), shader: "orion_circle", available: true},
        {name: "cava_orion_rotate", description: Translations.text("media.visualizers.rotate"), shader: "orion_circle_rotate", available: true},
        {name: "cava_orion_core", description: Translations.text("media.visualizers.saturnCore"), shader: "orion_saturn_core", available: true},
        {name: "cava_orion_subring", description: Translations.text("media.visualizers.saturnRing"), shader: "orion_saturn_subring", available: true},
        {name: "cava_spectrogram", description: Translations.text("media.visualizers.spectrogram"), shader: "spectrogram", available: true}
    ]

    function parseFrame(text) {
        const values = text.trim().split("|")[0].split(";");
        if (values.length !== Theme.mediaVisualizerPoints || values.some(value => !/^\d+$/.test(value)))
            return null;
        return values.map(value => Math.min(1000, Number(value)) / 1000);
    }
    function parseWaveform(text) {
        const values = (text.trim().split("|")[1] ?? "").split(";");
        if (values.length !== Theme.mediaVisualizerPoints || values.some(value => !/^-?\d+$/.test(value)))
            return null;
        return values.map(value => Math.max(-1000, Math.min(1000, Number(value))) / 1000);
    }
    function clear() {
        for (let i = 0; i < workers.count; i++) {
            const worker = workers.objectAt(i) as MediaSpectrumWorker;
            if (worker) {
                worker.frame = Array(Theme.mediaVisualizerPoints).fill(0);
                worker.waveform = Array(Theme.mediaVisualizerPoints).fill(0);
            }
        }
    }
    onCapturingChanged: clear()

    // Each stream has its own cavacore analysis; combine corresponding frequency bands.
    Instantiator {
        id: workers
        objectName: "mediaSpectrumWorkers"
        model: root.audioNodes
        delegate: MediaSpectrumWorker {
            id: spectrumWorker
            capturing: root.capturing && !modelData.audio?.muted
            onDataReceived: data => {
                const values = root.parseFrame(data);
                // Spectrogram must advance its time axis even when the band values repeat.
                if (values && (root.effect === "cava_spectrogram"
                    || values.some((value, index) => value !== spectrumWorker.frame[index])))
                    spectrumWorker.frame = values;
                if (root.effect === "waveform") {
                    const samples = root.parseWaveform(data);
                    if (samples && samples.some((value, index) => value !== spectrumWorker.waveform[index]))
                        spectrumWorker.waveform = samples;
                }
            }
        }
    }

    // Native scene graph geometry avoids repainting and uploading a Canvas bitmap.
    Item {
        id: plot
        objectName: "mediaVisualizerPlot"
        anchors.fill: parent
        visible: root.rendering && !root.cavaPreset
        readonly property real middle: height / 2
        readonly property real amplitude: Math.max(0, middle - Theme.audioSpacing)
        readonly property bool bars: ["bars", "mirror", "bars_top", "bars_left", "bars_right"].includes(root.effect)
        readonly property bool sideways: ["bars_left", "bars_right"].includes(root.effect)
        readonly property var outline: {
            if (!root.rendering || root.cavaPreset || bars || width <= 0 || height <= 0) return [];
            if (root.effect === "waveform")
                return root.waveform.map((value, index) => Qt.point(index * width / (root.waveform.length - 1), middle - value * amplitude));
            const values = root.bands;
            const step = width / (values.length - 1);
            const points = [];
            for (let i = 0; i < values.length; i++)
                points.push(Qt.point(i * step, middle - values[i] * amplitude));
            for (let i = values.length - 1; i >= 0; i--)
                points.push(Qt.point(i * step, middle + values[i] * amplitude));
            points.push(points[0]);
            return points;
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 1
            color: Theme.inactive
            opacity: 0.25
        }
        Shape {
            objectName: "mediaVisualizerWave"
            anchors.fill: parent
            visible: !plot.bars
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.accent
                strokeWidth: 2
                fillColor: root.effect === "ribbon" ? Qt.alpha(Theme.accent, 0.25) : "transparent"
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap
                PathPolyline { path: plot.outline }
            }
        }
        Repeater {
            model: root.rendering && !root.cavaPreset && plot.bars ? Theme.mediaVisualizerPoints : 0
            delegate: Rectangle {
                required property int index
                readonly property real level: root.bands[index] ?? 0
                readonly property real barStep: (plot.sideways ? plot.height : plot.width) / Theme.mediaVisualizerPoints
                readonly property real size: Math.max(2, level * (plot.sideways ? plot.width : plot.amplitude * 2))
                x: plot.sideways ? (root.effect === "bars_right" ? plot.width - size : 0) : index * barStep + 1
                y: plot.sideways ? index * barStep + 1 : root.effect === "bars_top" ? 0
                    : root.effect === "mirror" ? plot.middle - size / 2 : plot.height - size
                width: plot.sideways ? size : Math.max(1, barStep - 2)
                height: plot.sideways ? Math.max(1, barStep - 2) : size
                color: Theme.accent
                opacity: 0.35 + level * 0.65
            }
        }
    }
    Loader {
        id: cavaRenderer
        objectName: "mediaCavaRenderer"
        anchors.fill: parent
        active: root.rendering && !!root.cavaPreset
        sourceComponent: Component {
            MediaCavaShader {
                preset: root.cavaPreset
                bands: root.bands
                active: root.rendering
                playing: root.playing
            }
        }
    }
}
