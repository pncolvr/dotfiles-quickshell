import QtQuick
import "../modules/hyprland"
import "../theme"
import "../theme/ui"

Row {
    height: parent.height
    spacing: Theme.moduleSpacing
    Workspaces {}
    Windows {}
}
