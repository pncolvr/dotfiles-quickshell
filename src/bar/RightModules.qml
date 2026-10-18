import QtQuick
import "../modules/system"
import "../modules/media"
import "../modules/status"
import "../modules/hyprland"
import "../ui"

Row {
    id: root
    required property var window
    spacing: 0

    ActiveWindowNoScreenShare {}
    Submap {}
    Screencast {}
    Recording {}
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
