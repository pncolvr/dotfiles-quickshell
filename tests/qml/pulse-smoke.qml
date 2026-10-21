import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../src/ui" as UI
import "../../src/config"
import "../../src/theme"
import "../../src/services"

WorkerScope {
    id: root
    property int step: 0
    property real lowestRed: 1
    property real highestRed: 0
    property bool phasesMatch: true
    property var fakeConfig: Config
    property var fakeAudio: AudioService
    property int firstFrames: 0
    property int secondFrames: 0
    property double resumedTraceStarted: 0
    property bool compositorSampleDone: false
    property bool compositorSampleStarted: false
    readonly property var captureScreen: surface.screen
    Test.TestCase { id: test; when: false }
    Process {
        id: compositorSample
        stdout: StdioCollector { id: compositorOutput }
        stderr: StdioCollector { id: compositorError }
        onExited: (code, status) => {
            root.compositorSampleDone = true
            if (code !== 0 || status !== 0) {
                console.log("PULSE FAIL: compositor capture", compositorError.text)
                return
            }
            const sample = JSON.parse(compositorOutput.text)
            console.log("PULSE COMPOSITOR", JSON.stringify(sample))
            console.log(Math.abs(sample.first - sample.second) < 0.08
                ? "PASS: simultaneous compositor capture has matching pulse phases"
                : "PULSE FAIL: simultaneous compositor phase " + sample.first + " " + sample.second)
        }
    }
    Connections {
        target: surface.contentItem.Window.window
        function onFrameSwapped() { root.firstFrames++ }
    }
    Connections {
        target: secondSurface.contentItem.Window.window
        function onFrameSwapped() { root.secondFrames++ }
    }
    function grabPixel(item, name) {
        const stepBefore = root.step
        const started = Date.now()
        const before = [firstFrames, secondFrames]
        const pixel = test.grabImage(item).pixel(50, 50)
        if (Quickshell.env("PULSE_TEST_TRACE") === "1")
            console.log("PULSE CAPTURE", JSON.stringify({name, stepBefore, stepAfter: root.step,
                started, finished: Date.now(), before, after: [firstFrames, secondFrames], red: pixel.r}))
        return pixel
    }
    function offsetSurface(surface) { surface.margins.left = 100 }
    // Quickshell selects the native PanelWindow backend at runtime.
    // qmllint disable uncreatable-type
    PanelWindow {
        // qmllint enable uncreatable-type
        id: surface
        anchors { left: true; bottom: true }
        implicitWidth: 100
        implicitHeight: 100
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-pulse-test"
        color: "black"
        mask: Region {}
        UI.PulseText {
            id: glyph
            anchors.fill: parent
            centerVertical: false
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "█"
            font.pixelSize: 80
            baseColor: "blue"
            pulseColor: "red"
            pulsing: true
        }
    }
    // qmllint disable uncreatable-type
    PanelWindow {
        // qmllint enable uncreatable-type
        id: secondSurface
        screen: surface.screen
        anchors { left: true; bottom: true }
        Component.onCompleted: root.offsetSurface(secondSurface)
        implicitWidth: 100
        implicitHeight: 100
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-pulse-test"
        color: "black"
        mask: Region {}
        UI.PulseText {
            id: secondGlyph
            animationEnabled: UI.MotionPolicy.micPulseEnabled
            anchors.fill: parent
            centerVertical: false
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "█"
            font.pixelSize: 80
            baseColor: "blue"
            pulseColor: "red"
        }
    }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            root.step++
            let pixel = null
            if (root.step <= 25) {
                pixel = root.grabPixel(glyph, "first")
                root.lowestRed = Math.min(root.lowestRed, pixel.r)
                root.highestRed = Math.max(root.highestRed, pixel.r)
            }
            if (root.step === 6) secondGlyph.pulsing = true
            if (root.step >= 8 && root.step <= 23) {
                const otherPixel = root.grabPixel(secondGlyph, "staggered second")
                if (Math.abs(pixel.r - otherPixel.r) > 0.08) root.phasesMatch = false
            }
            if (root.step === 24) {
                console.log(root.phasesMatch ? "PASS: staggered pulses stay synchronized across windows"
                    : "PULSE FAIL: staggered pulses are out of phase")
                const ok = root.highestRed > 0.8 && root.lowestRed < 0.2 && glyph.color === Qt.rgba(1, 1, 1, 1)
                console.log(ok ? "PASS: GPU pulse changes rendered color without changing text color"
                    : "PULSE FAIL: color range " + root.lowestRed + " " + root.highestRed)
                glyph.pulsing = false
            } else if (root.step === 25) {
                console.log(pixel.b > 0.9 && pixel.r < 0.1 && !glyph.layer.enabled
                    ? "PASS: disabling pulse restores base color and releases the layer"
                    : "PULSE FAIL: stopped color")
                glyph.pulsing = true
                glyph.visible = false
            } else if (root.step === 26) {
                console.log(!glyph.pulseActive && !glyph.layer.enabled
                    ? "PASS: hidden text stops pulsing" : "PULSE FAIL: hidden text")
                glyph.visible = true
                surface.visible = false
            } else if (root.step === 27) {
                console.log(!glyph.pulseActive && !glyph.layer.enabled
                    ? "PASS: hidden window stops pulsing" : "PULSE FAIL: hidden window")
                surface.visible = true
            } else if (root.step === 28) {
                if (Quickshell.env("PULSE_TEST_COMPOSITOR") === "1" && !root.compositorSampleDone) {
                    root.step = 27
                    const phase = UI.PulseClock.phase
                    const blend = 0.5 - 0.5 * Math.cos(2 * Math.PI * phase)
                    if (!root.compositorSampleStarted && blend >= 0.35 && blend <= 0.65) {
                        root.compositorSampleStarted = true
                        const output = root.captureScreen
                        compositorSample.command = ["bash", Quickshell.env("PULSE_TEST_CAPTURE_HELPER"),
                            output.x + "," + (output.y + output.height - 100) + " 200x100"]
                        compositorSample.running = true
                    }
                    return
                }
                console.log(glyph.pulseActive && glyph.layer.enabled
                    ? "PASS: showing the window resumes its requested pulse" : "PULSE FAIL: resumed pulse")
                const firstPixel = root.grabPixel(glyph, "resumed first")
                const secondPixel = root.grabPixel(secondGlyph, "resumed second")
                console.log(Math.abs(firstPixel.r - secondPixel.r) < 0.08
                    ? "PASS: resumed pulse rejoins the shared phase" : "PULSE FAIL: resumed pulse phase " + firstPixel.r + " " + secondPixel.r)
                if (Quickshell.env("PULSE_TEST_TRACE") === "1") {
                    if (!root.resumedTraceStarted) root.resumedTraceStarted = Date.now()
                    if (Date.now() - root.resumedTraceStarted < Theme.pulsingTextDuration) {
                        root.step = 27
                        return
                    }
                }
                root.fakeConfig.animationsEnabled = false
                root.fakeAudio.screencastActive = true
                root.lowestRed = 1
                root.highestRed = 0
            } else if (root.step >= 30 && root.step <= 51) {
                const statusPixel = root.grabPixel(secondGlyph, "status")
                root.lowestRed = Math.min(root.lowestRed, statusPixel.r)
                root.highestRed = Math.max(root.highestRed, statusPixel.r)
                if (root.step === 51) {
                    console.log(!glyph.pulseActive && secondGlyph.pulseActive
                        && root.highestRed > 0.8 && root.lowestRed < 0.2
                        ? "PASS: status shader keeps pulsing with master off during sharing"
                        : "PULSE FAIL: status exception did not animate " + root.lowestRed + " " + root.highestRed)
                    root.fakeConfig.micPulseEnabled = false
                }
            } else if (root.step === 52) {
                const stoppedPixel = root.grabPixel(secondGlyph, "stopped status")
                console.log(!secondGlyph.pulseActive && !secondGlyph.layer.enabled
                    && stoppedPixel.b > 0.9 && stoppedPixel.r < 0.1
                    ? "PASS: status switch stops the shader and releases its layer"
                    : "PULSE FAIL: status switch")
                Qt.quit()
            }
        }
    }
}
