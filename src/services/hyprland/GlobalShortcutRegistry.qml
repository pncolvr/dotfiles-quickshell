pragma ComponentBehavior: Bound
// Installed GlobalShortcut metadata references a non-exported PostReloadHook base.
import QtQml
import QtQml.Models
import Quickshell
import Quickshell.Hyprland

// Register once per shell; callbacks reuse feature services and their lifecycle.
Scope {
    id: root
    property string appId: "quickshell"
    required property var actions

    Instantiator {
        model: root.actions
        delegate: Component {
            // qmllint disable unresolved-type
            GlobalShortcut {
                // qmllint enable unresolved-type
                required property var modelData
                appid: root.appId
                name: modelData.name
                description: modelData.description
                onPressed: modelData.activate()
            }
        }
    }
}