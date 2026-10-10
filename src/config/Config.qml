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

    }
    readonly property var updatesPriorityPatterns: [
        "^discord",
        "^firewall",
        "^grub",
        "^hypr",
        "keyring",
        "^linux",
        "nvidia",
        "^quickshell",
        "^signal",
        "^steam",
        "^streamcontroller",
        "systemd",
        "^visual-studio-code-bin",
        "^vivaldi"
    ]

    readonly property var windowTitleCleanPatterns: [
        "- Vivaldi", "- qutebrowser", "- FreeTube", "- YouTube",
        "- Google Search", "- Twitch", "- Microsoft Azure"
    ]

    readonly property var specialWorkspaces: [3, 4, 10]

    readonly property var workspaceClassOverrides: ({
        "vivaldi-teams.microsoft.com__v2_-lt": "teams"
    })

    readonly property int updatesScheduleDelay: Timespan.fromSeconds(30)
    readonly property string updatesMarkdownFile: `${_internal.runtimeDirectory}/quickshell-updates.md`
    readonly property string updatesCacheFile: `${_internal.home}/.cache/quickshell/updates.cache`
    readonly property var updatesCheckCommand: ["bash", "-c", `cat "${_internal.home}/.cache/quickshell/updates.cache" 2>/dev/null`]
    readonly property var updatesRefreshCommand: ["bash", Qt.resolvedUrl("update-check.sh").toString().replace("file://", "")]
    readonly property var updatesInstallCommand: ["setsid", "ghostty", "-e", "yay"]

    readonly property string submapParserCommand: _internal.home +  "/.config/hypr/scripts/keybinds/parser.sh"

    readonly property string calendarUrl: "https://calendar.google.com/calendar/r/day" 

    readonly property int timerTickInterval: Timespan.fromMilliseconds(250)
    readonly property int countdownWarningThreshold: Timespan.fromSeconds(30)
    readonly property int countdownUrgentThreshold: Timespan.fromSeconds(10)
    readonly property var countdownSoundCommand: ["canberra-gtk-play", "-i", "alarm-clock-elapsed"]

    // The database is local to this config and ignored by Git.
    readonly property string databasePath: Quickshell.shellPath("data/quickshell.db")
    readonly property string databaseName: "quickshell"
    readonly property int pickerMaxRows: 12
    readonly property bool pickerShowPrompt: false
    readonly property bool pickerFuzzySearch: true
    // Only mixed-case queries are case sensitive; lowercase and uppercase ignore case.
    readonly property bool pickerSmartCase: true
    readonly property bool pickerRememberSelection: true
    readonly property var exposeWallpaperCommand: ["awww", "query", "--json"]
    readonly property var exposeWorkspaceIds: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    readonly property bool exposeAnimateDuringScreenShare: false
    readonly property string pickerNamespace: "quickshell-picker"
    readonly property int clipboardMaxItems: 1000
    readonly property int clipboardMaxTotalBytes: 500000000
    readonly property int clipboardMaxBytes: 10000000
    readonly property string clipboardDirectory: Quickshell.shellPath("data/clipboard")
    readonly property bool clipboardMonitorEnabled: true
    readonly property var pickerBridgeCommand: ["bash", Quickshell.shellPath("src/services/launcher/launcher.sh"), "--bridge"]
    readonly property var clipboardCommand: ["bash", Quickshell.shellPath("src/services/clipboard/clipboard.sh")]
    // Whole minutes, aligned to the minute of the hour (:00, :05, :10, ...).
    readonly property int twitchInterval: Timespan.fromMinutes(5)
    readonly property int twitchUndoDuration: Timespan.fromSeconds(6)
    readonly property string twitchBaseUrl: "https://www.twitch.tv/"

    readonly property string twitchCli: "twitch"
    readonly property string qutebrowserSessionsDirectory: `${Quickshell.env("XDG_DATA_HOME") || `${_internal.home}/.local/share`}/qutebrowser/sessions`
    readonly property var qutebrowserSessionFiles: [
        `${qutebrowserSessionsDirectory}/_autosave.yml`,
        `${qutebrowserSessionsDirectory}/default.yml`
    ]

    readonly property var statusManagerCheckCommand:  [_internal.statusManager, "--check"]
    readonly property var statusManagerSourceCommand: [_internal.statusManager, "--source"]
    readonly property var statusManagerToggleCommand: [_internal.statusManager, "--toggle"]
    readonly property var statusManagerClearCommand:  [_internal.statusManager, "--clear"]
    readonly property string statusTimecardExecutable: `${Quickshell.env("ZDOTDIR") || `${_internal.home}/.config/zsh`}/scripts/status/bin/timecard`
    readonly property string statusTimetableFile: Quickshell.env("TIMETABLE_FILE") || `${_internal.home}/Documents/timetable.csv`
    readonly property int statusTimecardRefreshInterval: Timespan.fromMinutes(1)
    readonly property var statusTimecardCommand: (includeWeeks, includeMonths) => [
        "bash", Qt.resolvedUrl("../services/status/timecard.sh").toString().replace("file://", ""),
        "--executable", statusTimecardExecutable, "--file", statusTimetableFile,
        "--date", Qt.formatDateTime(new Date(), "yyyy-MM-dd")
    ].concat(includeWeeks ? ["--weeks"] : [], includeMonths ? ["--months"] : [])

    readonly property string screenShareHiddenNamespace: "quickshell-private"
    readonly property int notificationLowTimeout: 2000
    readonly property int notificationNormalTimeout: 5000
    readonly property int notificationCriticalTimeout: 0
    readonly property int notificationPageSize: 25

    // Either recent-file limit can be disabled with 0.
    readonly property int recentFilesMaxItems: 20
    readonly property int recentFilesMaxDays: 7
    readonly property int recentFilesRefreshInterval: Timespan.fromSeconds(30)
    readonly property string recentFilesPath: `${Quickshell.env("XDG_DATA_HOME") || `${_internal.home}/.local/share`}/recently-used.xbel`
    readonly property var recentFilesCommand: [
        "bash", Qt.resolvedUrl("../services/files/recent-files.sh").toString().replace("file://", ""),
        "--source", recentFilesPath, "--max-items", String(recentFilesMaxItems),
        "--max-days", String(recentFilesMaxDays)
    ]
    readonly property var recentFolderCommand: [
        "bash", Qt.resolvedUrl("../services/files/folder-files.sh").toString().replace("file://", "")
    ]

    readonly property real micActivityThreshold: 0.02
    readonly property int micActivityHold: 200
    readonly property var mixerCommand: ["pavucontrol"]
    readonly property real audioVolumeStep: 0.01
    readonly property real audioMaxVolume: 1.5 // 150%, including microphone gain.
    readonly property int audioDevicesInterval: Timespan.fromSeconds(3)
    readonly property var audioDevicesCommand: [
        "bash", Qt.resolvedUrl("../services/audio/audio-devices.sh").toString().replace("file://", "")
    ]
    readonly property var audioRouteCommand: (input, name) => [
        "bash", Qt.resolvedUrl("../services/audio/audio-route.sh").toString().replace("file://", ""),
        input ? "input" : "output", name
    ]

    readonly property var screencastSoundCommand: sound => ["canberra-gtk-play", "-i", sound]
    readonly property string screencastStartSound: "device-added"
    readonly property string screencastStopSound: "device-removed"

    readonly property var networkCheckCommand: ["bash", "-c", "ping -c1 -W1 1.1.1.1 &>/dev/null && echo 1 || echo 0"]
    readonly property var networkVpnCommand: ["bash", "-c", "nmcli -t -f NAME,TYPE,STATE connection show 2>/dev/null | grep -E ':vpn:|:wireguard:'"]
    readonly property int networkConnectionsInterval: Timespan.fromSeconds(3)
    readonly property int networkProcessesInterval: Timespan.fromSeconds(3)

    readonly property string statsProcRoot: "/proc"
    readonly property string statsTemperaturePath: "/sys/class/thermal/thermal_zone1/temp"
    readonly property var statsProcessesCommand: resource => [
        "bash", Qt.resolvedUrl("../services/system/stats-processes.sh").toString().replace("file://", ""),
        resource, "--proc", statsProcRoot
    ]
    readonly property int statsInterval: Timespan.fromSeconds(1)
    readonly property int batteryReceiverInterval: Timespan.fromMinutes(1)
    readonly property int batteryLowThreshold: 20
    readonly property int batteryCriticalThreshold: 10
    readonly property var batteryReceiverCommand: [
        "bash", Qt.resolvedUrl("../services/system/logitech-batteries.sh").toString().replace("file://", "")
    ]
    readonly property int networkRetryInterval: Timespan.fromSeconds(5)
    readonly property int networkAlertInterval: Timespan.fromMinutes(1)
    readonly property int tooltipHideDelay: Timespan.fromMilliseconds(300)
    // TOTP secrets live in the desktop Secret Service, never in this config.
    readonly property string totpVault: "default"
    readonly property string totpVaultLabel: "Quickshell TOTP"
    readonly property string totpSecretTool: "secret-tool"
    readonly property string totpOathTool: "oathtool"
    readonly property int totpSecretTimeout: 30
    readonly property int totpDefaultPeriod: 30
    readonly property int totpDefaultDigits: 6
    readonly property string totpDefaultAlgorithm: "SHA1"
    readonly property int totpListMinRows: 9
    readonly property real totpListMaxScreenHeight: 0.45
    readonly property int totpTickInterval: Timespan.fromMilliseconds(250)
    readonly property int totpCopiedDuration: Timespan.fromSeconds(2)
    readonly property var totpCommand: [
        "bash", Qt.resolvedUrl("../services/security/totp.sh").toString().replace("file://", ""),
        "--vault", totpVault, "--label", totpVaultLabel, "--secret-tool", totpSecretTool,
        "--oath-tool", totpOathTool,
        "--timeout", String(totpSecretTimeout), "--period", String(totpDefaultPeriod),
        "--digits", String(totpDefaultDigits), "--algorithm", totpDefaultAlgorithm
    ]
    readonly property int debounceInterval: Timespan.fromMilliseconds(50)

    readonly property var hyprlandGetWindowsCommand: ["hyprctl", "clients", "-j"]
    readonly property var hyprlandGetNoWarpsCommand: ["bash", "-c", "hyprctl getoption cursor:no_warps -j | jq -r '.bool'"]
    readonly property var hyprlandSetNoWarpsCommand: (value) => ["hyprctl", "eval", `hl.config({ cursor = { no_warps = ${value} } })`]
    readonly property var hyprlandGetActiveWindowHiddenCommand: ["bash", "-c", "hyprctl getprop activewindow no_screen_share"]
    readonly property var hyprlandHideApplicationsCommand: (active) => ["hyprctl", "eval", `HideApplications(${active})`]
    // Resolve live group membership when dispatched; cached group indexes can change.
    readonly property var hyprlandFocusWindowByAddress: (address) => `function()
        for _, window in ipairs(hl.get_windows()) do
            if window.address == "${address}" and window.mapped then
                if window.group then
                    for index, member in ipairs(window.group.members) do
                        if member.address == window.address then
                            hl.dispatch(hl.dsp.group.active({ index = index, window = window }))
                            break
                        end
                    end
                end
                hl.dispatch(hl.dsp.focus({ window = window }))
                return
            end
        end
    end`
    readonly property var hyprlandMoveWindowToWorkspace: (address, workspace) => `function()
        for _, window in ipairs(hl.get_windows()) do
            if window.address == "${address}" and window.mapped then
                if window.group then
                    hl.dispatch(hl.dsp.window.move({ window = window, out_of_group = true }))
                end
                hl.dispatch(hl.dsp.window.move({ window = window, workspace = ${workspace}, follow = false }))
                return
            end
        end
    end`
    readonly property string hyprlandCycleNextTiled: "hl.dsp.window.cycle_next({ tiled = true })"
    readonly property string hyprlandCyclePreviousTiled: "hl.dsp.window.cycle_prev({ tiled = true })"

    readonly property var powerProfiles: ["power-saver", "balanced", "performance"]
}
