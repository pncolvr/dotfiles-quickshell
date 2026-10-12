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
    Test.TestCase { id: test; when: false }
    PanelWindow {
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
            if (root.step === 24) {
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
                Qt.quit()
            }
        }
    }
}
