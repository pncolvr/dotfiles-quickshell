import QtQuick
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/config"

Scope {
    id: root
    readonly property string phase: Quickshell.env("CAPTURE_SYNC_PHASE")
    property var audio: AudioService
    property var configuration: Config
    readonly property var service: HyprlandEventsService
    readonly property var windows: WindowService
    property int stage: 0
    property int ticks: 0
    property int index: 0
    property int settledTicks: 0
    property bool failed: false
    property var commands: []
    property var expected: []
    property var steps: []

    Process {
        id: readLog
        command: ["cat", Quickshell.env("CAPTURE_SYNC_LOG")]
        stdout: StdioCollector {
            onStreamFinished: root.commands = text.trim().split("\n").filter(line => line !== "")
        }
    }
    function check(condition, message) {
        if (condition) return
        failed = true
        console.error("CAPTURE SYNC FAIL: " + phase + " " + message + " " + JSON.stringify(commands))
        Qt.quit()
    }
    function configure() {
        const reload = () => audio.compositor.rawEvent({name: "configreloaded"})
        const ready = () => audio.screencastReady = true
        switch (phase) {
        case "on":
            check(service.animationsEnabled, "Config on with no share")
            steps = [
                {run: ready, command: "false true", advanceWhileBusy: true},
                {run: () => configuration.hyprlandAnimationsEnabled = false, command: "false false"},
                {run: () => configuration.hyprlandAnimationsEnabled = true, command: "false true"},
                {run: () => audio.captureCount = 2, command: "true false"},
                {run: () => audio.captureCount = 1},
                {run: () => configuration.hyprlandAnimationsEnabled = false},
                {run: reload, command: "true false"},
                {run: () => audio.captureCount = 0, command: "false false"},
                {run: () => configuration.hyprlandAnimationsEnabled = true, command: "false true"},
                {run: () => audio.captureCount = 1, command: "true false"},
                {run: () => { audio.screencastReady = false; audio.captureCount = 0; reload() }},
                {run: () => { audio.captureCount = 1; ready() }, command: "true false"},
                {run: () => audio.captureCount = 0, command: "false true"}
            ]
            break
        case "off":
            check(!service.animationsEnabled, "edited Config off is honored after restart")
            steps = [{run: ready, command: "false false"},
                {run: () => audio.captureCount = 2, command: "true false"},
                {run: () => audio.captureCount = 1},
                {run: () => audio.captureCount = 0, command: "false false"},
                {run: reload, command: "false false"}]
            break
        case "restart-on":
            check(service.animationsEnabled, "edited Config on is honored after restart")
            steps = [{run: ready, command: "false true"}, {run: reload, command: "false true"}]
            break
        case "sharing":
            check(!service.animationsEnabled, "existing share suppresses Config on at startup")
            steps = [{run: ready, command: "true false"}, {run: () => audio.captureCount = 1},
                {run: reload, command: "true false"},
                {run: () => audio.captureCount = 0, command: "false true"}]
            break
        default: check(false, "unknown phase"); break
        }
    }
    function next() {
        settledTicks = 0
        const step = steps[index]
        if (step.command !== undefined) expected = expected.concat([step.command])
        step.run()
    }
    Component.onCompleted: audio.captureCount = phase === "sharing" ? 2 : 0
    Timer {
        interval: 25
        repeat: true
        running: !root.failed
        onTriggered: {
            if (!readLog.running) readLog.running = true
            if (++root.ticks > 350) {
                root.check(false, "timeout at step " + root.index + "; refreshed window state: " + root.windows.synchronizedState)
                return
            }
            switch (root.stage) {
            case 0:
                if (root.ticks < 8) return
                root.check(root.commands.length === 0, "unknown capture state must not be published")
                root.configure()
                if (root.failed) return
                root.next()
                root.stage++
                break
            case 1:
                root.check(root.commands.length <= root.expected.length, "unexpected command")
                if (JSON.stringify(root.commands) !== JSON.stringify(root.expected)) return
                const step = root.steps[root.index]
                // The hidden badge must reflect the completed compositor update,
                // without needing a focus or workspace event to refresh it.
                if (step.command !== undefined && !step.advanceWhileBusy
                    && root.windows.synchronizedState !== step.command) return
                // Check quiet steps; the first transition also exercises a busy command.
                if (!root.steps[root.index].advanceWhileBusy && ++root.settledTicks < 7) return
                if (++root.index < root.steps.length) { root.next(); return }
                if (!root.failed) console.log("PASS: capture synchronization " + root.phase)
                Qt.quit()
                break
            }
        }
    }
}
