pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../services"
import "../../config"

Singleton {
    id: root

    // Submap
    property string submapName: ""
    property bool submapActive: submapName !== ""

    function setSubmapName(value) {
        if (value != root.submapName) root.submapName = value
    }

    readonly property bool animationsEnabled: Config.hyprlandAnimationsEnabled && !AudioService.screencastActive
    onAnimationsEnabledChanged: synchronizeCapture()
    readonly property bool hideApplicationsEnabled: Config.hyprlandHideApplicationsEnabled
    onHideApplicationsEnabledChanged: synchronizeCapture()

    function synchronizeCapture() { captureSyncTimer.restart() }

    Timer {
        id: captureSyncTimer
        interval: 50
        onTriggered: {
            if (!AudioService.screencastReady) return
            if (hideApplicationsProcess.running) { restart(); return }
            hideApplicationsProcess.command = Config.hyprlandSynchronizeCaptureCommand(
                AudioService.screencastActive, root.animationsEnabled)
            hideApplicationsProcess.running = true
        }
    }

    Connections {
        target: AudioService
        function onScreencastReadyChanged() { root.synchronizeCapture() }
        function onScreencastActiveChanged() {
            root.synchronizeCapture()
        }
    }

    Process {
        id: hideApplicationsProcess
        // Query no_screen_share after the compositor applies the new state.
        onExited: WindowService.buildWindows()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
                case "submap":
                    root.setSubmapName(event.data.trim())
                    break
                case "configreloaded":
                    root.synchronizeCapture()
                    break
                case "activewindow":
                case "activewindowv2":
                    StatusService.reload()
                    WindowService.buildWindows()
                    break
                case "openwindow":
                case "closewindow":
                case "kill":
                    StatusService.reload()
                    break
                case "workspace":
                case "workspacev2":
                case "focusedmon":
                case "focusedmonv2":
                case "activespecial":
                case "activespecialv2":
                case "fullscreen":
                case "windowtitle":
                case "windowtitlev2":
                case "movewindow":
                case "movewindowv2":
                case "changefloatingmode":
                case "pin":
                case "minimized":
                case "togglegroup":
                case "moveintogroup":
                case "moveoutofgroup":
                    WindowService.buildWindows()
                    break

                // No action needed
                // createworkspace/destroyworkspace: no windows change
                // moveworkspace/renameworkspace: workspace meta, not window state
                // monitoradded/removed: no window or status impact
                // openlayer/closelayer: layer surfaces, not client windows
                // activelayout: keyboard layout only
                // screencast: screencopy client state
                // urgent: window urgency hint, not tracked
                // ignoregrouplock/lockgroups: group lock state only
            }
        }
    }

    Component.onCompleted: synchronizeCapture()
}
