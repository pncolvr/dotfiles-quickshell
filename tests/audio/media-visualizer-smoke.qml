pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQuick.Controls as QC
import QtQml.Models
import QtTest as Test
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../src/modules/system/audio"
import "../../src/services"

WorkerScope {
    id: root
    property bool failed: false
    property int step: 0
    property real cardHeight: 0
    property int styleIndex: 0
    property bool reviewingStyle: false
    property bool checkedLastPreset: false
    property int mutePhase: 0
    property int edgeProbe: 0
    readonly property bool nativeAudio: Quickshell.env("MEDIA_VISUALIZER_NATIVE") === "1"
    // Quickshell's UntypedObjectModel metadata omits the runtime values property.
    // qmllint disable missing-property
    readonly property var streams: Pipewire.nodes.values.filter(node => node.name === "visualizer-test")
    // qmllint enable missing-property
    Test.TestEvent { id: events }
    Test.TestResult { id: objects }
    PwObjectTracker { objects: root.nativeAudio ? root.streams : [] }
    function check(value, message) {
        if (!value) { failed = true; console.error("VISUALIZER FAIL: " + message); }
    }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.data ?? item.children ?? []) {
            const result = find(child, name);
            if (result) return result;
        }
        return null;
    }
    function checkRenderedLayer(name) {
        if (Quickshell.env("MEDIA_VISUALIZER_GPU") !== "1") return;
        const layer = root.find(card, name) as Item;
        const snapshot = objects.grabImage(layer);
        // QtTest's snapshot methods are not described in its qmltypes.
        // qmllint disable missing-property
        root.check(snapshot.alpha(Math.round(snapshot.width * 0.16), Math.round(snapshot.height * 0.4)) > 0,
            "native visualizer produces pixels in " + name);
        // qmllint enable missing-property
    }
    function checkIdle(reason) {
        const visualizer = root.find(card, "mediaVisualizer") as MediaVisualizer;
        const texture = root.find(card, "mediaVisualizerTexture") as ShaderEffectSource;
        const frontLayer = root.find(card, "mediaFrontVisualizer") as MediaCardVisualizer;
        const backLayer = root.find(card, "mediaBackVisualizer") as MediaCardVisualizer;
        const shader = root.find(visualizer, "mediaCavaRenderer") as Loader;
        root.check(!visualizer.rendering && !visualizer.capturing && !texture.live && !texture.sourceItem
            && !frontLayer.active && !backLayer.active && !frontLayer.item && !backLayer.item
            && !shader.active && !shader.item && root.find(visualizer, "mediaVisualizerPlot").outline.length === 0,
            reason + " stops analysis, texture updates, geometry and both face renderers");
    }
    function clickEffectText(choices, index, message) {
        const option = choices.itemAtIndex(index) as QC.ItemDelegate;
        const label = option.contentItem;
        const point = label.mapToItem(choices, label.width / 2, label.height / 2);
        root.check(point.y > 0 && point.y < choices.height, message + " text is visible");
        events.mouseMove(label, label.width / 2, label.height / 2, 0, Qt.NoButton, Qt.NoModifier);
        root.check(option.hovered, message + " text highlights the row");
        events.mouseClick(label, label.width / 2, label.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
        const visualizer = root.find(card, "mediaVisualizer") as MediaVisualizer;
        root.check(visualizer.effect === visualizer.effects[index].name, message + " text selects the effect");
    }
    QtObject {
        id: fixturePlayer
        property string identity: "Banana"
        property string desktopEntry: "banana"
        property string dbusName: "org.mpris.MediaPlayer2.banana"
        property string trackTitle: "Live audio visualization"
        property string trackArtist: "Test artist"
        property string trackArtUrl: Quickshell.env("MEDIA_VISUALIZER_ART") ? "file://" + Quickshell.env("MEDIA_VISUALIZER_ART") : ""
        property bool isPlaying: true
        property bool canControl: false
        property bool canPlay: false
        property bool canPause: false
        property bool canGoNext: false
        property bool canGoPrevious: false
        property bool canSeek: false
        property bool positionSupported: false
        property bool lengthSupported: false
        property bool volumeSupported: false
        property real volume: 1
        property real length: 0
        property real position: 0
        property int playbackState: 0
        signal trackChanged()
    }
    QtObject { id: mockAudio; property real volume: 1; property bool muted: false }
    QtObject {
        id: mockStream
        property bool ready: true
        property var audio: mockAudio
        property var properties: ({"application.id": "banana"})
    }
    QtObject {
        id: audio
        property bool matched: false
        readonly property var playbackApps: matched ? [{nodes: root.nativeAudio ? root.streams : [mockStream]}] : []
        function appVolume(app) { return app.nodes[0]?.audio?.volume ?? 1; }
        function appMuted(app) { return app.nodes.every(node => node.audio?.muted); }
    }
    QtObject {
        id: media
        function appForPlayer(value, apps) { return MediaService.appForPlayer(value, apps, [fixturePlayer]); }
        function volumeSupported(value) { return MediaService.volumeSupported(value); }
        function positionCommand(value) { return []; }
    }
    FloatingWindow {
        id: preview
        visible: true
        implicitWidth: 550
        implicitHeight: card.implicitHeight
        minimumSize: Qt.size(implicitWidth, implicitHeight)
        maximumSize: minimumSize
        MediaPlayerCard {
            id: card
            anchors.fill: parent
            player: fixturePlayer
            audioService: audio
            mediaService: media
        }
    }
    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            const visualizer = root.find(card, "mediaVisualizer") as MediaVisualizer;
            const selector = root.find(card, "mediaEffectSelector") as MediaEffectList;
            const flip = root.find(card, "mediaFlip") as AudioButton;
            const back = root.find(card, "mediaFlipBack") as AudioButton;
            // Wait for the rendered animation rather than assuming a fixed number of timer ticks.
            if ([2, 8, 10, 12, 14].includes(root.step) && card.flipping) return;
            if (root.step === 0) {
                root.check(visualizer.appId === "banana", "effect preferences use the app's desktop identity");
                fixturePlayer.desktopEntry = "BANANA.desktop";
                fixturePlayer.dbusName = "org.mpris.MediaPlayer2.banana.instance42";
                root.check(visualizer.appId === "banana", "case, desktop suffixes and player instance IDs keep the same preference key");
                root.check(!flip.visible && !root.find(card, "mediaMute").visible
                    && !root.find(card, "mediaVolume").visible && !root.find(card, "mediaVolumeValue").visible,
                    "unmatched streams hide flip and all volume controls");
                audio.matched = true;
                root.check(flip.visible && root.find(card, "mediaMute").visible
                    && root.find(card, "mediaVolume").visible && root.find(card, "mediaVolumeValue").visible,
                    "matching streams reveal flip and volume controls");
                root.cardHeight = card.implicitHeight;
                root.check(!card.flipped && visualizer.active && visualizer.capturing === root.nativeAudio,
                    "matched playback face activates the shared visualizer");
                const frontLayer = root.find(card, "mediaFrontVisualizer") as MediaCardVisualizer;
                const backLayer = root.find(card, "mediaBackVisualizer") as MediaCardVisualizer;
                root.check(frontLayer.active && !backLayer.active && frontLayer.textureSource === backLayer.textureSource,
                    "both faces share one renderer, with only the visible layer active");
                root.check(visualizer.width === card.width - 2 && visualizer.height === card.height - 2
                    && frontLayer.width === visualizer.width && backLayer.height === visualizer.height,
                    "visualizer fills the card inside its border on both faces");
                root.check(flip.width === back.width && flip.height === back.height, "both flip buttons share dimensions and styling");
                root.check(!flip.label && !back.label && !!flip.hint && !!back.hint, "flip buttons use accessible icons without text");
            } else if (root.step === 1) {
                // Allow the action row to lay out the newly revealed Flip button before clicking it.
                root.cardHeight = card.implicitHeight;
                events.mouseClick(flip, flip.width / 2, flip.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                root.check(card.flipped && card.flipping && !visualizer.active, "right-to-left flip delays monitoring until it finishes");
                card.flip();
                root.check(card.flipped, "repeated clicks do not interrupt the flip");
            } else if (root.step === 2) {
                root.check(card.flipped && !card.flipping && visualizer.active, "reverse face activates after the animation");
                root.check(root.find(card, "mediaBack").enabled && !root.find(card, "mediaFront").enabled, "reverse face accepts input after the flip");
                root.check(card.implicitHeight === root.cardHeight && visualizer.height > 30, "flip preserves card size with space for the visualization");
                root.check(visualizer.hasStreams === root.nativeAudio && visualizer.capturing === root.nativeAudio, "only the associated live stream is captured");
                root.check(selector.view.visible && selector.view.clip && selector.view.count === visualizer.effects.length,
                    "all visualizers are available in an always-visible scrolling list");
                root.check(root.find(visualizer, "mediaVisualizerPlot").outline.length > 0
                    && root.find(card, "mediaBackVisualizer").active, "native geometry feeds the reverse-face background");
                if (Quickshell.env("MEDIA_VISUALIZER_GPU") === "1") {
                    const wave = root.find(visualizer, "mediaVisualizerWave") as Shape;
                    root.check(wave.rendererType === Shape.CurveRenderer, "wave rendering uses the GPU curve renderer");
                }
                if (!root.nativeAudio) {
                    const bass = Array(64).fill(0); bass[10] = 0.8;
                    visualizer.bands = bass;
                    const plot = root.find(visualizer, "mediaVisualizerPlot");
                    const first = plot.outline.slice();
                    const treble = Array(64).fill(0); treble[45] = 0.6;
                    visualizer.bands = treble;
                    const second = plot.outline;
                    root.check(first.length === second.length && first.every((point, index) => point.x === second[index].x),
                        "frequency changes preserve the bands' horizontal positions");
                    root.check(first[10].y < second[10].y && second[45].y < first[45].y,
                        "bass and treble bands react independently");
                    root.check(visualizer.parseFrame("broken frame") === null, "malformed spectrum frames are ignored");
                    root.check(visualizer.parseFrame(Array(64).fill("500").join(";")).every(value => value === 0.5),
                        "native frames decode to normalized band values");
                    visualizer.bands = Array.from({length: 64}, (_, index) => Math.max(0, Math.sin(index / 4) * Math.exp(-index / 35)));
                }
                root.check(card.implicitHeight === root.cardHeight, "effect list does not resize the card");
            } else if (root.step === 3) {
                const choices = root.find(card, "mediaEffectChoices") as ListView;
                if (root.edgeProbe === 0) {
                    choices.contentY = selector.rowHeight / 3;
                    choices.forceLayout();
                    root.edgeProbe++;
                    return;
                }
                if (root.edgeProbe === 1) {
                    root.clickEffectText(choices, 0, "Partially visible first row");
                    root.edgeProbe++;
                    return;
                }
                if (root.edgeProbe === 2) {
                    // Keep the last visible row's label inside the viewport with its bottom clipped.
                    choices.contentY = selector.rowHeight * 6 - choices.height + selector.rowHeight * 0.75;
                    choices.forceLayout();
                    root.edgeProbe++;
                    return;
                }
                if (root.edgeProbe === 3) {
                    root.clickEffectText(choices, 6, "Partially visible last row");
                    root.edgeProbe++;
                    return;
                }
                if (root.edgeProbe === 4) {
                    choices.positionViewAtIndex(1, ListView.Beginning);
                    choices.forceLayout();
                    root.edgeProbe++;
                    return;
                }
                const option = choices.itemAtIndex(1) as QC.ItemDelegate;
                events.mouseMove(option, 30, 10, 0, Qt.NoButton, Qt.NoModifier);
                root.check((option.background as Rectangle).color.a === 1,
                    "hovered combo rows have an opaque background");
                events.mouseClick(choices.itemAtIndex(1), 30, 10, Qt.LeftButton, Qt.NoModifier, 0);
                root.check(visualizer.effect === "bars" && selector.view.visible, "effect list selects Bars and stays visible");
                root.check(PreferencesRepository.value(visualizer.effectPreferenceKey, "") === "bars",
                    "combo selection saves the effect for this app");
            } else if (root.step === 4) {
                selector.selected("mirror");
                root.check(visualizer.effect === "mirror", "Mirror effect can be selected");
            } else if (root.step === 5) {
                selector.selected("ribbon");
                root.check(visualizer.effect === "ribbon", "Ribbon effect can be selected");
                if (root.nativeAudio) {
                    const bands = visualizer.bands;
                    const strongest = bands.indexOf(Math.max(...bands));
                    root.check(!visualizer.error && Math.max(...bands) > 0.01, "native PipeWire audio drives cavacore frequency bands");
                    root.check(strongest < 30 && Math.max(...bands.slice(40)) < Math.max(...bands) * 0.2,
                        "matched bass stream is isolated from the unrelated treble stream on the same sink");
                    const workers = root.find(visualizer, "mediaSpectrumWorkers") as Instantiator;
                    const worker = workers.objectAt(0) as MediaSpectrumWorker;
                    let frameChanges = 0;
                    let waveformChanges = 0;
                    const countFrame = () => frameChanges++;
                    const countWaveform = () => waveformChanges++;
                    worker.frameChanged.connect(countFrame);
                    worker.waveformChanged.connect(countWaveform);
                    worker.dataReceived(worker.frame.map(value => String(Math.round(value * 1000))).join(";")
                        + "|" + Array(64).fill("200").join(";"));
                    root.check(frameChanges === 0 && waveformChanges === 0,
                        "unchanged bands do not repaint and non-waveform styles skip PCM updates");
                    selector.selected("cava_spectrogram");
                    worker.dataReceived(worker.frame.map(value => String(Math.round(value * 1000))).join(";")
                        + "|" + Array(64).fill("200").join(";"));
                    root.check(frameChanges === 1 && waveformChanges === 0,
                        "spectrogram still advances its history for repeated frames");
                    selector.selected("ribbon");
                    worker.frameChanged.disconnect(countFrame);
                    worker.waveformChanged.disconnect(countWaveform);
                }
                if (Quickshell.env("MEDIA_VISUALIZER_BACK"))
                    card.grabToImage(result => result.saveToFile(Quickshell.env("MEDIA_VISUALIZER_BACK")));
            } else if (root.step === 6) {
                const channel = root.nativeAudio ? root.streams[0].audio : mockAudio;
                if (root.mutePhase === 0) {
                    root.checkRenderedLayer("mediaBackVisualizer");
                    fixturePlayer.isPlaying = false;
                    root.checkIdle("Pausing");
                    fixturePlayer.isPlaying = true;
                    channel.muted = true;
                    root.mutePhase = 1;
                    return;
                }
                if (root.mutePhase === 1) {
                    if (!card.muted) return;
                    root.checkIdle("Muting");
                    channel.muted = false;
                    root.mutePhase = 2;
                    return;
                }
                if (card.muted) return;
                card.monitorPosition = false;
                root.checkIdle("Leaving the viewport");
                card.monitorPosition = true;
                preview.visible = false;
                root.checkIdle("Hiding the window");
                preview.visible = true;
                root.check(visualizer.active, "showing the window resumes the reverse face");
                back.clicked();
                root.check(!card.flipped && card.flipping && !visualizer.active, "left-to-right return stops monitoring immediately");
            } else if (root.step === 7) {
                if (root.nativeAudio) {
                    const workers = root.find(visualizer, "mediaSpectrumWorkers") as Instantiator;
                    root.check(workers.count === 1 && !(workers.objectAt(0) as Process).running,
                        "native analyzer process exits during the flip animation");
                }
            } else if (root.step === 8) {
                root.check(!card.flipping && root.find(card, "mediaFront").enabled && visualizer.active
                    && visualizer.sampling === root.nativeAudio, "return resumes visualization on the playback face");
                root.check(root.find(visualizer, "mediaVisualizerPlot").outline.length > 0
                    && root.find(card, "mediaFrontVisualizer").active && !root.find(card, "mediaBackVisualizer").active,
                    "front layer renders below playback content while the reverse layer stops");
                root.check(visualizer.effect === "ribbon" && card.implicitHeight === root.cardHeight, "effect selection and size survive the flip");
                if (Quickshell.env("MEDIA_VISUALIZER_FRONT"))
                    card.grabToImage(result => result.saveToFile(Quickshell.env("MEDIA_VISUALIZER_FRONT")));
            } else if (root.step === 9) {
                root.checkRenderedLayer("mediaFrontVisualizer");
                card.flip();
            } else if (root.step === 10) {
                root.check(card.flipped && !card.flipping, "visualizer can be reopened");
                if (root.nativeAudio) {
                    const workers = root.find(visualizer, "mediaSpectrumWorkers") as Instantiator;
                    root.check(workers.count === 1 && (workers.objectAt(0) as Process).running,
                        "native analyzer restarts when the reverse face is reopened");
                }
                audio.matched = false;
                root.check(!card.flipped && !visualizer.active && !flip.visible, "losing the stream returns to playback and hides flip");
            } else if (root.step === 12) {
                root.check(!card.flipping && !root.find(card, "mediaMute").visible
                    && !root.find(card, "mediaVolume").visible && !root.find(card, "mediaVolumeValue").visible,
                    "stream loss hides all volume controls");
                if (root.nativeAudio)
                    root.check(visualizer.waveform.length === 64, "native waveform carries bounded PCM samples");
                audio.matched = true;
                card.flip();
            } else if (root.step === 14) {
                root.check(visualizer.effects.length === 17 && visualizer.effects.filter(option => !!option.shader).length === 9,
                    "combo exposes all nine CAVA 1.0.0 shader presets, classic orientations and waveform");
                if (!root.nativeAudio) visualizer.waveform = Array.from({length: 64}, (_, index) => Math.sin(index / 5) * 0.6);
                const choices = root.find(card, "mediaEffectChoices") as ListView;
                choices.positionViewAtIndex(visualizer.effects.length - 1, ListView.End);
                choices.forceLayout();
            } else if (root.step === 15) {
                if (!root.checkedLastPreset) {
                    const choices = root.find(card, "mediaEffectChoices") as ListView;
                    root.clickEffectText(choices, visualizer.effects.length - 1, "Final preset");
                    root.check(visualizer.effect === "cava_spectrogram" && selector.view.visible,
                        "the last preset is reachable by scrolling and clicking the list");
                    root.checkedLastPreset = true;
                    return;
                }
                const option = visualizer.effects[root.styleIndex];
                if (option) {
                    if (!root.reviewingStyle) {
                        selector.selected(option.name);
                        root.reviewingStyle = true;
                        return;
                    }
                    root.check(visualizer.effect === option.name && selector.selectedName === option.name,
                        "combo selects " + option.description);
                    root.check(card.implicitHeight === root.cardHeight, "style selection preserves the card size");
                    const renderer = root.find(visualizer, "mediaCavaRenderer") as Loader;
                    if (option.shader) {
                        root.check(renderer.active && !!renderer.item, "shader preset loads: " + option.description);
                        if (Quickshell.env("MEDIA_VISUALIZER_GPU") === "1") {
                            const shader = renderer.item as MediaCavaShader;
                            root.check(shader.status === ShaderEffect.Compiled, "GPU shader compiles: " + option.description);
                            shader.playing = false;
                            root.check(!shader.animating, "pause stops shader time: " + option.description);
                            shader.playing = Qt.binding(() => visualizer.playing);
                        }
                    } else root.check(!renderer.active, "native style releases the shader renderer");
                    if (Quickshell.env("MEDIA_VISUALIZER_STYLE_DIR")) {
                        const destination = Quickshell.env("MEDIA_VISUALIZER_STYLE_DIR") + "/" + option.name + ".png";
                        card.grabToImage(result => result.saveToFile(destination));
                    }
                    root.styleIndex++;
                    root.reviewingStyle = false;
                    return;
                }
                back.clicked();
            } else if (root.step === 17) {
                root.check((root.find(visualizer, "mediaCavaRenderer") as Loader).active
                    && root.find(card, "mediaFrontVisualizer").active && !root.find(card, "mediaBackVisualizer").active,
                    "selected shader renders behind the playback face after flipping back");
                root.check(root.find(visualizer, "mediaVisualizerPlot").outline.length === 0,
                    "shader presets do not compute unused native geometry");
                fixturePlayer.isPlaying = false;
                root.checkIdle("Pausing a shader preset");
                fixturePlayer.isPlaying = true;
                card.opacity = 0;
                root.checkIdle("A transparent card");
                card.opacity = 1;
                card.visible = false;
                root.checkIdle("Hiding a card");
                card.visible = true;
                console.log(root.failed ? "VISUALIZER FAIL: checks" : "PASS: media flip, effects and audio lifecycle");
                Qt.quit();
            }
            root.step++;
        }
    }
}
