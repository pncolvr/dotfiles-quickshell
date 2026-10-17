pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../src/ui" as UI
import "../launcher" as Fixtures

Scope {
    id: root
    property var first: null
    property var second: null
    property real previousPhase: 0
    FloatingWindow { id: host; visible: true; implicitWidth: 200; implicitHeight: 100 }
    Component {
        id: pulse
        UI.PulseText { text: "Pulse"; pulsing: true; animationEnabled: true }
    }
    Fixtures.NativeFocusDriver {
        id: driver
        onFailed: message => { console.error("PULSE CLOCK FAIL:", message); root.finish() }
        onCompleted: root.finish()
    }
    function finish() {
        if (first) first.destroy()
        if (second) second.destroy()
        Qt.quit()
    }
    Component.onCompleted: {
        driver.add("idle clock", () => {
            driver.check(!UI.PulseClock.active, "no animation without visible pulses")
            first = pulse.createObject(host.contentItem)
            previousPhase = UI.PulseClock.phase
        })
        driver.waitFor("first pulse animates", () => UI.PulseClock.phase !== previousPhase)
        driver.add("join shared phase", () => {
            second = pulse.createObject(host.contentItem)
            first.visible = false
            driver.check(UI.PulseClock.active, "another visible pulse keeps the clock active")
            previousPhase = UI.PulseClock.phase
        })
        driver.waitFor("remaining pulse animates", () => UI.PulseClock.phase !== previousPhase)
        driver.add("rejoin and destroy second", () => {
            first.visible = true
            second.destroy()
            second = null
        })
        driver.add("policy and request gates", () => {
            driver.check(UI.PulseClock.active, "resumed pulse remains registered")
            first.animationEnabled = false
            driver.check(!UI.PulseClock.active, "policy disables the last pulse")
            first.animationEnabled = true
            driver.check(UI.PulseClock.active, "independently enabled pulse restarts the clock")
            first.pulsing = false
            driver.check(!UI.PulseClock.active, "clearing the request stops the clock")
            first.pulsing = true
            host.visible = false
            driver.check(!UI.PulseClock.active, "hidden window stops the clock")
            previousPhase = UI.PulseClock.phase
        })
        driver.add("idle phase", () => {
            driver.check(UI.PulseClock.phase === previousPhase, "inactive clock does not advance")
            host.visible = true
            previousPhase = UI.PulseClock.phase
        })
        driver.waitFor("reshown window animates", () => UI.PulseClock.phase !== previousPhase)
        driver.add("destroy final pulse", () => { first.destroy(); first = null })
        driver.waitFor("destruction releases clock", () => !UI.PulseClock.active)
        driver.add("finished", () => console.log("PASS: shared pulse clock joins/resumes, preserves other consumers, stops while idle or disabled and releases destroyed text"))
        driver.running = true
    }
}
