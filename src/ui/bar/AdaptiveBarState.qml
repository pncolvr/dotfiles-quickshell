pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "../../config"
import "../../theme"
import "../../services"
import "../../services/ui/AdaptiveColors.mjs" as Colors
import ".." as UI

Item {
    id: root
    required property var screen
    property Item foregroundRoot: null
    property var windowService: WindowService
    property var monitor: Hyprland.monitors.values.find(output => output.name === screen.name) ?? null
    readonly property string workspaceKey: monitor ? monitor.id + ":" + monitor.activeWorkspace?.id
        + ":" + (monitor.lastIpcObject.specialWorkspace?.id ?? 0) : ""
    readonly property bool islands: !!monitor && !Colors.hasTiledWindow(windowService.allWindows,
        monitor.id, monitor.activeWorkspace?.id, monitor.lastIpcObject.specialWorkspace?.id ?? 0)
    readonly property bool blocked: AdaptiveBarService.blocked(screen)
    readonly property var indicators: [Theme.inactive, Theme.accent].concat(AdaptiveBarService.foregrounds(screen))
    property color sample: Theme.background
    property color targetColor: islands ? Theme.background : sample
    property color animatedColor: targetColor
    readonly property color background: Colors.readable(animatedColor, Theme.background, Theme.text, indicators)
        ? animatedColor : Theme.background
    property int generation: 0
    property bool dirty: true
    readonly property bool sampling: capture.running
    property string capturedColor: ""
    property string lastResult: "waiting"
    readonly property string status: islands ? "islands" : blocked ? "blocked" : sampling ? "sampling" : lastResult
    visible: false
    UI.MotionBehavior on animatedColor {
        ColorAnimation { duration: Theme.adaptiveBarColorDuration; easing.type: Easing.InOutCubic }
    }
    function invalidate() {
        generation++
        dirty = true
        settle.restart()
    }
    onWorkspaceKeyChanged: invalidate()
    onIslandsChanged: invalidate()
    onBlockedChanged: invalidate()
    Component.onCompleted: { AdaptiveBarService.register(root); windowService.buildWindows(); invalidate() }
    Component.onDestruction: AdaptiveBarService.unregister(root)
    Connections { target: root.windowService; function onAllWindowsChanged() { root.invalidate() } }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["activewindowv2", "workspacev2", "focusedmonv2", "activespecialv2", "configreloaded", "monitoraddedv2", "monitorremoved"].includes(event.name))
                root.invalidate()
        }
    }
    Connections {
        target: root.screen
        function onWidthChanged() { root.invalidate() }
        function onHeightChanged() { root.invalidate() }
    }
    Timer {
        id: settle
        interval: Math.max(80, Config.debounceInterval * 2)
        onTriggered: {
            if (root.blocked || root.islands || capture.running || !root.monitor) return
            root.dirty = false
            capture.generation = root.generation
            capture.command = Config.adaptiveBarSampleCommand.concat([root.screen.name,
                String(Math.round(root.screen.x)), String(Math.round(root.screen.y + Theme.barHeight + 1)),
                String(Math.floor(root.screen.width)), String(Math.max(1, Math.min(Theme.adaptiveBarSampleHeight,
                    Math.floor(root.screen.height - Theme.barHeight - 1))))])
            capture.running = true
        }
    }
    Process {
        id: capture
        property int generation: 0
        stdout: StdioCollector { id: result; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: code => {
            if (generation === root.generation && !root.blocked && !root.islands) {
                const color = result.text.trim()
                const margin = root.sample === Theme.background ? 0.15 : 0
                root.capturedColor = /^#[0-9a-f]{6}$/i.test(color) ? color : ""
                root.lastResult = code !== 0 || !root.capturedColor ? "capture-error"
                    : Colors.readable(color, Theme.background, Theme.text, root.indicators, margin) ? "accepted" : "unreadable"
                root.sample = root.lastResult === "accepted" ? color : Theme.background
            }
            if (root.dirty) settle.restart()
        }
    }
}
