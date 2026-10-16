pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtTest as Test
import Quickshell.Wayland
import "../../src/bar"
import "../../src/theme"
import "../../src/theme/ui" as UI
Scope {
    id: root
    property int stage: 0
    property int ticks: 0
    property bool failed: false
    property var samples: ({})
    property var contents: ({})
    Test.TestCase { id: images; when: false }
    function check(ok, message) { if (!ok) { failed = true; console.error("SHADOW GPU FAIL:", message) } }
    function capture(name) {
        const image = images.grabImage(surface)
        samples[name] = image.alpha(30, 3)
        contents[name] = image.red(Math.round(surface.motion.displayedX) + 50, 80)
        const frames = Quickshell.env("PANEL_SHADOW_FRAMES")
        if (frames) image.save(frames + "/" + name + ".png")
        stage++
    }
    // Quickshell selects the creatable native PanelWindow backend at runtime.
    // qmllint disable uncreatable-type
    PanelWindow {
        // qmllint enable uncreatable-type
        readonly property var surfaceComponent: surface
        visible: true
        anchors.top: true
        WlrLayershell.margins.top: Theme.barHeight
        implicitWidth: 800
        implicitHeight: 480
        exclusiveZone: 0
        color: "transparent"
        mask: Region { width: 0; height: 0 }
        WlrLayershell.namespace: "quickshell-shadow-check"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        TopPanelSurface {
            id: surface
            anchors.fill: parent
            contentX: 180
            contentWidth: 300
            contentHeight: 180
            UI.TabBar { id: tabs; width: parent.width; labels: ["First", "Second"] }
            Rectangle { x: 40; y: 70; width: 40; height: 40; color: "white" }
        }
    }
    Timer {
        interval: 35
        running: true
        repeat: true
        onTriggered: {
            if (++root.ticks > 120) { console.error("SHADOW GPU FAIL: timeout"); Qt.quit(); return }
            switch (root.stage) {
            case 0:
                surface.requestedVisible = true
                root.stage++
                break
            case 1: root.capture("opening"); break
            case 2:
                if (surface.motion.transitioning) return
                root.capture("settled")
                break
            case 3:
                tabs.currentIndex = 1
                root.stage++
                break
            case 4: root.capture("tab-fading"); break
            case 5:
                if (surface.motion.transitioning) return
                root.capture("tab-settled")
                break
            case 6:
                surface.contentX = 350
                surface.contentWidth = 360
                surface.contentKey = "next module"
                root.stage++
                break
            case 7: root.capture("switching"); break
            case 8:
                if (surface.motion.transitioning) return
                surface.requestedVisible = false
                root.stage++
                break
            case 9: root.capture("closing"); break
            default:
                if (surface.presented) return
                root.check(root.samples.settled > 0, "settled bar shadow is rendered by the GPU")
                root.check(root.contents["tab-fading"] > 0 && root.contents["tab-fading"] < root.contents.settled
                    && root.contents["tab-settled"] === root.contents.settled,
                    "same-size tab content visibly fades in and settles at full opacity")
                root.check(Math.abs(root.samples["tab-fading"] - root.samples.settled) <= 2,
                    "tab fade keeps the bar shadow steady")
                root.check(root.samples.opening > 0 && root.samples.opening <= root.samples.settled,
                    "opening keeps a visible shadow at the same bar edge")
                root.check(Math.abs(root.samples.switching - root.samples.settled) <= 2,
                    "changing modules preserves the bar shadow without an opacity reset")
                root.check(root.samples.closing > 0 && root.samples.closing <= root.samples.settled,
                    "closing fades the shadow at the bar edge instead of moving it away")
                console.log(root.failed ? "SHADOW GPU FAIL: pixels" : "PASS: GPU bar shadow remains anchored through opening, tab fades, module handoff and closing without taking focus")
                Qt.quit()
            }
        }
    }
}
