pragma Singleton

import QtQuick
import Quickshell
import "../services"

Item {
    QtObject {
        id: _internal
        readonly property string home: Quickshell.env("HOME")
        readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`
        readonly property string runtimeDirectory: Quickshell.env("XDG_RUNTIME_DIR")
    }

    // Display language: system, en or pt (European Portuguese). Unsupported locales use English.
    readonly property string language: "system"

    // Optional modules and integrations. Configure these before first launch.
    readonly property bool bookmarksEnabled: true
    readonly property bool browserRoutingEnabled: true
    readonly property bool browserHistoryEnabled: true
    readonly property bool browserWorkspaceFocusEnabled: true
    readonly property bool clipboardMonitorEnabled: true
    readonly property bool workModeEnabled: true
    readonly property bool statsNetworkEnabled: true
    readonly property bool batteriesEnabled: true
    readonly property bool twitchEnabled: true
    readonly property bool twitchQutebrowserEnabled: true
    // Calls the custom Hypr Lua helper; compositor animations also work without it.
    readonly property bool hyprlandHideApplicationsEnabled: true
    // Password prompts and browser autofill remain independent of the manager.
    readonly property bool vaultEnabled: true
    // Full-state backups still include TOTP tokens when the module is disabled.
    readonly property bool totpEnabled: true

    // Shared UI and privacy
    // Decorative motion follows both switches below.
    readonly property bool animationsEnabled: true
    readonly property bool animateDuringScreenShare: false
    // Status indicators have independent switches, including during screen sharing.
    readonly property bool animateIndicators: animationsEnabled || true
    readonly property bool screenSharePulseEnabled: animateIndicators
    readonly property bool recordingPulseEnabled: animateIndicators
    readonly property bool notificationBorderAnimationEnabled: animateIndicators
    readonly property bool micPulseEnabled: animateIndicators
    readonly property bool volumePulseEnabled: animateIndicators
    readonly property string screenShareHiddenNamespace: "quickshell-private"
    readonly property int debounceInterval: Timespan.fromMilliseconds(50)
    readonly property int tooltipHideDelay: Timespan.fromMilliseconds(300)

    // Storage and backup
    // The database is local to this config and ignored by Git.
    readonly property string databasePath: Quickshell.shellPath("data/quickshell.db")
    readonly property string databaseName: "quickshell"
    readonly property var backupCommand: ["bash", Quickshell.shellPath("src/services/storage/backup.sh")]

    // Panel keybinds. Desktop-opening shortcuts remain in Hypr.
    readonly property var keybinds: ({
        common: {
            cancel: "Escape",
            add: "Ctrl+N",
            edit: "Ctrl+E",
            save: "Ctrl+S",
            copy: "Ctrl+C",
            refresh: "Ctrl+R",
            search: "Ctrl+F",
            manage: "Ctrl+M",
            workFilter: "Ctrl+W",
            nextTab: "Ctrl+Tab",
            previousTab: "Ctrl+Shift+Tab",
            preview: "Ctrl+Shift+I"
        },
        vault: {
            lock: "Ctrl+L"
        },
        bookmarks: {
            history: "Ctrl+H"
        },
        clipboard: {
            delete: "Delete",
            pin: "Ctrl+P",
            pinnedOnly: "Ctrl+Shift+P"
        },
        remotes: {
            shutdown: "Ctrl+Shift+S",
            runningOnly: "Ctrl+Shift+R"
        },
        audio: {
            mute: "Ctrl+Shift+M"
        },
        notifications: {
            dnd: "Ctrl+Shift+D"
        },
        media: {
            previousPlayer: "Left",
            nextPlayer: "Right",
            closeWindow: "Alt+F4"
        },
        expose: {
            all: "Ctrl+Shift+A",
            workspace: "Ctrl",
            move: "Ctrl+Shift"
        },
        selection: {
            toggle: "Shift+Space",
            all: "Ctrl+A",
            clear: "Ctrl+Shift+A"
        }
    })

    // Ordered footer action IDs. Empty lists hide hints; explicit lists may exceed three.
    readonly property var panelHints: ({
        default: [],
        clipboard: [
            "clipboard.pin",
            "clipboard.pinnedOnly",
            "preview"
        ],
        manage: [
            "edit",
            "add",
            "refresh"
        ],
        editing: [
            "save"
        ],
        vault: [
            "edit",
            "add",
            "refresh",
            "vault.lock"
        ],
        projects: [
            "selection.toggle",
            "selection.clear"
        ],
        remotes: [
            "remotes.runningOnly",
            "remotes.shutdown"
        ],
        webapps: [],
        n8n: [],
        directories: [],
        multiple: [
            "selection.toggle",
            "selection.clear"
        ],
        expose: [
            "expose.all",
            "expose.workspace",
            "expose.move"
        ],
        wallpaper: [],
        windows: [
            "preview"
        ],
        files: []
    })

    // Shared copy-button success feedback
    readonly property int copyFeedbackDuration: Timespan.fromSeconds(2)

    // Launcher: shared picker
    // Shared defaults; feature-specific settings below can override these bindings.
    readonly property string pickerManageShortcut: keybinds.common.manage
    readonly property string pickerAddShortcut: keybinds.common.add
    readonly property string pickerShowAllShortcut: keybinds.common.workFilter
    readonly property string pickerWorkStatus: "work"
    readonly property int pickerMaxRows: 12
    readonly property int pickerPreviewMaxRows: 4
    readonly property bool pickerPreviewEnabled: false
    // null inherits the global setting; explicit booleans override it.
    readonly property var pickerPreviewDefaults: ({
        clipboard: null,
        windows: null
    })
    readonly property bool pickerShowPrompt: false
    readonly property bool pickerFuzzySearch: true
    // Only mixed-case queries are case sensitive; lowercase and uppercase ignore case.
    readonly property bool pickerSmartCase: true
    readonly property bool pickerRememberSelection: true
    readonly property string pickerNamespace: "quickshell-picker"
    readonly property var pickerBridgeCommand: ["bash", Quickshell.shellPath("src/services/launcher/launcher.sh"), "--bridge"]

    // Launcher: projects
    readonly property string projectDefaultApp: "code"
    // First matching extension wins. Commands are argv arrays, never shell code.
    readonly property var projectApps: [
        {
            id: "code",
            name: "Code",
            offerFolder: true,
            useFileNames: true,
            extensions: [".code-workspace"],
            command: ["code"],
            profiles: {
                work: "Work",
                personal: "Personal"
            },
            arguments: ["{path}"],
            profileArguments: ["--profile", "{profile}"],
            windowClass: "code",
            windowTitlePrefix: "{folderName}"
        },
        {
            id: "godot",
            name: "Godot",
            extensions: [".godot"],
            command: ["godot"],
            arguments: ["--editor", "{path}"],
            folderArguments: ["--editor", "--path", "{path}"]
        }
    ]
    readonly property var projectFileExclusions: ["*/.config/Code/*", "*/.godot/*", "*/.git/*"]
    readonly property var projectScanCommand: ["bash", Quickshell.shellPath("src/services/projects/scan.sh"), "scan"]
    readonly property string projectWorkStatus: pickerWorkStatus
    readonly property string projectManageShortcut: pickerManageShortcut
    readonly property string projectAddShortcut: pickerAddShortcut
    readonly property string projectShowAllShortcut: pickerShowAllShortcut
    readonly property string projectSshConfig: _internal.home + "/.ssh/config"
    readonly property string projectDotfilesGitDirectory: _internal.home + "/.cfg"
    readonly property string projectDotfilesWorkTree: _internal.home

    // Shared browsers and routing. Commands are literal argv templates.
    // Desktop integration is installed separately from integrations/browser/.
    readonly property string defaultBrowserId: "qutebrowser"
    readonly property var defaultBrowserCommand: browsers.find(browser=>browser.id===defaultBrowserId)?.command ?? []
    readonly property var browsers: [
        {
            id: "qutebrowser",
            name: "Qutebrowser",
            command: ["qutebrowser"],
            profiles: [
                {
                    id: "qutebrowser-webapp",
                    name: "Webapps"
                }
            ],
            profileArguments: ["--desktop-file-name", "{profile}", "-C", _internal.home + "/.config/qutebrowser/config.py", "-B", _internal.dataHome + "/{profile}"],
            reuseArguments: ["--target", "tab"],
            windowArguments: ["--target", "window"]
        },
        {
            id: "vivaldi",
            name: "Vivaldi",
            command: ["vivaldi"],
            profiles: [
                {
                    id: "inbox",
                    name: "inbox"
                },
                {
                    id: "lt",
                    name: "lt"
                },
                {
                    id: "storage",
                    name: "storage"
                }
            ],
            profileArguments: ["--profile-directory={profile}"],
            windowArguments: ["--new-window"],
            appArguments: ["--app={url}"]
        },
        {
            id: "default",
            name: "System default",
            command: ["xdg-open"]
        }
    ]
    readonly property int browserHistoryLimit: 100
    readonly property var browserRouterCommand: ["bash", Quickshell.shellPath("src/services/browser/browser.sh")]
    readonly property var browserOpenCommand: browserRoutingEnabled ? browserRouterCommand.concat(["open", "--fallback", JSON.stringify(defaultBrowserCommand), "--"]) : defaultBrowserCommand

    // Launcher: bookmarks
    readonly property string bookmarkFile: _internal.home + "/.config/qutebrowser/bookmarks/urls"

    // Launcher: directories
    readonly property string directoryManageShortcut: pickerManageShortcut
    readonly property string directoryAddShortcut: pickerAddShortcut
    readonly property string directoryShowAllShortcut: pickerShowAllShortcut
    readonly property string directoryWorkStatus: pickerWorkStatus
    readonly property var directoryResolveCommand: ["bash", Quickshell.shellPath("src/services/files/resolve-folder.sh")]
    readonly property var directoryOpenCommand: ["pcmanfm-qt"]

    // Launcher: remotes. Managed hosts/credentials stay in the backed-up database.
    readonly property var remoteRdpCommand: ["sdl-freerdp3"]
    readonly property var remoteSshCommand: ["ssh"]
    readonly property var remoteTerminalCommand: ["ghostty", "--gtk-single-instance=false", "--quit-after-last-window-closed=true", "-e"]
    readonly property var remoteVmCommand: ["virsh", "-c", "qemu:///system"]
    readonly property var remoteProbeCommand: ["nc"]
    readonly property int remoteVmWaitSeconds: 60
    readonly property var remoteRdpArguments: []

    // Launcher: wallpapers and Expose
    readonly property string wallpaperStateDirectory: `${_internal.home}/Pictures/.runtime`
    readonly property string wallpaperDirectory: `${_internal.home}/Pictures/wallpapers`
    readonly property var exposeWallpaperCommand: ["awww", "query", "--json"]
    readonly property var exposeWorkspaceIds: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    // Screenshots and recording
    readonly property string screenshotDirectory: `${_internal.home}/Pictures/Screenshots`
    readonly property string recordingDirectory: `${_internal.home}/Videos/recordings`
    readonly property var recordingEncoderArguments: [
        "--codec", "hevc_nvenc", "--codec-param", "preset=p7", "--codec-param", "tune=hq",
        "--codec-param", "rc=vbr", "--codec-param", "cq=21", "--codec-param", "rc-lookahead=32",
        "--codec-param", "bf=3", "--codec-param", "spatial_aq=1", "--codec-param", "temporal_aq=1",
        "--codec-param", "aq-strength=10"
    ]

    // Explicit process environment shared by online IPC and the offline exporter.
    readonly property var providerEnvironment: ({
        SCREENSHOT_FOLDER: screenshotDirectory,
        VIDEOS_FOLDER: recordingDirectory,
        WALLPAPER_DIRECTORY: wallpaperDirectory,
        WALLPAPER_STATE_DIRECTORY: wallpaperStateDirectory,
        WORKING_STATE_NAME: pickerWorkStatus,
        WORK_MODE_ENABLED: workModeEnabled ? "true" : "false"
    })

    // Clipboard
    readonly property int clipboardMaxItems: 1000
    readonly property int clipboardMaxTotalBytes: 500000000
    readonly property int clipboardMaxBytes: 10000000
    readonly property int clipboardPreviewMaxPixels: 8388608
    readonly property string clipboardDirectory: Quickshell.shellPath("data/clipboard")
    readonly property var clipboardCommand: ["bash", Quickshell.shellPath("src/services/clipboard/clipboard.sh")]

    // Hyprland: workspaces and windows
    readonly property var specialWorkspaces: [3, 4, 10]
    readonly property var workspaceClassOverrides: ({
        "vivaldi-teams.microsoft.com__v2_-lt": "teams"
    })
    readonly property var windowTitleCleanPatterns: [
        "- Vivaldi", "- qutebrowser", "- FreeTube", "- YouTube",
        "- Google Search", "- Twitch", "- Microsoft Azure"
    ]
    readonly property string submapParserCommand: _internal.home +  "/.config/hypr/scripts/keybinds/parser.sh"
    readonly property var hyprlandCaptureCloseStateCommand: ["bash", Quickshell.shellPath("src/services/hyprland/capture-close-state.sh")]
    readonly property var hyprlandGetWindowsCommand: ["hyprctl", "clients", "-j"]
    // Authoritative compositor setting; sharing temporarily suppresses animations.
    readonly property bool hyprlandAnimationsEnabled: true
    readonly property var hyprlandGetNoWarpsCommand: ["bash", "-c", "hyprctl getoption cursor:no_warps -j | jq -r '.bool'"]
    readonly property var hyprlandSetNoWarpsCommand: (value) => ["hyprctl", "eval", `hl.config({ cursor = { no_warps = ${value} } })`]
    readonly property var hyprlandGetActiveWindowHiddenCommand: ["bash", "-c", "hyprctl getprop activewindow no_screen_share"]
    readonly property var hyprlandSynchronizeCaptureCommand: (active, animationsEnabled) => ["hyprctl", "eval",
        hyprlandHideApplicationsEnabled
            ? `HideApplications(${active}, ${animationsEnabled})`
            : `hl.config({ animations = { enabled = ${animationsEnabled} } })`]
    // Resolve live group membership when dispatched; cached group indexes can change.
    readonly property var hyprlandFocusWindowByAddress: (address) => `function()
        for _, window in ipairs(hl.get_windows()) do
            if window.address == "${address}" and window.mapped then
                if window.group and #window.group.members > 1 then
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

    // Calendar
    readonly property string calendarEventUrl: "https://calendar.google.com/calendar/render?action=TEMPLATE"
    readonly property int calendarClockChangeEventHour: 18
    readonly property int calendarClockChangeEventMinute: 0
    readonly property int calendarClockChangeEventDurationMinutes: 15
    // Month numbers are 1–12; an empty list disables municipal holidays.
    readonly property var calendarMunicipalHolidays: [
        {
            month: 5,
            day: 22,
            name: "Dia de Leiria"
        }
    ]

    // Timers and countdowns
    readonly property int timerTickInterval: Timespan.fromMilliseconds(250)
    readonly property int countdownWarningThreshold: Timespan.fromSeconds(30)
    readonly property int countdownUrgentThreshold: Timespan.fromSeconds(10)
    readonly property var countdownSoundCommand: ["canberra-gtk-play", "-i", "alarm-clock-elapsed"]

    // Package updates
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
    readonly property int updatesScheduleDelay: Timespan.fromSeconds(30)
    readonly property string updatesMarkdownFile: `${_internal.runtimeDirectory}/quickshell-updates.md`
    readonly property var updatesCheckCommand: ["bash", "-c", `cat "${_internal.home}/.cache/quickshell/updates.cache" 2>/dev/null`]
    readonly property var updatesRefreshCommand: ["bash", Quickshell.shellPath("src/services/system/update-check.sh")]
    readonly property var updatesInstallCommand: ["setsid", "ghostty", "-e", "yay"]

    // Optional work mode; private detection rules and tracking live in SQLite.
    readonly property int workHistoryRetentionMonths: 36

    // Notifications
    readonly property int notificationLowTimeout: 2000
    readonly property int notificationNormalTimeout: 5000
    readonly property int notificationCriticalTimeout: 0
    readonly property int notificationPageSize: 25

    // Recent files
    // Either recent-file limit can be disabled with 0.
    readonly property int recentFilesMaxItems: 20
    readonly property int recentFilesMaxDays: 7
    readonly property int recentFilesRefreshInterval: Timespan.fromSeconds(30)
    readonly property var recentFileOpenCommand: ["gio", "open"]
    readonly property string recentFilesPath: `${_internal.dataHome}/recently-used.xbel`
    readonly property var recentFilesCommand: [
        "bash", Qt.resolvedUrl("../services/files/recent-files.sh").toString().replace("file://", ""),
        "--source", recentFilesPath, "--max-items", String(recentFilesMaxItems),
        "--max-days", String(recentFilesMaxDays)
    ]
    readonly property var recentFolderCommand: [
        "bash", Qt.resolvedUrl("../services/files/folder-files.sh").toString().replace("file://", "")
    ]

    // Audio: devices and levels
    readonly property real micActivityThreshold: 0.20 // Quickshell peak scale; calibrated above MMX silence (~0.14 max).
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

    // Audio: media and screencasting
    readonly property bool mediaPreferPlayingTab: true
    readonly property int mediaPositionInterval: Timespan.fromSeconds(1)
    readonly property var mediaSpectrumCommand: (serial, bands, fps) => [
        "bash", Qt.resolvedUrl("../services/audio/audio-spectrum.sh").toString().replace("file://", ""),
        serial, String(bands), String(fps)
    ]
    readonly property real mediaUnmuteVolume: 1.0 // Fallback when the player's previous volume is unknown.
    readonly property string mediaFullscreenNamespace: "quickshell-media"
    readonly property var screencastSoundCommand: sound => ["canberra-gtk-play", "-i", sound]
    readonly property string screencastStartSound: "device-added"
    readonly property string screencastStopSound: "device-removed"

    // Network
    readonly property var networkCheckCommand: ["bash", "-c", "ping -c1 -W1 1.1.1.1 &>/dev/null && echo 1 || echo 0"]
    readonly property var networkVpnCommand: ["bash", "-c", "nmcli -t -f NAME,TYPE,STATE connection show 2>/dev/null | grep -E ':vpn:|:wireguard:'"]
    readonly property int networkConnectionsInterval: Timespan.fromSeconds(3)
    readonly property int networkProcessesInterval: Timespan.fromSeconds(3)
    readonly property int networkRetryInterval: Timespan.fromSeconds(5)
    readonly property int networkAlertInterval: Timespan.fromMinutes(1)

    // System statistics and power
    readonly property string statsProcRoot: "/proc"
    readonly property string statsTemperaturePath: "/sys/class/thermal/thermal_zone1/temp"
    readonly property var statsProcessesCommand: resource => [
        "bash", Qt.resolvedUrl("../services/system/stats-processes.sh").toString().replace("file://", ""),
        resource, "--proc", statsProcRoot
    ]
    readonly property int statsInterval: Timespan.fromSeconds(1)
    readonly property var powerProfiles: ["power-saver", "balanced", "performance"]

    // Batteries
    readonly property int batteryReceiverInterval: Timespan.fromMinutes(1)
    readonly property int batteryLowThreshold: 20
    readonly property int batteryCriticalThreshold: 10
    readonly property var batteryReceiverCommand: [
        "bash", Qt.resolvedUrl("../services/system/logitech-batteries.sh").toString().replace("file://", "")
    ]

    // Twitch and browser sessions
    // Whole minutes, aligned to the minute of the hour (:00, :05, :10, ...).
    readonly property int twitchInterval: Timespan.fromMinutes(5)
    readonly property int twitchUndoDuration: Timespan.fromSeconds(6)
    readonly property string twitchBaseUrl: "https://www.twitch.tv/"
    readonly property string twitchCli: "twitch"
    readonly property string qutebrowserSessionsDirectory: `${_internal.dataHome}/qutebrowser/sessions`
    readonly property var qutebrowserSessionFiles: [
        `${qutebrowserSessionsDirectory}/_autosave.yml`,
        `${qutebrowserSessionsDirectory}/default.yml`
    ]

    // TOTP
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
    readonly property var totpCommand: [
        "bash", Qt.resolvedUrl("../services/security/totp.sh").toString().replace("file://", ""),
        "--vault", totpVault, "--label", totpVaultLabel, "--secret-tool", totpSecretTool,
        "--oath-tool", totpOathTool,
        "--timeout", String(totpSecretTimeout), "--period", String(totpDefaultPeriod),
        "--digits", String(totpDefaultDigits), "--algorithm", totpDefaultAlgorithm
    ]
}
