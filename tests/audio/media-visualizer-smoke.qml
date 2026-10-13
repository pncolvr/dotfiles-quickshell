pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQml.Models
import QtTest as Test
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../src/modules/system/audio"
import "../../src/services"

Scope {
    id: root
    property bool failed: false
    property int step: 0
    property real cardHeight: 0
    property int styleIndex: 0
    property bool reviewingStyle: false
    property bool checkedLastPreset: false
    readonly property bool nativeAudio: Quickshell.env("MEDIA_VISUALIZER_NATIVE") === "1"
    // Quickshell's UntypedObjectModel metadata omits the runtime values property.
    // qmllint disable missing-property
    readonly property var streams: Pipewire.nodes.values.filter(node => node.name === "visualizer-test")
    // qmllint enable missing-property
    Test.TestEvent { id: events }
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
            const selector = root.find(card, "mediaEffectSelector") as AudioSelector;
            const flip = root.find(card, "mediaFlip") as AudioButton;
            const back = root.find(card, "mediaFlipBack") as AudioButton;
            // Wait for the rendered animation rather than assuming a fixed number of timer ticks.
            if ([2, 8, 10, 12, 14].includes(root.step) && card.flipping) return;
            if (root.step === 0) {
                root.check(!flip.visible && !root.find(card, "mediaMute").visible
                    && !root.find(card, "mediaVolume").visible && !root.find(card, "mediaVolumeValue").visible,
                    "unmatched streams hide flip and all volume controls");
                audio.matched = true;
                root.check(flip.visible && root.find(card, "mediaMute").visible
                    && root.find(card, "mediaVolume").visible && root.find(card, "mediaVolumeValue").visible,
                    "matching streams reveal flip and volume controls");
                root.cardHeight = card.implicitHeight;
                root.check(!card.flipped && !visualizer.active && !visualizer.sampling, "front does not capture audio");
                root.check(flip.width === back.width && flip.height === back.height, "both flip buttons share dimensions and styling");
                root.check(!flip.label && !back.label && !!flip.hint && !!back.hint, "flip buttons use accessible icons without text");
                if (Quickshell.env("MEDIA_VISUALIZER_FRONT"))
                    card.grabToImage(result => result.saveToFile(Quickshell.env("MEDIA_VISUALIZER_FRONT")));
                events.mouseClick(flip, flip.width / 2, flip.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                root.check(card.flipped && card.flipping && !visualizer.active, "right-to-left flip delays monitoring until it finishes");
                card.flip();
                root.check(card.flipped, "repeated clicks do not interrupt the flip");
            } else if (root.step === 2) {
                root.check(card.flipped && !card.flipping && visualizer.active, "reverse face activates after the animation");
                root.check(root.find(card, "mediaBack").enabled && !root.find(card, "mediaFront").enabled, "reverse face accepts input after the flip");
                root.check(card.implicitHeight === root.cardHeight && visualizer.height > 30, "flip preserves card size with space for the visualization");
                root.check(visualizer.hasStreams === root.nativeAudio && visualizer.capturing === root.nativeAudio, "only the associated live stream is captured");
                const toggle = root.find(card, "mediaEffectToggle") as Item;
                const cursor = root.find(card, "mediaEffectToggleCursor") as MouseArea;
                root.check(cursor.width === toggle.width && cursor.height === toggle.height
                    && cursor.acceptedButtons === Qt.NoButton && cursor.cursorShape === Qt.PointingHandCursor,
                    "selector cursor covers the entire button and lets clicks through");
                root.check(root.find(visualizer, "mediaVisualizerPlot").visible, "native visualizer geometry is visible on the reverse face");
                if (Quickshell.env("MEDIA_VISUALIZER_GPU") === "1") {
                    const wave = root.find(visualizer, "mediaVisualizerWave") as Shape;
                    root.check(wave.rendererType === Shape.CurveRenderer, "wave rendering uses the GPU curve renderer");
                }
                if (!root.nativeAudio) {
                    root.check(root.find(card, "mediaVisualizerStatus").text === "Audio stream unavailable", "missing association is explicit");
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
                root.find(card, "mediaEffectToggle").clicked();
                root.check(selector.expanded && card.implicitHeight === root.cardHeight, "effect choices overlay without resizing the card");
            } else if (root.step === 3) {
                const choices = root.find(card, "mediaEffectChoices") as ListView;
                events.mouseClick(choices.itemAtIndex(1), 30, 10, Qt.LeftButton, Qt.NoModifier, 0);
                root.check(visualizer.effect === "bars" && !selector.expanded, "effect combo selects Bars and closes");
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
                }
                if (Quickshell.env("MEDIA_VISUALIZER_BACK"))
                    card.grabToImage(result => result.saveToFile(Quickshell.env("MEDIA_VISUALIZER_BACK")));
            } else if (root.step === 6) {
                fixturePlayer.isPlaying = false;
                root.check(!visualizer.capturing && !visualizer.sampling, "pause stops capture and sampling");
                fixturePlayer.isPlaying = true;
                card.monitorPosition = false;
                root.check(!visualizer.active && !visualizer.sampling, "cards outside the viewport stop monitoring");
                card.monitorPosition = true;
                preview.visible = false;
                root.check(!visualizer.active && !visualizer.sampling, "hidden windows stop monitoring");
                preview.visible = true;
                root.check(visualizer.active, "showing the window resumes the reverse face");
                back.clicked();
                root.check(!card.flipped && card.flipping && !visualizer.active, "left-to-right return stops monitoring immediately");
            } else if (root.step === 7) {
                if (root.nativeAudio) {
                    const workers = root.find(visualizer, "mediaSpectrumWorkers") as Instantiator;
                    root.check(workers.count === 1 && !(workers.objectAt(0) as Process).running,
                        "native analyzer process exits after the card flips back");
                }
            } else if (root.step === 8) {
                root.check(!card.flipping && root.find(card, "mediaFront").enabled && !visualizer.sampling, "return finishes on the playback face");
                root.check(!root.find(visualizer, "mediaVisualizerPlot").visible, "hidden visualizer geometry stops rendering");
                root.check(visualizer.effect === "ribbon" && card.implicitHeight === root.cardHeight, "effect selection and size survive the flip");
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
                root.find(card, "mediaEffectToggle").clicked();
                const choices = root.find(card, "mediaEffectChoices") as ListView;
                choices.positionViewAtIndex(visualizer.effects.length - 1, ListView.End);
                choices.forceLayout();
            } else if (root.step === 15) {
                if (!root.checkedLastPreset) {
                    const choices = root.find(card, "mediaEffectChoices") as ListView;
                    const lastChoice = choices.itemAtIndex(visualizer.effects.length - 1);
                    events.mouseClick(lastChoice, 30, 10, Qt.LeftButton, Qt.NoModifier, 0);
                    root.check(visualizer.effect === "cava_spectrogram" && !selector.expanded,
                        "the last preset is reachable by scrolling and clicking the combo");
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
                root.check(!(root.find(visualizer, "mediaCavaRenderer") as Loader).active,
                    "flipping back releases shader and feedback textures");
                console.log(root.failed ? "VISUALIZER FAIL: checks" : "PASS: media flip, effects and audio lifecycle");
                Qt.quit();
            }
            root.step++;
        }
    }
}
