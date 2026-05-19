pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import "../../theme"
import "../../theme/ui" as UI

UI.Row {
    id: root
    spacing: Theme.workspaceSpacing

    Repeater {
        model: {
            const ws = Hyprland.workspaces.values
            return [...ws].sort((a, b) => a.id - b.id)
        }
        delegate: UI.IconButton {
            id: window
            required property var modelData
            property var workspace: modelData
            property bool hasWindows: updateHasWindows()

            text: Theme.workspaceIcons[window.workspace.id - 1] ?? Theme.workspaceUnknownIcon
            iconColor: getTextColour()
            onClicked: workspace.activate()

            Connections {
                target: window.workspace.toplevels
                function onRowsInserted() { window.updateHasWindows() }
                function onRowsRemoved()  { window.updateHasWindows() }
                function onModelReset()   { window.updateHasWindows() }
            }

            Component.onCompleted: updateHasWindows

            function getTextColour() {
                if (hovered)            return Theme.text
                if (workspace.active)   return Theme.accent
                if (workspace.urgent)   return Theme.warning
                if (hasWindows)         return Theme.inactive
                return Theme.empty
            }

            function updateHasWindows() {
                hasWindows = workspace.toplevels.rowCount() > 0
            }

        }
    }
}