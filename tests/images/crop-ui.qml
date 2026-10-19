pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Quickshell
import "../../src/ui" as UI
import "../../src/modules/system/notifications"
import "../../src/modules/media"
import "../../src/modules/system/audio"

Scope {
    id: root
    property int step: 0
    property int ticks: 0
    property int settledComputations: 0
    property int guiTicks: 0
    property bool awaitingRender: false
    property bool captureStarted: false
    readonly property url ringSource: "file://" + Quickshell.env("CROP_TEST_DIR") + "/ring.png"
    readonly property url plainSource: "file://" + Quickshell.env("CROP_TEST_DIR") + "/plain.svg"
    readonly property url blackSource: "file://" + Quickshell.env("CROP_TEST_DIR") + "/black.svg"
    readonly property url vectorSource: "file://" + Quickshell.env("CROP_TEST_DIR") + "/ring.svg"
    function check(value, message) {
        if (value) return true
        console.error("IMAGE CROP FAIL: " + message)
        ticker.stop(); Qt.quit(); return false
    }
    function captureRenderedScene() {
        if (captureStarted) return
        captureStarted = true
        // Capture the parent to include the children's layer/mask effects.
        const accepted = scene.grabToImage(result => {
            if (!root.check(result.saveToFile(Quickshell.env("CROP_TEST_DIR") + "/rendered.png"),
                "could not save the rendered crop scene")) return
            root.step++
        }, Qt.size(scene.width, scene.height))
        root.check(accepted, "could not request the rendered crop scene")
    }
    Connections {
        target: scene.Window.window
        function onFrameSwapped() {
            if (!root.awaitingRender) return
            root.awaitingRender = false
            // Schedule the grab after the completed frame's notification.
            Qt.callLater(root.captureRenderedScene)
        }
    }
    Component {
        id: deletedOwner
        QtObject { function analyzeImage(key) { root.check(false,"a deleted request owner must never run") } }
    }
    FloatingWindow {
        visible: true
        color: "transparent"
        implicitWidth: 1000; implicitHeight: 600
        Item {
            id: scene
            width: 1000; height: 600
            UI.CroppedImage { id: small; x:10; y:10; width:40; height:40; source:root.ringSource; circular:true }
            UI.CroppedImage { id: large; x:100; y:10; width:400; height:400; source:root.ringSource }
            NotificationAvatar { id: notification; x:550; y:10; width:40; height:40; source:root.ringSource }
            UI.CroppedImage { id: plain; x:550; y:90; width:300; height:150; source:root.plainSource }
            NotificationAvatar { id: black; x:550; y:280; width:40; height:40; source:root.blackSource }
            TwitchUserRow { id: twitch; x:10; y:450; user:({login:"synthetic",online:true,avatar:root.ringSource,game:"Testing",title:"Synthetic title",description:"Fixture",viewers:"1"}) }
            MediaCardBackground { id: background; x:700; y:280; width:250; height:180; artworkSource:root.ringSource }
            UI.CroppedImage { id: vector; width:80; height:80; visible:false }
        }
    }
    Timer { interval:1; running:true; repeat:true; onTriggered:root.guiTicks++ }
    Timer {
        id: ticker
        interval:100; running:true; repeat:true
        onTriggered: {
            if (!root.check(++root.ticks < 80,"timed out at step " + root.step)) return
            switch(root.step) {
            case 0:
                if (!large.analysis || !small.analysis || !plain.analysis || !black.analysis || !notification.analysis || !background.ready) return
                if (!root.check(!!large.analysis.ring && JSON.stringify(large.analysis.ring) === JSON.stringify(small.analysis.ring)
                    && JSON.stringify(large.analysis.ring) === JSON.stringify(notification.analysis.ring),
                    "avatar, notification and artwork share one cached ring result: " + JSON.stringify(large.analysis.ring))) return
                if (!root.check(UI.ImageCropCache.computations === 3,"each unique source is analyzed once")) return
                if (!root.check(large.originalSize.width === 2048 && large.decodedSize.width === 2048
                    && small.decodedSize.width === 2048,"small and large views retain original source resolution")) return
                if (!root.check(!plain.analysis.ring && plain.baseCrop.width === 1 && plain.cropAspect === 2
                    && plain.paintedWidth === 300 && plain.paintedHeight === 150,"ordinary rectangular artwork retains its geometry")) return
                if (!root.check(black.paddingNeeded && !black.analysis.ring,"edge-connected black padding remains supported")) return
                if (!root.check(black.analysis.padding.filter(value => value > 0).length > 6000,
                    "padding analysis preserves its opaque interior (pixels=" + black.analysis.padding.filter(value => value > 0).length + ")")) return
                if (!root.check(large.smooth && large.mipmap && small.layer.mipmap,"shared texture settings remain active")) return
                root.settledComputations = UI.ImageCropCache.computations
                root.step++
                if (Quickshell.env("QT_QPA_PLATFORM") === "wayland") {
                    // Analysis updates layer geometry and mask textures. Wait
                    // for the native scene to render before checking GPU pixels.
                    root.awaitingRender = true
                    scene.Window.window.requestUpdate()
                } else {
                    // Offscreen windows do not swap frames. Their grab drives
                    // rendering; this path checks analysis, not GPU mask pixels.
                    Qt.callLater(root.captureRenderedScene)
                }
                break
            case 1:
                // The frame notification and grab callback advance this step.
                break
            case 2:
                if (!root.check(UI.ImageCropCache.computations === root.settledComputations,"idle and repeated drawing do not rerun detection")) return
                large.source = root.plainSource
                if (!root.check(!large.analysis?.ring,"source replacement does not retain the previous crop")) return
                root.step++
                break
            case 3:
                if (!large.analysis) return
                if (!root.check(!large.analysis.ring && large.baseCrop.width === 1 && UI.ImageCropCache.computations === root.settledComputations,
                    "source replacement reuses cached metadata (computations=" + UI.ImageCropCache.computations
                        + ", previous=" + root.settledComputations + ")")) return
                large.source = root.ringSource
                root.step++
                break
            case 4:
                if (!large.analysis?.ring) return
                if (!root.check(UI.ImageCropCache.computations === root.settledComputations && root.guiTicks > 20,
                    "cached resize/source switches leave the UI loop responsive")) return
                const disposed = deletedOwner.createObject(root)
                UI.ImageCropCache.request("fixture-deleted-owner",disposed)
                disposed.destroy()
                root.step++
                break
            case 5:
                if (UI.ImageCropCache.queue.length || UI.ImageCropCache.active) return
                if (!root.check(!UI.ImageCropCache.pending["fixture-deleted-owner"],"deleted owners are removed from pending requests")) return
                vector.source = root.vectorSource
                root.step++
                break
            case 6:
                if (!vector.analysis?.ring || vector.status !== Image.Ready) return
                if (!root.check(vector.originalSize.width === 2048,"vector analysis records the intrinsic source dimensions")) return
                root.settledComputations = UI.ImageCropCache.computations
                vector.width = 700; vector.height = 700
                root.step++
                break
            case 7:
                if (vector.status !== Image.Ready || vector.decodedSize.width < Math.ceil(700 * Screen.devicePixelRatio)) return
                if (!root.check(UI.ImageCropCache.computations === root.settledComputations && vector.originalSize.width === 2048,
                    "enlarged vector sources rerasterize sharply without repeating detection")) return
                console.log("PASS: cached shared crops, native source resolution, rectangular fallback, black padding, texture settings, source replacement, disposed owners and idle analysis")
                console.log("IMAGE CROP TIMING:",large.analysis.analysisMilliseconds,"ms worker,",large.analysis.samplingMilliseconds,"ms GUI sampling")
                console.log("IMAGE CROP FALLBACK TIMING:",plain.analysis.analysisMilliseconds,"ms worker")
                Qt.quit()
                break
            }
        }
    }
}
