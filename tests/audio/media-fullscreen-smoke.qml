pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import "../../src/theme"
import "../../src/modules/system/audio"
import "../../src/services"

Scope {
    id: root
    property bool failed: false
    property int step: 0
    property var activeCard: null
    readonly property var inputMask: fullscreen.mask
    property int styleIndex: 0
    property int shaderCheckPhase: 0
    property int renderedFrames: 0
    property int framesBeforeUpdate: 0
    property string emptyMiddlePixel: ""
    property string emptyTopPixel: ""
    onStepChanged: if (Quickshell.env("MEDIA_FULLSCREEN_TRACE") === "1") console.log("FULLSCREEN STEP: " + step)
    property bool sawOpening: false
    property bool sawClosing: false
    property bool cancelNextOpening: false
    property bool canceledOpening: false
    property bool sawNextSlide: false
    property bool sawPreviousSlide: false
    property bool cancelNextSlide: false
    property bool canceledSlide: false
    Test.TestEvent { id: events }
    Test.TestResult { id: images }
    Connections {
        target: fullscreen.card?.Window.window ?? null
        function onFrameSwapped() { root.renderedFrames++; }
    }
    function check(value, message) {
        if (!value) { failed = true; console.error("FULLSCREEN FAIL: " + message); }
    }
    function find(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (const child of item.data ?? item.children ?? []) {
            const result = find(child, name);
            if (result) return result;
        }
        return null;
    }
    component Player: QtObject {
        property string identity: "Fullscreen test"
        property string desktopEntry: "fullscreen-test"
        property string trackTitle: "Fullscreen media"
        property string trackArtist: "Test artist"
        property string trackArtUrl: "file://" + Quickshell.env("MEDIA_FULLSCREEN_ART")
        property bool isPlaying: true
        property int playbackState: 1
        property bool canPlay: true
        property bool canPause: true
        property bool canControl: false
        property bool canGoNext: false
        property bool canGoPrevious: false
        property bool canSeek: true
        property bool positionSupported: true
        property bool lengthSupported: true
        property real length: 240
        property real position: 65
        signal trackChanged()
        function pause() { isPlaying = false; }
        function play() { isPlaying = true; }
    }
    Player { id: fixturePlayer }
    Player {
        id: secondPlayer
        identity: "Second player"
        desktopEntry: "fullscreen-second"
        trackTitle: "Another track"
        trackArtist: "Another artist"
    }
    Player {
        id: unavailablePlayer
        identity: "Stopped player"
        desktopEntry: "fullscreen-unavailable"
        canPlay: false
        isPlaying: false
        playbackState: MprisPlaybackState.Stopped
    }
    QtObject { id: streamAudio; property bool muted: false; property real volume: 1 }
    QtObject { id: secondAudio; property bool muted: false; property real volume: 0.8 }
    QtObject {
        id: stream
        property bool ready: true
        property var audio: streamAudio
        property var properties: ({"application.id": "fullscreen-test"})
    }
    QtObject {
        id: secondStream
        property bool ready: true
        property var audio: secondAudio
        property var properties: ({"application.id": "fullscreen-second"})
    }
    QtObject {
        id: audio
        property var playbackApps: [{nodes: [stream]}, {nodes: [secondStream]}]
        function appVolume(app) { return app.nodes[0].audio.volume; }
        function appMuted(app) { return app.nodes[0].audio.muted; }
        function toggleAppMute(app, input) { app.nodes[0].audio.muted = !app.nodes[0].audio.muted; }
        function setAppVolume(app, volume) { app.nodes[0].audio.volume = volume; }
    }
    QtObject {
        id: media
        property var players: [fixturePlayer, secondPlayer, unavailablePlayer]
        function appForPlayer(value, apps) { return MediaService.appForPlayer(value, apps, players); }
        function positionCommand(value) { return []; }
    }
    FloatingWindow {
        id: preview
        visible: true
        implicitWidth: 550
        implicitHeight: compactCard.implicitHeight
        MediaPlayerCard {
            id: compactCard
            anchors.fill: parent
            player: fixturePlayer
            audioService: audio
            mediaService: media
        }
    }
    MediaFullscreenWindow { id: fullscreen }
    Timer {
        interval: 40
        running: fullscreen.visible
        repeat: true
        onTriggered: {
            if (fullscreen.slidingPlayer && fullscreen.card) {
                if (fullscreen.playerSlideDirection > 0) root.sawNextSlide = true;
                else root.sawPreviousSlide = true;
                const camera = root.find(fullscreen.contentItem, "mediaFullscreenCamera") as Item;
                const incoming = root.find(camera, "mediaFullscreenIncoming") as Item;
                const outgoing = root.find(camera, "mediaFullscreenOutgoing") as Item;
                const incomingX = incoming.mapToItem(camera, 0, 0).x;
                const outgoingX = outgoing.mapToItem(camera, 0, 0).x;
                root.check(Math.abs(incomingX - fullscreen.playerSlideDirection * fullscreen.width
                    * (1 - fullscreen.playerSlideProgress)) < 1
                    && Math.abs(outgoingX + fullscreen.playerSlideDirection * fullscreen.width * fullscreen.playerSlideProgress) < 1,
                    "both views slide horizontally in the requested direction");
                root.check(!!fullscreen.previousCardSnapshot && !fullscreen.card.monitorPosition
                    && !root.find(fullscreen.card, "mediaVisualizer").rendering,
                    "the outgoing view is frozen and audio rendering pauses during switching");
                root.check(root.find(fullscreen.contentItem, "mediaFullscreenExit").enabled,
                    "exit stays enabled while switching players");
                if (root.cancelNextSlide) {
                    root.cancelNextSlide = false;
                    root.canceledSlide = true;
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0);
                }
            }
            if (fullscreen.transitionProgress <= 0 || fullscreen.transitionProgress >= 1 || !fullscreen.card) return;
            if (MediaFullscreenService.requested) root.sawOpening = true;
            else root.sawClosing = true;
            root.check(!fullscreen.card.monitorPosition && !root.find(fullscreen.card, "mediaVisualizer").rendering,
                "zoom pauses audio rendering and position polling");
            const camera = root.find(fullscreen.contentItem, "mediaFullscreenCamera") as Item;
            const origin = camera.mapToItem(fullscreen.contentItem, 0, 0);
            const corner = camera.mapToItem(fullscreen.contentItem, camera.width, camera.height);
            root.check(Math.abs(origin.x - fullscreen.transitionRect.x) < 1
                && Math.abs(origin.y - fullscreen.transitionRect.y) < 1
                && Math.abs(corner.x - origin.x - fullscreen.transitionRect.width) < 1
                && Math.abs(corner.y - origin.y - fullscreen.transitionRect.height) < 1,
                "zoom applies the actual card bounds");
            if (root.cancelNextOpening && MediaFullscreenService.requested) {
                root.cancelNextOpening = false;
                root.canceledOpening = true;
                const exit = root.find(fullscreen.contentItem, "mediaFullscreenExit") as Item;
                events.mouseClick(exit, exit.width / 2, exit.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
            }
        }
    }
    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            const visualizer = root.find(compactCard, "mediaVisualizer") as MediaVisualizer;
            const card = fullscreen.card;
            if ([2, 10, 12, 14, 19, 21].includes(root.step)
                && (!MediaFullscreenService.requested || fullscreen.transitionProgress < 1)) return;
            if ([9, 11, 13, 15, 18, 20, 22].includes(root.step) && MediaFullscreenService.visible) return;
            if (root.step === 18 && root.cancelNextOpening) return;
            if ([9, 11, 13, 15, 18, 20].includes(root.step) && compactCard.flipping) return;
            if ([3, 4, 5, 6].includes(root.step) && fullscreen.switchingPlayer) return;
            if (root.step === 22 && root.cancelNextSlide) return;
            if (root.step === 0) {
                visualizer.selectEffect("bars");
                compactCard.flip();
            } else if (root.step === 1) {
                if (compactCard.flipping) return;
                compactCard.toggleFullscreen();
            } else if (root.step === 2) {
                root.activeCard = card;
                const screen = fullscreen.geometryScreen
                root.check(!!card && card.width === screen.width && card.height === screen.height,
                    "one player fills the originating monitor");
                root.check(!root.find(card, "mediaFlip") && !root.find(card, "mediaFlipBack"),
                    "fullscreen has one face and no flip controls");
                root.check(fullscreen.color.a === 1 && card.color.a === 1, "fullscreen stays opaque");
                root.check(!root.find(fullscreen.contentItem, "mediaFullscreenExit").label,
                    "exit is an icon outside the animated view");
                const controls = root.find(card, "mediaPlaybackRow") as Item;
                root.check(Math.abs(controls.x - card.width * 0.02) < 1
                    && Math.abs(card.width - controls.x - controls.width - card.width * 0.02) < 1
                    && Math.abs(card.height - controls.y - controls.height - card.height * 0.02) < 1,
                    "bottom controls span the width with two-percent left, right and bottom margins");
                const fullVisualizer = root.find(card, "mediaVisualizer") as MediaVisualizer;
                root.check(fullVisualizer.width === card.width && fullVisualizer.height === card.height
                    && !root.find(card, "mediaVisualizerTexture"),
                    "the live visualizer renders directly at full resolution without an upscaled texture");
                const background = root.find(card, "mediaFullscreenBackgroundTexture") as ShaderEffectSource;
                root.check(background.textureSize.width <= Theme.mediaFullscreenCacheWidth
                    && background.textureSize.height <= Theme.mediaFullscreenCacheHeight,
                    "only the cached blurred background uses the smaller render budget");
                root.check(!visualizer.rendering && fullVisualizer.rendering
                    && !root.find(card, "mediaFrontVisualizer") && !root.find(card, "mediaBackVisualizer"),
                    "only the selected player renders, without fullscreen face masks");
                root.check(!root.find(card, "mediaFullscreenBackgroundTexture").live,
                    "blurred artwork is cached rather than rendered each frame");
                root.check(!!root.find(card, "mediaFullscreenBackgroundTexture").sourceItem,
                    "cached artwork has loaded into its background texture");
                const effects = root.find(card, "mediaEffectSelector") as MediaEffectList;
                root.check(effects.view.visible && effects.view.count === 17 && effects.view.clip,
                    "all effects are available in a permanent scrollable list");
                const row = effects.view.itemAtIndex(1);
                events.mouseMove(row, row.width - 10, row.height / 2, 0, Qt.NoButton, Qt.NoModifier);
                root.check(((row as QC.ItemDelegate).background as Rectangle).color.a === 1, "hovered rows remain opaque across the whole row");
                events.mouseClick(row, 20, row.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                root.check(fullVisualizer.effect === "bars", "clicking the effect list saves the app effect");
                fullVisualizer.selectEffect("cava_orion_rotate");
                card.player.pause();
                root.check(!fullVisualizer.rendering && !root.find(fullVisualizer, "mediaCavaRenderer").active,
                    "pause stops the native-resolution renderer");
                card.player.play();
                events.keyClick(Qt.Key_Right, Qt.NoModifier, 0);
                events.keyClick(Qt.Key_Right, Qt.NoModifier, 0);
            } else if (root.step === 3) {
                root.check(card === root.activeCard && card.player === secondPlayer
                    && root.find(card, "mediaTitle").text === secondPlayer.trackTitle
                    && root.find(card, "mediaVisualizer").nodes[0] === secondStream,
                    "Right changes metadata and audio in the same single view");
                root.find(card, "mediaVisualizer").selectEffect("mirror");
                events.keyClick(Qt.Key_Left, Qt.NoModifier, 0);
            } else if (root.step === 4) {
                root.check(card.player === fixturePlayer && root.find(card, "mediaVisualizer").effect === "cava_orion_rotate",
                    "Left restores the first app's saved effect");
                const effects = root.find(card, "mediaEffectSelector") as MediaEffectList;
                const selected = effects.view.itemAtIndex(effects.view.currentIndex);
                root.check(String(((selected as QC.ItemDelegate).background as Rectangle).color) === String(effects.color)
                    && String(((selected as QC.ItemDelegate).contentItem as Text).color) === String(Theme.accent),
                    "selection uses accent text without a colored background");
                root.find(card, "mediaPlayPause").clicked();
                root.check(!fixturePlayer.isPlaying, "fullscreen transport affects the same player");
                root.find(card, "mediaPlayPause").clicked();
                root.find(card, "mediaVolume").volumeMoved(0.4);
                root.check(streamAudio.volume === 0.4, "fullscreen volume targets the selected stream");
                root.find(card, "mediaMute").clicked();
                root.check(streamAudio.muted && !root.find(card, "mediaVisualizer").rendering, "mute stops rendering");
                root.find(card, "mediaMute").clicked();
                card.seekTo(120);
                root.check(fixturePlayer.position === 120, "fullscreen timeline seeks the selected player");
                events.keyClick(Qt.Key_Left, Qt.NoModifier, 0);
            } else if (root.step === 5) {
                root.check(card.player === secondPlayer, "navigation wraps at the first player");
                root.find(fullscreen.contentItem, "mediaFullscreenNextPlayer").clicked();
            } else if (root.step === 6) {
                root.check(card.player === fixturePlayer, "navigation buttons wrap at the last player");
                root.check(root.sawNextSlide && root.sawPreviousSlide && !fullscreen.previousCardSnapshot,
                    "both slide directions finish and release the outgoing snapshot");
                media.players = [fixturePlayer];
                root.check(!root.find(fullscreen.contentItem, "mediaFullscreenNavigation").visible,
                    "single-player view hides navigation");
                root.find(card, "mediaVisualizer").selectEffect("bars");
                if (Quickshell.env("MEDIA_FULLSCREEN_SCREENSHOT"))
                    card.grabToImage(result => result.saveToFile(Quickshell.env("MEDIA_FULLSCREEN_SCREENSHOT")));
            } else if (root.step === 7) {
                const fullVisualizer = root.find(card, "mediaVisualizer") as MediaVisualizer;
                if (root.shaderCheckPhase < 5) {
                    const renderer = root.find(fullVisualizer, "mediaCavaRenderer") as Loader;
                    const shader = renderer.item as MediaCavaShader;
                    if (root.shaderCheckPhase === 0) {
                        fullVisualizer.selectEffect("cava_bar_spectrum");
                        fullVisualizer.bands = Array(64).fill(0);
                    } else if (root.shaderCheckPhase === 1) {
                        shader.playing = false;
                        const snapshot = images.grabImage(fullVisualizer);
                        // QtTest's snapshot methods are not described in its qmltypes.
                        // qmllint disable missing-property
                        root.emptyMiddlePixel = String(snapshot.pixel(Math.round(snapshot.width * 0.9), Math.round(snapshot.height * 0.5)));
                        root.emptyTopPixel = String(snapshot.pixel(Math.round(snapshot.width * 0.9), Math.round(snapshot.height * 0.05)));
                        // qmllint enable missing-property
                        root.framesBeforeUpdate = root.renderedFrames;
                        fullVisualizer.bands = Array(64).fill(1);
                    } else if (root.shaderCheckPhase === 2) {
                        root.check(root.renderedFrames > root.framesBeforeUpdate,
                            "new audio levels request a GPU frame even without a running animation");
                        const snapshot = images.grabImage(fullVisualizer);
                        // QtTest's snapshot methods are not described in its qmltypes.
                        // qmllint disable missing-property
                        root.check(String(snapshot.pixel(Math.round(snapshot.width * 0.9), Math.round(snapshot.height * 0.5))) !== root.emptyMiddlePixel,
                            "new levels reach the shader band texture");
                        // qmllint enable missing-property
                        root.find(shader, "mediaCavaBandBlend").duration = 1000;
                        shader.playing = true;
                        fullVisualizer.bands = Array(64).fill(0);
                    } else if (root.shaderCheckPhase === 3) {
                        const snapshot = images.grabImage(fullVisualizer);
                        // qmllint disable missing-property
                        root.check(String(snapshot.pixel(Math.round(snapshot.width * 0.9), Math.round(snapshot.height * 0.5))) !== root.emptyMiddlePixel
                            && String(snapshot.pixel(Math.round(snapshot.width * 0.9), Math.round(snapshot.height * 0.05))) === root.emptyTopPixel,
                            "GPU pixels show intermediate audio levels between frames");
                        // qmllint enable missing-property
                        root.check(root.find(shader, "mediaCavaBandBlend").running,
                            "interpolation runs on the render thread between audio frames");
                        shader.playing = false;
                        root.check(!root.find(shader, "mediaCavaBandBlend").running,
                            "pausing stops band interpolation immediately");
                    } else {
                        root.find(shader, "mediaCavaBandBlend").duration = Theme.mediaVisualizerInterval;
                        shader.playing = Qt.binding(() => fullVisualizer.playing);
                    }
                    root.shaderCheckPhase++;
                    return;
                }
                const style = fullVisualizer.effects[root.styleIndex];
                if (style) {
                    fullVisualizer.selectEffect(style.name);
                    fullVisualizer.bands = Array.from({length: 64}, (_, index) => 0.2 + Math.sin(index / 7) * 0.15);
                    root.styleIndex++;
                    return;
                }
                root.find(card, "mediaEffectSelector").view.forceActiveFocus();
                events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0);
                root.check(!MediaFullscreenService.requested
                    && fullscreen.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None && root.inputMask.width === 0,
                    "Escape from the effect list immediately releases keyboard focus and pointer capture");
            } else if (root.step === 9) {
                root.check(!card && !MediaFullscreenService.snapshot && root.sawOpening && root.sawClosing,
                    "animated exit unloads all view and snapshot resources");
                compactCard.toggleFullscreen();
            } else if (root.step === 10) {
                root.find(card, "mediaVolume").forceActiveFocus();
                events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0);
                const animation = root.find(fullscreen.contentItem, "mediaFullscreenTransition");
                animation.stop();
                fullscreen.transitionProgress = 1;
                root.check(MediaFullscreenService.closing, "test holds the exit animation before completion");
            } else if (root.step === 11) {
                root.check(!card && !fullscreen.visible && !MediaFullscreenService.snapshot,
                    "exit deadline dismisses even a stalled animation");
                compactCard.toggleFullscreen();
            } else if (root.step === 12) {
                media.players = [];
            } else if (root.step === 13) {
                root.check(!card, "removing the player closes fullscreen");
                media.players = [fixturePlayer];
                compactCard.toggleFullscreen();
            } else if (root.step === 14) {
                audio.playbackApps = [];
                root.check(!root.find(card, "mediaMute").visible && !root.find(card, "mediaVolume").visible,
                    "unmatched players hide audio stream controls");
                root.find(fullscreen.contentItem, "mediaFullscreenExit").clicked();
            } else if (root.step === 15) {
                root.cancelNextOpening = true;
                compactCard.toggleFullscreen();
            } else if (root.step === 18) {
                root.check(root.canceledOpening && !card && !MediaFullscreenService.snapshot,
                    "exit button works during entry without waiting for the zoom");
                fullscreen.animationsEnabled = false;
                compactCard.toggleFullscreen();
            } else if (root.step === 19) {
                root.check(fullscreen.transitionProgress === 1 && !fullscreen.transitioning,
                    "disabled animations open directly");
                events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0);
            } else if (root.step === 20) {
                root.check(!card, "disabled animations clean up immediately");
                media.players = [fixturePlayer, secondPlayer];
                compactCard.toggleFullscreen();
            } else if (root.step === 21) {
                fullscreen.navigate(1);
                root.check(card.player === secondPlayer && !fullscreen.switchingPlayer && !fullscreen.previousCardSnapshot,
                    "disabled animations switch players directly without capturing a snapshot");
                fullscreen.animationsEnabled = true;
                root.cancelNextSlide = true;
                fullscreen.navigate(-1);
            } else if (root.step === 22) {
                root.check(root.canceledSlide && !card && !fullscreen.previousCardSnapshot,
                    "Escape cancels an active player slide and releases its snapshot");
                fullscreen.animationsEnabled = false;
                compactCard.toggleFullscreen();
            } else if (root.step === 23) {
                if (!MediaFullscreenService.requested || fullscreen.transitionProgress < 1) return;
                events.keyClick(Qt.Key_F4, Qt.AltModifier, 0);
            } else if (root.step === 24) {
                if (MediaFullscreenService.visible) return;
                root.check(!card && !fullscreen.visible, "Alt+F4 also exits independently of child focus");
                if (!root.failed) console.log("PASS: fullscreen native-resolution visualizers, accent-only selection, directional slides, opaque single view, player navigation, exit during slides and stalled-animation deadline");
                stop(); Qt.quit();
            }
            root.step++;
        }
    }
}
