import QtQuick
import "../modules/system"
import "../modules/status"
import "../modules/hyprland"
import "../theme"
import "../theme/ui"

Row {
    id: root
    required property var window
    spacing: Theme.moduleSpacing

    ActiveWindowNoScreenShare {}
    Submap {}
    Screencast {}
    Mic {}
    Volume {}
    Stats {}
    Notifications {}
    Status {}
    Totp { window: root.window }
    Batteries { window: root.window }
    Tray {
        window: root.window
    }
}
