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
    Screencast { moduleName: "sharing" }
    Timers { moduleName: "timers"; window: root.window }
    Mic { moduleName: "mic" }
    Volume { moduleName: "volume" }
    Stats { moduleName: "stats" }
    Twitch { moduleName: "twitch"; moduleFocusSearch: true }
    
    Status { moduleName: "status" }
    Totp { moduleName: "totp"; moduleFocusSearch: true; window: root.window }
    Batteries { moduleName: "batteries"; window: root.window }
    Notifications { moduleName: "notifications"; window: root.window }
    Tray { moduleName: "tray"; window: root.window }
}
