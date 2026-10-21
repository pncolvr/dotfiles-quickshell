import QtQuick
import "../../modules/hyprland"
import ".."

Row {
    id: root
    property real maximumWidth: parent.width
    height: parent.height
    Workspaces { id: workspaces }
    Windows { maximumWidth: Math.max(0, root.maximumWidth - workspaces.width) }
}
