# Configuration

## Files to edit

| File | Controls |
| --- | --- |
| [`src/config/Config.qml`](../src/config/Config.qml) | Commands, intervals, defaults, namespaces and feature settings |
| [`config/Theme.qml`](../config/Theme.qml) → [`src/theme/Theme.qml`](../src/theme/Theme.qml) | Fonts, glyphs, colors, dimensions and spacing |
| [`src/bar/LeftModules.qml`](../src/bar/LeftModules.qml) | Workspaces and windows |
| [`src/bar/CenterModules.qml`](../src/bar/CenterModules.qml) | Clock, package updates and recent files |
| [`src/bar/RightModules.qml`](../src/bar/RightModules.qml) | System, Twitch, status, TOTP, batteries, notifications and tray |
| [`shell.qml`](../shell.qml) | Entry point, startup environment and dedicated windows |

The root `config/` link exposes `Config.qml` and a relative `Theme.qml` link to
`src/theme/Theme.qml`. Editing either theme path updates the same file; both QML
modules export the same singleton. Reusable UI components remain under `src/theme/ui`.

`Config.qml` groups settings by component: shared UI/privacy and storage;
launcher pickers, projects, directories and wallpapers; screenshots/recording;
clipboard; Hyprland;
calendar/timers; package updates; status/timecard; notifications; recent files;
audio/media; network/statistics/power; batteries; Twitch/browser sessions; and TOTP.

## Launcher defaults

Project and directory pickers inherit `pickerManageShortcut`, `pickerAddShortcut`,
`pickerShowAllShortcut` and `pickerWorkStatus` from the shared picker section.
Changing a shared default updates both pickers. Each feature retains its own
setting and can override the shared value:

```qml
readonly property string pickerManageShortcut: "Ctrl+M"
readonly property string projectManageShortcut: pickerManageShortcut
readonly property string directoryManageShortcut: "Alt+M"
```

Recent-file and qutebrowser session paths share the private `_internal.dataHome`
helper, which honors `XDG_DATA_HOME` and falls back to `~/.local/share`. Their
full-path settings remain individually editable. Equal durations and limits with
different purposes remain independent.

## Bookmarks

`bookmarkFile` defaults to Qutebrowser's existing `~/.config/qutebrowser/bookmarks/urls`.
`bookmarkBrowserCommand` inherits `projectBrowserCommand`, which defaults to
`["xdg-open"]`. Both use the desktop's default browser association. Override either
with a literal argv array to choose another opener. These are public path/command settings; bookmark contents stay in the
existing local file and are read when the picker opens.

## Webapp browsers

`webappBrowsers` follows the configurable application pattern: each item has an
`id`, visible `name`, and argv `command`. Each browser's `profiles` array defines
its profile choices as `{id: "profile-directory", name: "Visible label"}`. Manage
shows these profiles in a combo, alongside Browser default. The stable profile
ID is saved per entry; the configured label is only for display.

Browser definitions also accept optional `profileArguments`,
`reuseArguments`, `windowArguments` and `appArguments`. The normal window mode
uses `reuseArguments` when configured; Qutebrowser sets `--target tab`, retaining
its profile directory so launches open tabs in that profile. Vivaldi has no reuse
override. Templates accept `{profile}` and `{url}`
as literal values. App-window arguments include the URL; other modes append it.
Private entry URLs, selected profile IDs and launch hooks are managed in Webapps and
saved in SQLite rather than Config. Webapps has no legacy-file reader or import
settings; add and edit entries through Manage.

## Theme defaults

`config/Theme.qml` exposes one palette toggle:

```qml
readonly property bool darkMode: true
```

Set it to `false` for the similar light palette. The existing configuration reload
applies the change; there is no separate picker, database preference or Config.qml
switch. Fonts, icons, dimensions and motion controls keep their existing settings.

`src/theme/ThemePalette.qml` holds the dark/light color definitions and foreground
contrast policy. The dark defaults preserve the original colors, including alpha.
Edit its palette entries to customize colors, or override a specific Theme property
with a literal as before. Every component reads colors through Theme; only the
Theme implementation selects a palette. Shared filled controls use
`Theme.foregroundOn(surface)`, while selected text uses `Theme.selectionText`.
Calendar highlight text and notification colors also come from Theme. Functional
black/white used by QR images, image masks and shader inputs stays independent.


`Theme.qml` groups appearance settings by component and keeps rendering state in
shared UI utilities. Pulse timing lives in `src/theme/ui/PulseClock.qml`; calendar
color selection belongs to the month view used by month/year calendars.

Feature properties can inherit shared defaults while retaining their own names:

```qml
readonly property int tooltipWidth: 420
readonly property int statsTooltipWidth: tooltipWidth
```

Changing `tooltipWidth` updates timers, stats and status panels together. The
`tooltipMaxHeightRatio` and `tooltipCompactMaxHeightRatio` defaults group the 60%
and 50% tooltip limits. `rotateIcon` supplies retry/media-flip glyphs, and the
network up-arrow inherits `upIcon`. Calendar cell and tray icon heights default
to their widths. Assign a literal to a feature property to override that default.
Equal numbers with unrelated purposes remain separate settings.

## Desktop integrations

Review these defaults when adapting the configuration:

- `workModeEnabled` controls native work/personal detection, tracking and shared category UI.
  Rules and manual mode are saved privately in SQLite through Status → Manage.
- `wallpaperDirectory` sets the wallpaper picker root, defaulting to `~/Pictures/wallpapers`.
  An explicit directory argument overrides it for one picker session.
- `wallpaperStateDirectory` holds saved per-mode/per-monitor links, defaulting to `~/Pictures/.runtime`.
- `screenshotDirectory` and `recordingDirectory` set capture destinations.
- `recordingEncoderArguments` supplies literal codec/quality arguments for wf-recorder.
  The default is HEVC/NVENC; framerate remains a separate recording-menu choice.
- `submapParserCommand` points to `~/.config/hypr/scripts/keybinds/parser.sh`.
- Screen-sharing commands expect `HideApplications(active, animationsEnabled)` and related Hyprland rules.
- Update installation opens Ghostty and runs `yay`. The refresh helper is
  `src/services/system/update-check.sh`. Pacman hooks and cron jobs should invoke
  that helper directly. The root `config` link exposes settings only; it does not
  provide the updater. The helper combines
  `checkupdates --nocolor` (pacman-contrib) with `yay -Qua --color never`, refreshing
  repository metadata in `~/.cache/quickshell/updates.db` without sudo. Schedule
  the helper in your user crontab; remove the old root `yay -Sy` job. Running the
  queries alone does not publish the five-column cache used by the module.
  Concurrent checks are locked, failed checks preserve the previous snapshot and
  report an error, and abandoned temporary cache/error files older than an hour
  are removed. If pacman's configured database or the private update database
  has `db.lck`, the helper preserves the cache, requests `updates schedule` and
  exits successfully. The desktop retries after `updatesScheduleDelay` (30 seconds
  by default), including when the helper is invoked by a post-transaction hook.
  Locks are checked again after queries and before publication. The helper uses
  `C.UTF-8` for English package fields and Qt IPC without locale warnings.
  See the helper's comments for cron and pacman hook examples.
  In the installed hook's `Exec`, use `sudo -H -u pncolvr --` instead of
  `sudo -u pncolvr -i`: `-H` sets the user's home without loading the zsh login
  profile, which starts an SSH agent and prints `Agent pid ...`. Script comments
  do not update `/etc/pacman.d/hooks/95-quickshell-updates.hook` automatically.
- The temperature command reads `/sys/class/thermal/thermal_zone1/temp`.
- `calendarEventUrl` opens Google Calendar. `mixerCommand` opens `pavucontrol`.

Helper commands resolve relative to the configuration source. Persistent data
resolves from the shell root, so `data/quickshell.db` stays outside `src/`.

## Project apps

`projectApps` maps literal file extensions to app definitions in one ordered
array. Each app has a unique `id`, display `name`, `extensions`, a `command` argv
array and an `arguments` array. The first extension match wins, without case
sensitivity. `projectDefaultApp` selects the fallback app for folders with no
included matching files; it defaults to `code`.

Defaults associate `.code-workspace` with Code and `.godot` with Godot:

```qml
readonly property string projectDefaultApp: "code"
readonly property var projectApps: [
    {id: "code", name: "Code", extensions: [".code-workspace"],
        offerFolder: true, useFileNames: true, command: ["code"],
        profiles: {work: "Work", personal: "Personal"},
        arguments: ["{path}"], profileArguments: ["--profile", "{profile}"],
        windowClass: "code", windowTitlePrefix: "{folderName}"},
    {id: "godot", name: "Godot", extensions: [".godot"], command: ["godot"],
        arguments: ["--editor", "{path}"],
        folderArguments: ["--editor", "--path", "{path}"]}
]
```

A single action opens directly. Godot-only projects open in Godot; plain folders
open in the default app. Mixed projects show all included file actions. An app
with `offerFolder: true` also offers **Open in App name** for the project folder
when one of its file types is detected. Code uses this for workspace projects.
`useFileNames: true` labels file actions with their scanned names (Code workspaces);
other file actions use **Open in App name**, adding relative paths if needed to
distinguish multiple files. `folderArguments`, when present, replaces `arguments`
for folder actions. `profileArguments` are appended only while work mode is enabled;
keep profile selection flags there so disabling work mode uses the app default. **Open in …** actions appear first, sorted alphabetically;
named file actions follow, also sorted alphabetically.

Add an app/extension rule and refresh the affected source in Manage. Command or
name changes apply to saved files without rescanning. Removing a matching rule
hides its file actions; the next refresh updates the saved file list. Inclusion
choices and remembered selections survive, including existing workspace choices.

| Placeholder | Value |
| --- | --- |
| `{path}` | Selected folder or project-file path |
| `{project}` | Owning project folder |
| `{directory}` | Selected folder, or the file's parent directory |
| `{name}` | Project display name |
| `{folderName}` | Basename of `{directory}` |
| `{profile}` | Selected app's `profiles` entry for the project category, falling back to the category |

Optional `profiles` maps project categories to app-specific profiles. Code maps
`work` to `Work` and `personal` to `Personal`; each other app can provide its own
mapping when using `{profile}`. Without a mapping, `{profile}` uses the category.

Arguments remain separate strings, including paths containing spaces or shell
characters; commands do not run through a shell. Optional `windowClass` and
`windowTitlePrefix` focus an existing matching window before launching. Code
retains its existing matching; other apps launch normally unless configured.

`projectFileExclusions` applies to every type. Its defaults exclude Code
configuration directories, generated `.godot` directories and Git metadata.
Godot's project entry is normally `project.godot`, distinct from its generated
`.godot` directory; see the [Godot CLI documentation](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html#setting-the-project-path).

## Optional Twitch module

`twitchEnabled` defaults to `true`. Disable it to hide the icon and deactivate its
shortcut, polling, browser suggestions and alerts while retaining saved channels
and cached data. Config reload applies the choice. See [Twitch](features/twitch.md).

## Panels and search

See the [panel behavior reference](features/panels.md) for the shared interaction rules.

Search matches streamer logins, categories and stream titles as you type, and
temporarily expands Offline to show matching results. TOTP searches token names;
notification Emitters searches names and desktop IDs above the policy filters.
Each search has a clear button and resets when its panel closes. Adding a streamer
or token temporarily hides search and suspends filtering, then restores the query.
Hovering any bar module opens its panel without taking keyboard focus. Left-click
pins or unpins it, and a pinned icon uses the accent color. Leaving an unpinned
icon, panel and its popups dismisses it after `tooltipHideDelay`; another module
can replace it. Search text does not retain a panel. Real form fields declare
`retainPanelWhileEditing`, protecting their owner only while the field and window
are active. Losing focus, saving or cancelling releases that protection.

Native child dialogs temporarily retain their owner and release its keyboard
focus/grab. Accepting or cancelling releases the hold and restores the appropriate
input, without changing manual pinning. Bar panels then re-evaluate hover;
launchers stay open. Escape goes to an editor or popup first, then closes the
focused panel. Unfocused hover panels never intercept another app's Escape.
Explicit launcher or bar-shortcut invocation activates the input/root without
moving the pointer. Pinning is always a manual action.

## Animation policy

Set `animationsEnabled: false` to disable decorative UI motion. It defaults to
`true`. All UI animation decisions come from `UI.MotionPolicy`; the master switch
settles active transitions immediately and stops decorative effects.
`animateDuringScreenShare` defaults to `false`; enabling it allows decorative
motion during sharing, subject to the master switch.

Compositor animations are owned by `HyprlandEventsService`, independently of UI
motion. `hyprlandAnimationsEnabled` is authoritative: animations run only when it
is `true` and no screen share is active. Changing it in Config.qml applies on bar
reload/restart; ending a share restores the current configured value. Capture
discovery must be ready before synchronization. There is no SQLite override,
animation IPC setter or separate state file. The companion Hypr configuration
has no Meta+X animation binding.

Status indicators have independent Config switches, all enabled by default. They
continue animating with the master switch off and during screen sharing:

| Config switch | Status animation |
| --- | --- |
| `screenSharePulseEnabled` | Active screen-sharing indicator |
| `recordingPulseEnabled` | Screen-recording indicator, including finalization |
| `notificationBorderAnimationEnabled` | Notification lifetime border |
| `micPulseEnabled` | Muted microphone with an active audio request |
| `volumePulseEnabled` | Muted output with an active audio request |

Disable any of these individually to stop its animation. Existing visibility,
manual pinning and audio activity conditions still apply. Functional clocks,
notification expiry, input handling and data updates continue with motion disabled.

`Theme.panelOpenDuration` (150ms), `panelCloseDuration` (100ms) and
`panelResizeDuration` (160ms) control shared top-panel motion.
`clipboardLayoutDuration` inherits `panelResizeDuration`.

## Shell provider configuration

`Config.providerEnvironment` projects the component settings into one explicit
process-environment object. `launcher.sh --provider-config` obtains it from
launcher IPC, or runs `provider-config.qml` headlessly when the bar is offline.
Both use the same Config definition. The launcher validates the keys and values; the common shell loader then exports
them without evaluating shell expressions. Private FIFO
requests are removed when the export completes or fails. No configuration cache
or database setting is created.

This preserves startup wallpaper restoration and direct screenshot commands
before the bar is running. Edit the component properties above, rather than
provider `.env` files or exported environment variables. Normal bar reloads apply
Config changes online; offline exports read the current file on every invocation.

## Shared controls

Twitch and TOTP use shared `UI.ActionButton` and `UI.InputField` controls. Shared
action glyphs such as add, cancel, delete, and check are defined once in `Theme.qml`.

TOTP and the notification manager reuse `src/bar/PrivateTooltipWindow.qml` for
their monitor selection, positioning, keyboard focus, and private layer namespace.
`UI.WindowFocusHandler` shares activation, native-child handoff and outside-click
policy with launchers and Vault; `UI.PanelFocusScope` supplies the outer Escape
fallback. `UI.FolderDialog` shares native folder selection and path decoding.
Both modules declare `ownsTooltipWindow`, so the shared tooltip window leaves
their content to the dedicated window without checking module names.

Feature guides describe the individual controls and settings:
[notifications](features/notifications.md), [Twitch](features/twitch.md),
[TOTP](features/totp.md), [audio](features/audio.md), [batteries](features/batteries.md).
Recent-file source and limits are described in [recent files](features/recent-files.md).
Mode detection, timetable commands, and reports are described in
[status and timecard](features/status.md).

[Documentation](README.md)

## Remotes

Managed host names, endpoints, credentials, categories and literal RDP arguments
live in SQLite and are covered by encrypted backups. There is no hosts JSON file.
`remoteRdpCommand` selects the FreeRDP 3 client; it must support `/args-from:stdin`.
`remoteSshCommand`, `remoteVmCommand` and `remoteProbeCommand` select SSH, libvirt
and a netcat-compatible readiness probe. Commands are literal argument arrays.
`remoteVmWaitSeconds` bounds VM readiness waiting (1–300 seconds).
`remoteRdpArguments` supplies initial arguments for newly created records; changing
it does not overwrite existing records. SSH key paths belong to their managed host.
SSH uses configured keys/agents in batch mode rather than prompting in a hidden terminal.

## n8n

Use n8n's Manage tab for multiple private instance connections: address, API key,
browser/profile, enabled state and Personal/Work category. Connections and each
instance's cached workflow list are stored in SQLite and encrypted backups.
Browser commands and available profile choices reuse `Config.webappBrowsers`;
work filtering reuses `pickerWorkStatus`. No API key or instance address belongs
in public Config, provider JSON or environment files. Refresh is explicit only.
