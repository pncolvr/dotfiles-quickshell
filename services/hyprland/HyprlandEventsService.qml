pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../services"
Singleton {
    id: root

    // Submap
    property string submapName: ""
    property bool submapActive: submapName !== ""

    function setSubmapName(value) {
        if (value != root.submapName) root.submapName = value
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
                case "submap":
                    root.setSubmapName(event.data.trim())
                    break
            }
            StatusService.reload()
            WindowService.buildWindows()
        }
    }
}