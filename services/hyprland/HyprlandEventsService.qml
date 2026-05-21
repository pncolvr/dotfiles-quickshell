pragma Singleton

import QtQuick
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

    Connections {
        target: AudioService
        function onScreencastActiveChanged() {
            hideApplicationsProcess.command = Config.hyprlandHideApplicationsCommand(AudioService.screencastActive)
            hideApplicationsProcess.running = true
            WindowService.buildWindows()
        }
    }

    Process { id: hideApplicationsProcess }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
                case "submap":
                    root.setSubmapName(event.data.trim())
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
                // configreloaded: no window/status impact
            }
        }
    }
}