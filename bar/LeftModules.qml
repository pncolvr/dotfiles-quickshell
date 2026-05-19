import QtQuick
import "../modules/hyprland"
import "../theme"
import "../theme/ui"

Row {
    spacing: Theme.moduleSpacing
    Workspaces {}
    Windows {}
}