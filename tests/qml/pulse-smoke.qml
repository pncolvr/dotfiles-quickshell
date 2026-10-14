import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Wayland
import "../../src/theme/ui" as UI

Scope {
    id: root
    property int step: 0
    property real lowestRed: 1
    property real highestRed: 0
    property bool phasesMatch: true
    Test.TestCase { id: test; when: false }
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
        anchors { left: true; bottom: true }
        Component.onCompleted: root.offsetSurface(secondSurface)
        implicitWidth: 100
        implicitHeight: 100
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-pulse-test"
        color: "black"
        UI.PulseText {
            id: secondGlyph
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
                const image = test.grabImage(glyph)
                pixel = image.pixel(50, 50)
                root.lowestRed = Math.min(root.lowestRed, pixel.r)
                root.highestRed = Math.max(root.highestRed, pixel.r)
            }
            if (root.step === 6) secondGlyph.pulsing = true
            if (root.step >= 8 && root.step <= 23) {
                const otherPixel = test.grabImage(secondGlyph).pixel(50, 50)
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
                console.log(glyph.pulseActive && glyph.layer.enabled
                    ? "PASS: showing the window resumes its requested pulse" : "PULSE FAIL: resumed pulse")
                const firstPixel = test.grabImage(glyph).pixel(50, 50)
                const secondPixel = test.grabImage(secondGlyph).pixel(50, 50)
                console.log(Math.abs(firstPixel.r - secondPixel.r) < 0.08
                    ? "PASS: resumed pulse rejoins the shared phase" : "PULSE FAIL: resumed pulse phase")
                Qt.quit()
            }
        }
    }
}
