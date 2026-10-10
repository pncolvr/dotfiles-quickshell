import QtQuick
import "../modules/system"
import "../modules/media"
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
    Timers { window: root.window }
    Mic {}
    Volume {}
    Stats {}
    Twitch {}
    
    Status {}
    Totp { window: root.window }
    Batteries { window: root.window }
    Notifications { window: root.window }
    Tray { window: root.window }
}
