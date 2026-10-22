pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/config"
import "../../src/theme"
import "../../src/services"
import "../../src/ui/bar" as Bar
import "../../src/ui/components" as UI
import "../../src/modules/system/audio" as Audio

WorkerScope {
    id: root
    property var settings: Config
    property int step: 0
    property int ticks: 0
    property bool failed: false
    property bool dispatching: false
    readonly property var provider: sampler.item
    Test.TestCase { id: events; when: false }
    QtObject { id: output; property string name: "fixture"; property int x: -1000; property int y: 40; property int width: 1000; property int height: 800 }
    QtObject { id: other; property string name: "other" }
    QtObject { id: fakeMonitor; property int id: 2; property var activeWorkspace: ({id:7}); property var lastIpcObject: ({specialWorkspace:{id:0}}) }
    QtObject {
        id: backend
        property var allWindows: [{monitor:2,workspace:{id:7},mapped:true,hidden:false,floating:false,at:[-998,72],size:[996,700]}]
        function buildWindows() {}
    }
    QtObject {
        id: overlayHost
        property var screen: output
        property var surfaceComponent: ({motion:{displayedX:100,displayedWidth:780,fraction:1}})
    }
    QtObject { id: overlay; property var host: overlayHost; property bool requested: true; property bool presentationPending: true }
    FileView { id: color; path: Quickshell.env("ADAPTIVE_TEST_DIR") + "/fixture.color"; blockWrites: true }
    FileView { id: requests; path: Quickshell.env("ADAPTIVE_TEST_DIR") + "/requests"; blockLoading: true; printErrors: false }
    FileView { id: delay; path: Quickshell.env("ADAPTIVE_TEST_DIR") + "/delay"; blockWrites: true; printErrors: false }
    function countRequests() { requests.reload(); return requests.text().trim().split("\n").filter(Boolean).length }
    property int requestCount: 0
    property int waitTicks: 0
    property real decorativeOpacity: 0.4
    property bool exerciseButton: false
    Test.SignalSpy { id: contrastChanges; target: root.provider; signalName: "indicatorsChanged" }
    Item {
        id: foregrounds
        // Real controls can derive their foreground from their host background.
        // Scanning that color must not reenter the background's contrast binding.
        Text { color: root.provider && !Qt.colorEqual(root.provider.background, Theme.background) ? Theme.inactive : Theme.text }
        Text { id: urgent; color: Theme.warning; visible: false }
        Text { color: Theme.warning; opacity: 0.5 }
        Item {
            readonly property color buttonSurfaceColor: root.provider?.background ?? Theme.background
            UI.ActionButton { id: derivedButton; visible: root.exerciseButton; label: "Derived foreground"; fillColor: "transparent" }
        }
        Audio.MediaVisualizer {
            // Exercise the real visualizer's exclusion, without audio capture.
            width: 200; height: 50
            Rectangle { opacity: root.decorativeOpacity }
            Text { color: Theme.warning }
        }
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function preview(name) {
        const directory = Quickshell.env("ADAPTIVE_PREVIEWS")
        if (directory) events.grabImage(background).save(directory + "/" + name + ".png")
    }
    Loader {
        id: sampler
        active: Config.adaptiveBarEnabled
        sourceComponent: Bar.AdaptiveBarState { screen: output; monitor: fakeMonitor; windowService: backend; foregroundRoot: foregrounds }
    }
    FloatingWindow {
        color: "transparent"
        visible: true
        implicitWidth: 1000; implicitHeight: 100
        Bar.BarBackground {
            id: background
            width: 1000; height: 30
            islands: true
            leftBounds: Qt.rect(0,0,180,30)
            centerBounds: Qt.rect(400,0,200,30)
            rightBounds: Qt.rect(800,0,200,30)
        }
        UI.TooltipBackground {
            id: straightPanel
            y: 40; panelWidth: 180; height: 50
            barJoin: false
        }
    }
    Timer {
        id: ticker
        interval: 20; repeat: true; running: !root.dispatching
        onTriggered: {
            if (root.dispatching) return
            root.dispatching = true
            try { ticker.advance() }
            finally { root.dispatching = false }
        }
        function advance() {
            try {
                root.check(++root.ticks < 250, "timed out at step " + root.step)
                switch (root.step) {
                case 0:
                    root.check(!Config.adaptiveBarEnabled && !sampler.item && AdaptiveBarService.providers.length === 0,
                        "disabled feature creates no sampler")
                    root.check(AdaptiveBarService.backgroundFor(output) === Theme.background, "disabled palette is unchanged")
                    const image = events.grabImage(background)
                    root.check(image.alpha(50,15) === 255 && image.alpha(250,15) === 0 && image.alpha(500,15) === 255,
                        "three opaque islands have transparent gaps")
                    root.check(image.alpha(179,29) === 0 && image.alpha(400,29) === 0 && image.alpha(800,29) === 0,
                        "inner bottom corners are rounded")
                    root.preview("islands")
                    background.bridges = [{x:150,width:700,opacity:1}]
                    const bridge = events.grabImage(background)
                    root.check(bridge.alpha(250,15) === 255 && bridge.alpha(700,15) === 255,
                        "a wider panel draws continuous backing between islands")
                    root.preview("panel-backing")
                    background.bridges = []
                    root.check(straightPanel.width === straightPanel.panelWidth && straightPanel.joinRadius === 0,
                        "island panels have no flared top joins")
                    root.check(root.provider === null, "sampler remains disabled during geometry checks")
                    color.setText("#08121c\n")
                    root.settings.adaptiveBarEnabled = true
                    root.step++; break
                case 1:
                    if (!root.provider || !Qt.colorEqual(AdaptiveBarService.backgroundFor(output), "#08121c")) return
                    root.check(!root.provider.islands && AdaptiveBarService.backgroundFor(other) === Theme.background,
                        "each monitor keeps its own approved color")
                    root.check(root.provider.borderReady && root.provider.borderSize === 2
                        && root.provider.samplingRegion.y === 72, "native border metadata places the strip inside window content")
                    requests.reload()
                    root.check(requests.text().trim().split("\n")[0] === "fixture -1000 72 1000 12",
                        "capture command uses the border-adjusted full-width strip")
                    root.check(AdaptiveBarService.foregrounds(output).length === 1,
                        "hidden and deliberately dim indicators do not veto sampled colors")
                    urgent.visible = true
                    root.check(AdaptiveBarService.foregrounds(output).length === 2,
                        "visible urgent text participates in contrast checks")
                    urgent.visible = false
                    contrastChanges.clear()
                    root.decorativeOpacity = 0.8
                    root.check(contrastChanges.count === 0,
                        "visualizer changes do not reevaluate adaptive contrast")
                    root.exerciseButton = true
                    root.check(AdaptiveBarService.foregrounds(output).length > 1,
                        "shared button palette references participate in adaptive contrast")
                    contrastChanges.clear()
                    derivedButton.down = true
                    root.check(contrastChanges.count === 0,
                        "derived button colors do not feed back into the adaptive background")
                    derivedButton.down = false
                    root.exerciseButton = false
                    root.requestCount = root.countRequests()
                    for (let request = 0; request < 20; request++) root.provider.invalidate()
                    root.step++; break
                case 2:
                    if (root.provider.dirty || root.provider.sampling) return
                    // FileView reloads an existing request log asynchronously.
                    if (root.countRequests() === root.requestCount) return
                    root.check(root.countRequests() === root.requestCount + 1,
                        "a burst of invalidations produces one deferred capture; before=" + root.requestCount
                            + ", after=" + root.countRequests())
                    background.islands = false
                    background.background = root.provider.background
                    AdaptiveBarService.registerOverlay(overlay)
                    root.requestCount = root.countRequests()
                    color.setText("#ffffff\n")
                    root.provider.invalidate()
                    root.step++; break
                case 3:
                    if (++root.waitTicks < 15) return
                    root.preview("sampled")
                    root.check(root.provider.blocked && root.countRequests() === root.requestCount,
                        "open overlays block sampling")
                    root.check(Qt.colorEqual(AdaptiveBarService.backgroundFor(output), "#08121c"), "open panels retain the cached background")
                    AdaptiveBarService.unregisterOverlay(overlay)
                    root.step++; break
                case 4:
                    if (AdaptiveBarService.backgroundFor(output) !== Theme.background) return
                    color.setText("#08121c\n")
                    delay.setText("delay")
                    root.provider.invalidate()
                    root.step++; break
                case 5:
                    if (!root.provider.sampling) return
                    AdaptiveBarService.registerOverlay(overlay)
                    root.step++; break
                case 6:
                    if (root.provider.sampling) return
                    root.check(root.provider.sample === Theme.background,
                        "an in-flight sample cannot update the background after an overlay opens")
                    AdaptiveBarService.unregisterOverlay(overlay)
                    backend.allWindows = [{monitor:2,workspace:{id:7},floating:true}]
                    AdaptiveBarService.registerOverlay(overlay)
                    root.step++; break
                case 7:
                    root.check(root.provider.islands && AdaptiveBarService.backgroundFor(output) === Theme.background,
                        "floating-only workspaces use palette islands")
                    const bridges = AdaptiveBarService.bridges(output)
                    root.check(bridges.length === 1 && bridges[0].x === 100
                        && bridges[0].width === 780 && !AdaptiveBarService.bridges(other).length,
                        "panel backing follows the panel footprint on its monitor only")
                    AdaptiveBarService.unregisterOverlay(overlay)
                    root.settings.adaptiveBarEnabled = false
                    root.step++; break
                case 8:
                    root.check(!sampler.item && !AdaptiveBarService.providers.length, "disabling unloads the sampler")
                    console.log("PASS: adaptive bar disabled lifecycle, islands, panel backing, per-monitor sampling, contrast fallback, visualizer exclusion, coalesced capture requests and overlay freeze")
                    stop(); Qt.quit()
                }
            } catch (error) {
                console.error("ADAPTIVE FAIL:", error)
                stop(); Qt.quit()
            }
        }
    }
}
