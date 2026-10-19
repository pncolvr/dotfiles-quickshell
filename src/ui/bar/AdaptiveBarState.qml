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
    property int borderSize: 0
    property bool borderReady: false
    property bool borderRefreshPending: false
    readonly property var samplingRegion: Colors.sampleRegion(screen, Theme.barHeight, Theme.adaptiveBarSampleHeight,
        windowService.allWindows, monitor?.id, monitor?.activeWorkspace?.id,
        monitor?.lastIpcObject.specialWorkspace?.id ?? 0, borderSize)
    readonly property var indicators: [Theme.inactive, Theme.accent].concat(AdaptiveBarService.foregrounds(screen))
    property color sample: Theme.background
    property color targetColor: islands ? Theme.background : sample
    property color animatedColor: targetColor
    property color approvedBackground: Theme.background
    readonly property color background: approvedBackground
    property int generation: 0
    property bool dirty: true
    readonly property bool sampling: capture.running
    property string capturedColor: ""
    property string lastResult: "waiting"
    readonly property string status: islands ? "islands" : blocked ? "blocked"
        : !borderReady ? "checking-borders" : sampling ? "sampling" : lastResult
    visible: false
    UI.MotionBehavior on animatedColor {
        ColorAnimation { duration: Theme.adaptiveBarColorDuration; easing.type: Easing.InOutCubic }
    }
    function approveBackground() {
        // A control may derive its foreground from our published background.
        // Publish after foreground bindings finish, rather than reevaluating
        // them recursively inside the background's own binding.
        const candidate = Colors.readable(animatedColor, Theme.background, Theme.text, indicators)
            ? animatedColor : Theme.background
        if (!Qt.colorEqual(approvedBackground, candidate)) approvedBackground = candidate
    }
    onIndicatorsChanged: Qt.callLater(root.approveBackground)
    onAnimatedColorChanged: Qt.callLater(root.approveBackground)
    function refreshBorderSize() {
        borderReady = false
        invalidate()
        if (borderProbe.running) borderRefreshPending = true
        else borderProbe.running = true
    }
    function invalidate() {
        generation++
        dirty = true
        Qt.callLater(root.captureIfReady)
    }
    function captureIfReady() {
        if (!dirty || blocked || islands || !borderReady || capture.running || !monitor) return
        dirty = false
        const region = samplingRegion
        if (!region) { lastResult = "invalid-geometry"; sample = Theme.background; return }
        capture.generation = generation
        capture.command = Config.adaptiveBarSampleCommand.concat([screen.name,
            String(region.x), String(region.y), String(region.width), String(region.height)])
        capture.running = true
    }
    onWorkspaceKeyChanged: invalidate()
    onIslandsChanged: invalidate()
    onBlockedChanged: invalidate()
    Component.onCompleted: {
        AdaptiveBarService.register(root); windowService.buildWindows(); refreshBorderSize()
        Qt.callLater(root.approveBackground)
    }
    Component.onDestruction: AdaptiveBarService.unregister(root)
    Connections { target: root.windowService; function onAllWindowsChanged() { root.invalidate() } }
    Connections {
        target: Theme
        function onBackgroundChanged() { Qt.callLater(root.approveBackground) }
        function onTextChanged() { Qt.callLater(root.approveBackground) }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") { root.refreshBorderSize(); return }
            if (["activewindowv2", "workspacev2", "focusedmonv2", "activespecialv2", "monitoraddedv2", "monitorremoved"].includes(event.name))
                root.invalidate()
        }
    }
    Connections {
        target: root.screen
        function onWidthChanged() { root.invalidate() }
        function onHeightChanged() { root.invalidate() }
    }
    Process {
        id: borderProbe
        command: ["hyprctl", "getoption", "general:border_size", "-j"]
        stdout: StdioCollector { id: borderResult; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: code => {
            let size = 0
            try { size = JSON.parse(borderResult.text).int } catch (_) {}
            root.borderSize = code === 0 && Number.isInteger(size) && size >= 0 ? size : 0
            root.borderReady = true
            root.invalidate()
            if (root.borderRefreshPending) {
                root.borderRefreshPending = false
                Qt.callLater(root.refreshBorderSize)
            }
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
            if (root.dirty) Qt.callLater(root.captureIfReady)
        }
    }
}
