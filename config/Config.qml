pragma Singleton

import QtQuick
import Quickshell
import "../services"
import "."

Item {
     QtObject {
        id: _internal
        readonly property string home:Quickshell.env("HOME")
        readonly property string runtimeDirectory:Quickshell.env("XDG_RUNTIME_DIR")
        readonly property string userId:ConfigService.userId
        readonly property string statusManager: `${home}/.config/zsh/scripts/status/manager.sh`
        readonly property string notificationsManager: "swaync-client"
        readonly property string powerProfilesManager: "powerprofilesctl"

    }
    readonly property var updatesPriorityPatterns: [
        "^discord",
        "^linux",
        "nvidia",
        "^vivaldi",
        "^steam",
        "^firewall",
        "^visual-studio-code-bin",
        "^grub",
        "^hypr",
        "^streamcontroller",
        "^signal",
        "systemd",
        "^quickshell"
    ]

    readonly property var windowTitleCleanPatterns: [
        "- Vivaldi", "- qutebrowser", "- FreeTube", "- YouTube",
        "- Google Search", "- Twitch", "- Microsoft Azure"
    ]

    readonly property var specialWorkspaces: [3, 4, 10]

    readonly property var workspaceClassOverrides: ({
        "vivaldi-teams.microsoft.com__v2_-lt": "teams"
    })

    readonly property int updatesMax: 30
    readonly property int updatesInterval: Timespan.fromHours(1)
    readonly property var updatesCheckCommand: ["bash", "-c", "yay -Qu 2>/dev/null | sort"]
    readonly property var updatesInstallCommand: ["bash", "-c", "ghostty -e yay &"]

    readonly property string submapParserCommand: _internal.home +  "/.config/hypr/scripts/keybinds/parser.sh"

    readonly property string calendarUrl: "https://calendar.google.com/calendar/r/day" 

    readonly property string twitchUsersFile: Qt.resolvedUrl("./twitch-users").toString().replace("file://", "")
    readonly property int twitchInterval: Timespan.fromMinutes(5)
    readonly property var twitchStreamCommand: [`${_internal.home}/.config/hypr/scripts/tolocalplayer.sh`]
    readonly property string twitchBaseUrl: "https://www.twitch.tv/"

    readonly property string twitchCacheDir: `${Quickshell.env("XDG_CACHE_HOME") ?? _internal.home + "/.cache"}/quickshell/twitch`
    readonly property string twitchOnlineFile: `${Quickshell.env("XDG_RUNTIME_DIR")}/twitch_online_${_internal.userId}`
    readonly property string twitchCli: "twitch"

    readonly property var statusManagerCheckCommand:  [_internal.statusManager, "--check"]
    readonly property var statusManagerSourceCommand: [_internal.statusManager, "--source"]
    readonly property var statusManagerToggleCommand: [_internal.statusManager, "--toggle"]
    readonly property var statusManagerClearCommand:  [_internal.statusManager, "--clear"]

    readonly property var notificationsManagerGetDndCommand:[_internal.notificationsManager, "--get-dnd"]
    readonly property var notificationsManagerToggleDndCommand:[_internal.notificationsManager, "--toggle-dnd"]
    readonly property var notificationsManagerOpenPanelCommand:[_internal.notificationsManager, "--open-panel"]

    readonly property string preferredMicName: "PRO X 2 LIGHTSPEED"
    readonly property var mixerCommand: ["pavucontrol"]

    readonly property var screencastSoundCommand: ["canberra-gtk-play", "-i"]
    readonly property string screencastStartSound: "device-added"
    readonly property string screencastStopSound: "device-removed"

    readonly property var networkCheckCommand: ["bash", "-c", "ping -c1 -W1 1.1.1.1 &>/dev/null && echo 1 || echo 0"]

    readonly property int statsInterval: Timespan.fromSeconds(1)
    readonly property int networkRetryInterval: Timespan.fromSeconds(5)
    readonly property int networkAlertInterval: Timespan.fromMinutes(1)
    readonly property int tooltipHideDelay: Timespan.fromMilliseconds(150)
    readonly property var cpuCommand: ["cat", "/proc/stat"]
    readonly property var memoryDetailCommand: ["bash", "-c", "free -m | awk '/Mem/{print $2,$3,$4,$6,$7} /Swap/{print $2,$3,$4}'"]
    readonly property var tempCommand: ["bash", "-c", "cat /sys/class/thermal/thermal_zone1/temp"]

    readonly property var hyprlandGetNoWarpsCommand: ["bash", "-c", "hyprctl getoption cursor:no_warps -j | jq -r '.bool'"]
    readonly property var hyprlandGetActiveWindowHiddenCommand: ["bash", "-c", "hyprctl getprop activewindow no_screen_share"]

    readonly property var powerProfiles: ["power-saver", "balanced", "performance"]
    readonly property string powerProfilesDefaultProfile: "balanced"
    readonly property var powerProfilesSetCommand: [_internal.powerProfilesManager, "set"]
    readonly property var powerProfilesGetCommand: [_internal.powerProfilesManager, "get"]
}