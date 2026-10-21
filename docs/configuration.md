# Configuration

## Files to edit

| File | Controls |
| --- | --- |
| [`src/config/Config.qml`](../src/config/Config.qml) | Commands, intervals, defaults, namespaces and feature settings |
| [`config/Theme.qml`](../config/Theme.qml) → [`src/theme/Theme.qml`](../src/theme/Theme.qml) | Fonts, glyphs, colors, dimensions and spacing |
| [`config/ThemePalette.qml`](../config/ThemePalette.qml) → [`src/theme/ThemePalette.qml`](../src/theme/ThemePalette.qml) | Dark/light palette colors and contrast policy |
| [`src/ui/bar/LeftModules.qml`](../src/ui/bar/LeftModules.qml) | Workspaces and windows |
| [`src/ui/bar/CenterModules.qml`](../src/ui/bar/CenterModules.qml) | Clock, package updates and recent files |
| [`src/ui/bar/RightModules.qml`](../src/ui/bar/RightModules.qml) | System, Twitch, status, TOTP, batteries, notifications and tray |
| [`shell.qml`](../shell.qml) | Entry point, startup environment and dedicated windows |

The root `config/` link exposes `Config.qml` and relative links to `Theme.qml`
and `ThemePalette.qml` under `src/theme/`. Editing either path updates the same file; both QML
modules export the same singleton. Reusable UI components remain under `src/ui`.
Bar composition, including `Bar.qml`, lives in `src/ui/bar/`. Shared top-panel
surfaces, tooltip windows and handlers, alerts and the submap window live in
`src/ui/panels/`.

`Config.qml` groups settings by component: shared UI/privacy and storage;
launcher pickers, projects, directories and wallpapers; screenshots/recording;
clipboard; Hyprland;
calendar/timers; package updates; status/timecard; notifications; recent files;
audio/media; network/statistics/power; batteries; Twitch/browser sessions; and TOTP.

## Optional modules and integrations

The switches are grouped immediately below `language` at the top of
`config/Config.qml`. Review this block before first launch. Personal overrides and different clone defaults
have not been introduced.

| Setting | When false |
| --- | --- |
| `adaptiveBarEnabled` | Keep the fixed palette and continuous bar; unload the optional color sampler |
| `bookmarksEnabled` | Hide/disable the Bookmarks picker and skip bookmark-file reads |
| `browserRoutingEnabled` | Enable browser routing and the Bookmarks History/Manage tabs; enabled in this setup |
| `clipboardMonitorEnabled` | Stop automatic history collection; existing history remains available |
| `workModeEnabled` | Stop work detection/tracking and remove category filters; retain saved data |
| `statsNetworkEnabled` | Hide Stats Network and stop bandwhich sampling; retain Overview totals, CPU and Memory |
| `batteriesEnabled` | Hide Batteries and stop collection/receiver scans; retain cached readings |
| `updatesEnabled` | Hide Updates and stop Quickshell checks, refreshes and scheduled retries; retain the external update cache |
| `recentFilesEnabled` | Hide Recent Files and stop history/folder scans and pin checks; retain pins, folders and preferences |
| `twitchEnabled` | Disable Twitch UI and module work; retain saved channels/cache |
| `twitchQutebrowserEnabled` | Skip Twitch browser-session suggestions; other Twitch features remain available |
| `hyprlandHideApplicationsEnabled` | Skip the custom `HideApplications(...)` helper; still synchronize compositor animations |
| `vaultEnabled` | Disable Vault management; password prompts and explicitly installed browser autofill remain independent |
| `totpEnabled` | Disable TOTP UI/module work; full-state backup/restore still includes tokens and needs the TOTP tools |

`updatesEnabled` and `recentFilesEnabled` default to `true`. Disabling either
closes its panel and makes its bar shortcut inactive. Updates stops its own
checks and retry timer; separately installed cron jobs, pacman hooks and manually
invoked `update-check.sh` still run independently. An installation already opened
in a terminal continues. Recent Files stops history/folder scans and pin checking
without deleting its saved pins, folder tabs, aliases or default tab. Shared
directory pickers and other file-opening features remain available.

Without the custom capture helper, this configuration does not install or toggle
compositor privacy rules. Review the [sample Hypr Lua code](setup.md#screen-sharing)
before enabling it. Screenshot/recording control closure uses the separate
per-panel `hideForCapture` policy; this switch does not change that policy.

## Adaptive bar and panel backgrounds

With `adaptiveBarEnabled`, the bar samples the most common color
of a narrow strip below each monitor's bar. Hyprland's configured border size and
visible window geometry move the strip below horizontal borders it would cross.
Border size is read at startup and compositor configuration reload; window
geometry updates follow the existing window model. Workspace, focus and
window-layout events request a new sample; requests are coalesced on the next
event-loop turn without a fixed capture delay. There is no continuous capture loop.
The bar, its panels and launcher previews share that monitor's approved color.
Unreadable colors, missing capture tools and capture failures use the configured
theme background. Color animation follows the shared motion and screen-sharing
policy. Samples stay in memory; no screenshots or color history are saved.
Contrast checks include visible bar and panel labels; hidden urgent indicators
and deliberately dim decorative markers do not reject otherwise readable colors.
Media visualizers are excluded from the text-contrast scan, so their animation
does not repeatedly rescan the panel. Media-card labels remain checked.

Empty workspaces and workspaces with only floating windows use three palette-
colored islands. The left island rounds its bottom-right corner, the middle
rounds both bottom corners, and the right rounds its bottom-left corner. The bar
keeps its reserved height; transparent gaps pass pointer input to the desktop.
An open panel adds matching backing behind the bar across its own width, so a
panel wider than its island still has a continuous attachment. In island mode,
panels have straight top edges and rounded bottom corners. Sampling pauses
while Quickshell panels or notifications could cover the strip and resumes after
they close, retaining the last accepted color meanwhile.

Install `grim` and `imagemagick` for sampling. `Theme.adaptiveBarSampleHeight`
sets the strip height (12 logical pixels), and `Theme.adaptiveBarColorDuration`
sets color-transition duration (100 ms). `adaptiveBarSampleCommand` is the
capture/color helper command; disabling the feature unloads its sampler.
Run `qs ipc -p . call adaptivebar status` from the repository to inspect each
monitor's sampled color, chosen background and sampling status.
The result also includes the detected border size and logical capture region.
This skips compositor horizontal borders, not application-drawn title bars or
vertical border columns. If the border query fails, sampling uses a zero-border
fallback. Per-window border-size overrides are not exposed by the client snapshot;
placement uses the global size and reported content rectangles.

## Display language

Set `Config.language` in `config/Config.qml` to `"system"` (default) or a catalog
filename without `.json` from `src/i18n/languages/`: `"en"` (English), `"pt"`
(European Portuguese), `"es"` (Spanish), or `"fr"` (French).
System mode reads Qt's default locale once, tries a matching regional catalog,
then its base language, and falls back to English. There are no locale
subprocesses or polling. A changed system locale may require restarting Quickshell. Editing the
Config override applies through the normal config reload.

All shell-owned wording comes from the shared `Translations` singleton and the
public catalogs in `src/i18n/languages/`. Each filename is a language key in the
catalog dictionary; adding a language requires no loader changes. Optional
`$locale` metadata controls date/number formatting (`en_GB`, `pt_PT`, `es_ES`, and
`fr_FR` in the shipped catalogs). Missing messages fall back to English. Catalogs use stable
semantic identifiers, independent of wording. Complete messages own their placeholders and singular/plural forms.
Calendar month and weekday names live in these catalogs, rather than Theme;
weekday highlighting uses numeric indexes. Theme still owns calendar styling.

User-entered names, paths, browser profiles, application names, notification/OCR
content and output from external tools stay unchanged. Action IDs, command
arguments, stored categories and the internal time-report grammar remain
independent of the selected language. Detached workers return semantic diagnostics;
Quickshell translates them using its current language.

## Panel keybinds

`Config.keybinds` groups in-panel shortcuts by action. Desktop shortcuts that
open modules, including Alt+Tab, remain in Hypr. These are the defaults:

| Group | Actions and bindings |
| --- | --- |
| `common` | `cancel`: Escape; `add`: Ctrl+N; `edit`: Ctrl+E; `save`: Ctrl+S; `copy`: Ctrl+C; `refresh`: Ctrl+R; `search`: Ctrl+F |
| `common` | `manage`: Ctrl+M; `workFilter`: Ctrl+W; `nextTab`: Ctrl+Tab; `previousTab`: Ctrl+Shift+Tab; `preview`: Ctrl+Shift+I |
| `clipboard` | `pin`: Ctrl+P; `pinnedOnly`: Ctrl+Shift+P; `delete`: Delete |
| `vault` | `lock`: Ctrl+L |
| `remotes` | `runningOnly`: Ctrl+Shift+R; `shutdown`: Ctrl+Shift+S |
| `audio` | `mute`: Ctrl+Shift+M |
| `notifications` | `dnd`: Ctrl+Shift+D |
| `media` | `previousPlayer`: Left; `nextPlayer`: Right; `closeWindow`: Alt+F4 |
| `expose` | `all`: Ctrl+Shift+A; `workspace`: Ctrl; `move`: Ctrl+Shift |
| `selection` | `toggle`: Shift+Space; `all`: Ctrl+A; `clear`: Ctrl+Shift+A |

Edit a binding in the corresponding group, for example `refresh: "F6"`.
An empty string disables that action's shortcut. Use single key combinations
with Qt names such as `Ctrl+Shift+R`; Exposé's workspace and move settings are
modifier prefixes for its existing workspace keys. Choose distinct bindings for
actions available in the same panel. Action hints and tooltips follow the
configured bindings in both languages.

Shortcuts act only in the active owning panel and respect disabled actions,
native child dialogs and selection popups. Standard field editing remains
native, including Ctrl+A for Select all and Left/Right for cursor movement.
Multi-selection Ctrl+A applies when the result list has focus. Tab/Shift+Tab,
list arrows and Enter/Space activation keep their normal control behavior.
`common.cancel` controls app-owned cancel, back and close actions, including
fullscreen media, search clearing and selection popups. It defaults to Escape;
an empty string disables it and hides its hints. Popups/editors handle it before
the outer panel. Native system dialogs retain their platform shortcuts. The old
`media.exit` entry is replaced by this shared binding.

## Panel footer hints

`Config.panelHints` contains ordered action-ID lists, one per panel/context.
It selects what to display; translations remain in `src/i18n/languages/`,
and shortcut bindings remain in `Config.keybinds`. Reorder IDs to
change their display order. Use `[]` for no hints and no empty footer row.
Explicit lists may contain more than three items; Vault uses four. Unsupported
actions and disabled bindings are omitted. Routine Enter/Escape/opening
instructions are excluded from the defaults.

| Context | Default IDs |
| --- | --- |
| `clipboard` | `clipboard.pin`, `clipboard.pinnedOnly`, `preview` (Images) |
| `manage` | `edit`, `add`, `refresh` where supported |
| `editing` | `save` |
| `vault` | `edit`, `add`, `refresh` (Sync), `vault.lock` |
| `projects` | `selection.toggle`, `selection.clear` in multiple-selection mode |
| `remotes` | `remotes.runningOnly`, `remotes.shutdown` when available |
| `multiple` | `selection.toggle`, `selection.clear` |
| `expose` | `expose.all`, `expose.workspace`, `expose.move` |
| `windows` | `preview` |
| `default`, `webapps`, `n8n`, `directories`, `wallpaper`, `files` | None |

Additional supported choices include Clipboard `copy`/`clipboard.delete`,
Manage `search`/`manage` (return to list), Vault `search`, window-switcher
`search`/`windows.previous`, Wallpaper `copy`, and Recent Files
`files.multiple`/`files.drag`/`selection.all`. Collection list contexts also
support `manage`, `search` and `workFilter` where work mode exists. Existing
button guards still apply to shortcuts: VM shutdown requires a selected running
VM, and Vault lock is blocked while busy.

## Stats Network tab

`statsNetworkEnabled` defaults to `true`. Set it to `false` to hide Stats’ Network
tab and stop its `bandwhich` sampling. Disabling it while selected returns to
Overview. Overview's download/upload totals, CPU and Memory stay available;
`bandwhich` is required only when the Network tab is enabled.

## Launcher defaults

Project and directory pickers inherit `pickerManageShortcut`, `pickerAddShortcut`,
`pickerShowAllShortcut` and `pickerWorkStatus` from the shared picker section.
Changing a shared default updates both pickers. Each feature retains its own
setting and can override the shared value:

```qml
readonly property string pickerManageShortcut: keybinds.common.manage
readonly property string projectManageShortcut: pickerManageShortcut
readonly property string directoryManageShortcut: "Alt+M"
```

Recent-file and qutebrowser session paths share the private `_internal.dataHome`
helper, which honors `XDG_DATA_HOME` and falls back to `~/.local/share`. Their
full-path settings remain individually editable. Equal durations and limits with
different purposes remain independent.

## Bookmarks

`bookmarksEnabled` controls the launcher (true in this setup). When false,
opening requests do nothing, its own open picker closes, and the source is not
read. An empty `bookmarkFile` disables the launcher unless routing is enabled,
which keeps History/Manage available without a bookmark source. Other open panels are
preserved. `bookmarkFile` accepts any plain text file containing one URL and an
optional title per line, separated by whitespace. In this setup it points to
`~/.config/qutebrowser/bookmarks/urls`.
`browserOpenCommand` is shared by Bookmarks and Project URLs, using the browser
selected by `defaultBrowserId` and `browsers`. These actions open a browser,
including for local HTML targets. With routing enabled, they use the shared
router instead. The opener remains an overridable literal argv array. Bookmark contents
stay in the local file; use encoded file URLs for paths containing spaces in
that source, or type an absolute path into the picker. HTML is opened, not parsed.

## Copy feedback

Copy buttons show a checkmark, active color and Copied tooltip after a successful
clipboard write. `copyFeedbackDuration` controls the confirmation duration in
milliseconds (2000 in this setup), including TOTP. Changing the copied row or
hiding a button clears its local confirmation.

## Browser routing

`browserRoutingEnabled` is enabled in this setup. It adds Bookmarks / History /
Manage tabs and activates routing for generic URLs. The default browser always
comes from `Config.defaultBrowserId`; Manage edits ordered rules using the
browser definitions below. Twitch links, saved Twitch notification actions,
calendar events and package pages use this same opener directly. They do not
require the desktop integration or default-browser associations. With routing
disabled, they open the configured browser without routing or history.
Ordinary browser/application links dispatch independently of pending URL
transformations, so a slow redirect does not hold up those links. Redirect/query
requests retain their bounded, sequential transformation queue.
Host/subdomain, literal Contains, wildcard and
regular-expression patterns match rules. Contains accepts one value per line and
matches when any value occurs in the URL. Each
rule opens a browser, follows redirects, unwraps a named query parameter or runs
a literal application command. Transformations re-evaluate the resulting URL;
the first matching terminal action in the displayed list order wins. Use the
Move up / Move down buttons in Manage to change that order. New rules append to
the end, and their order is saved. History can prefill a new rule.
Explicit Webapp/n8n browser choices remain authoritative and bypass routing.

`browserHistoryEnabled` defaults to `true`, and `browserHistoryLimit` to `100`
distinct URLs. Recording occurs only while routing is enabled. SQLite FTS5 indexes
history searches. Disabling recording retains existing history for viewing/removal;
reducing the limit prunes older rows, and zero clears/stops history. Rules and
history are included in encrypted backups.

There are no built-in domain/application URL handlers. Configure redirect and
query-unwrapping actions in Manage. Application rules accept literal argv with
`{url}` and numbered regex captures (`{1}`, `{2}`, …), plus an optional
running-application checkbox. When checked and the process is absent, the
matching browser rule/default is used. Manage can select an installed desktop application and optional extra
arguments instead of entering a command. A missing desktop entry or executable
opens the URL in the configured default browser and posts an alert naming the app.
Redirect requests are bounded, and URL transformations stop after eight
steps or a detected cycle. Unchanged transformations continue through other rules.

`browserWorkspaceFocusEnabled` is enabled in this setup. When enabled, terminal rules
use their workspace number and respect the existing runtime `hypr-autofocus`
toggle. See the [editable rule examples](../integrations/browser/README.md#rule-examples)
for Microsoft wrappers and Steam; these examples are not loaded automatically.

The optional [desktop integration](../integrations/browser/README.md) includes a
desktop entry, installer and explicit default-browser commands. Installation does
not change associations. When disabled or unavailable, the handler opens a concrete
fallback without routing/history. `defaultBrowserCommand` derives from the
configured default browser; avoid `xdg-open` as a router destination to prevent
recursion.

## Shared browsers

`defaultBrowserId` selects the browser ID for new Webapps and n8n entries
and their shared Browser fields. This setup explicitly selects `"qutebrowser"`;
choose another concrete browser ID from `browsers`. The default always comes
from Config. The `"default"` definition uses `xdg-open` and remains available for
explicitly configured Webapp/n8n entries; do not use it as `defaultBrowserId`,
because routing and direct fallback require a concrete browser.
Saved entries and active drafts keep their browser IDs; changing the default
only affects new entries. Removing a browser definition does not migrate saved
entries: edit their Browser choice before launching them again.

`browsers` follows the configurable application pattern: each item has an
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

Webapps, n8n, Remotes, Projects and Directories share `Theme.pickerHeight`
(450 logical pixels) for their list views. Empty results and Work/Running-only
filters keep that height; additional rows scroll inside the list. Window sizing
still respects the available screen space. Manage views use `Theme.manageHeight`.

Image-based picker previews use a separate larger window below the standard list.
`Config.pickerPreviewEnabled` sets the shared initial state (false by default).
In `Config.pickerPreviewDefaults`, `clipboard` and `windows` default to `null`
(inherit). Set an entry to a boolean to override the global default, or to `null`
to inherit it. Wallpaper always shows its preview and has no off setting.
Manual preview toggles
apply to the current opening. Clipboard's Images only action retains its combined
image filter/preview behavior. Wallpaper uses `keybinds.common.copy` (Ctrl+C)
to copy the selected original image without closing either window.

`Config.pickerPreviewMaxRows` limits preview-mode lists to four entries; other
entries remain scrollable and closing the preview restores `pickerMaxRows`.
`Theme.pickerPreviewWidth` caps preview width at 1600 logical pixels, bounded to
the screen with room for its shadow. `Theme.pickerPreviewListHeightRatio` adds a
32% screen-height safety ceiling on smaller screens. `Theme.pickerPreviewGap`
sets the minimum spacing above and below the preview. Both visible gaps use the
same margin, increased together when needed to fit shadows and closing motion.
Image previews shrink vertically to fit the image within the available height,
with smaller top/bottom padding and larger side padding. The remaining outside
space is split equally above and below the preview. Its center stays fixed when
image dimensions change, including during resize animations.
Dimensions use Qt logical coordinates; image decode sizes follow display scale.

`config/Theme.qml` exposes one palette toggle:

```qml
readonly property bool darkMode: true
```

Set it to `false` for the similar light palette. The existing configuration reload
applies the change; there is no separate picker, database preference or Config.qml
switch. Fonts, icons, dimensions and motion controls keep their existing settings.

Shared text, icons and input controls use `Theme.textRenderType` (default
`Text.NativeRendering`) and `Theme.fontHintingPreference` (default
`Font.PreferFullHinting`). Configure both in `config/Theme.qml`. Full hinting
applies with native rendering; changing these defaults can affect text metrics.

`config/ThemePalette.qml` holds the dark/light color definitions and foreground
contrast policy. The dark defaults preserve the original colors, including alpha.
Edit its palette entries to customize colors, or override a specific Theme property
with a literal as before. Every component reads colors through Theme; only the
Theme implementation selects a palette. Shared filled controls use
`Theme.foregroundOn(surface)`, while selected text uses `Theme.selectionText`.
Calendar highlight text and notification colors also come from Theme. Functional
black/white used by QR images, image masks and shader inputs stays independent.


`Theme.qml` groups appearance settings by component and keeps rendering state in
shared UI utilities. Pulse timing lives in `src/ui/PulseClock.qml`; calendar
color selection belongs to the month view used by month/year calendars.

Feature properties can inherit shared defaults while retaining their own names:

```qml
readonly property int tooltipWidth: 420
readonly property int statsTooltipWidth: tooltipWidth
```

Changing `tooltipWidth` updates timers, stats and status panels together.
`tooltipMinHeight` sets the minimum height of bar hover panels (200 px), including
private TOTP and notification panels. It is bounded by the monitor height after
reserving room for the bar and shadow. Content stays top-aligned, and taller
panels retain their natural height. This gives combobox popups room inside the
panel even when its contents are short. The
`tooltipMaxHeightRatio` and `tooltipCompactMaxHeightRatio` defaults group the 60%
and 50% tooltip limits. `rotateIcon` supplies retry/media-flip glyphs, and the
network up-arrow inherits `upIcon`. Calendar cell and tray icon heights default
to their widths. Assign a literal to a feature property to override that default.
Equal numbers with unrelated purposes remain separate settings.

## Desktop integrations

Review these defaults when adapting the configuration:

- `workModeEnabled` controls native work/personal detection, tracking and shared category UI.
  Automatic detection follows window/focus events and refresh requests; it does not poll on a timer.
  Clicking a mode pins it manually; clicking that same manual mode again returns
  to automatic detection. Selecting the other mode switches the manual override.
  Manual mode stops detection checks and cancels any running scan. Returning to
  automatic mode runs a fresh check; time tracking continues in either mode.
- `workHistoryRetentionMonths` sets stored work/personal history retention in whole calendar months (default `36`; positive integers only). Cleanup runs at startup and hourly, trimming sessions that cross the cutoff. The History picker follows actual stored records.
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
  The panel's refresh button, immediately left of Install updates, offers
  “Check now”. It clears the pending retry
  timer and starts the configured refresh helper immediately, even if the cached
  connectivity status is offline. The button is disabled while a check runs;
  repeated service requests reuse that check. A new failure or package-database
  lock can still schedule the normal retry afterward.
  See the [integration templates and installation instructions](../integrations/README.md#arch-updates)
  for cron and pacman hooks. Fill in your username and absolute checkout path.
  The hook uses `sudo -H -u` to set the user's home without loading a login
  profile. Updating repository templates does not update installed copies.
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

## Optional TOTP and Vault modules

`totpEnabled` and `vaultEnabled` both default to `true` and can be set
independently. Setting `totpEnabled` to `false` hides its bar icon, prevents its
panel from opening and stops its token worker. Setting `vaultEnabled` to `false`
disables the Vault manager and its opening actions. Config reload applies these
settings; disabled modules do not load their panel windows.

Stored tokens and Vault entries are preserved. Vault password prompts and browser
autofill remain available independently of the manager. Full-state backups still
include and restore TOTP tokens when its module is disabled, so those operations
still require the configured TOTP/keyring tools. See [TOTP](features/totp.md),
[Vault](features/rbw.md) and [backups](storage.md#backups).

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
launchers stay open. The configured cancel key goes to an editor or popup first,
then closes the focused panel. Unfocused hover panels never intercept another
app's cancel key.
Explicit launcher or bar-shortcut invocation activates the input/root without
moving the pointer. Pinning is always a manual action.

## Fullscreen media artwork

`mediaFullscreenArtworkStyle` selects `plain` (the current artwork), `cassette`
(artwork printed on a cassette label), `cd` (a jewel case with a ribbed spine),
or `disc` (round printed artwork with a metallic rim/hub and transparent centre hole).
It defaults to `plain`; unknown values also use `plain`. This changes only the
fullscreen artwork decoration. Compact cards, playback controls and visualizer
behavior keep their existing settings. Reload the bar after editing Config.

The native Hyprland action `quickshell:media-fullscreen` opens the first playing
player, or the first available player when none is playing, on the focused
monitor. It needs no open media panel. Bind it in your tools submap; Escape
retains its existing close behavior.

## Animation policy

Set `animationsEnabled: false` to disable decorative UI motion. It defaults to
`true`. All UI animation decisions come from `UI.MotionPolicy`; the master switch
settles active transitions immediately and stops decorative effects.
`animateDuringScreenShare` defaults to `false`; enabling it allows decorative
motion during sharing, subject to the master switch.

`mediaVisualizerEnabled` defaults to `true` and independently controls media-card
and fullscreen visualizers, including audio analysis and shader animation. They
can run with general UI motion disabled and during screen sharing. Set it to
`false` to stop visualization. Card flips and fullscreen transitions still follow
the general animation policy.

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

TOTP and the notification manager reuse `src/ui/panels/PrivateTooltipWindow.qml` for
their monitor selection, positioning, keyboard focus, and private layer namespace.
`UI.WindowFocusHandler` shares activation, native-child handoff and outside-click
policy with launchers and Vault; `UI.PanelFocusScope` supplies the outer configured-cancel
fallback. `UI.FolderDialog` shares native folder selection and path decoding.
Both modules declare `ownsTooltipWindow`, so the shared tooltip window leaves
their content to the dedicated window without checking module names.

Feature guides describe the individual controls and settings:
[notifications](features/notifications.md), [Twitch](features/twitch.md),
[TOTP](features/totp.md), [audio](features/audio.md), [batteries](features/batteries.md).
Recent-file source and limits are described in [recent files](features/recent-files.md).
`recentFileOpenCommand` defaults to `["gio", "open"]` for desktop-default file
activation; the selected file URI is appended as one argument.
Mode detection, timetable commands, and reports are described in
[status and timecard](features/status.md).

[Documentation](README.md)

## Remotes

Managed host names, endpoints, credentials, categories and literal RDP/SSH arguments
live in SQLite and are covered by encrypted backups. There is no hosts JSON file.
`remoteRdpCommand` selects the FreeRDP 3 client; it must support `/args-from:stdin`.
`remoteSshCommand`, `remoteVmCommand` and `remoteProbeCommand` select SSH, libvirt
and a netcat-compatible readiness probe. Commands are literal argument arrays.
`remoteVmWaitSeconds` bounds VM readiness waiting (1–300 seconds).
`remoteRdpArguments` supplies initial arguments for newly created records; changing
it does not overwrite existing records. SSH key paths belong to their managed host.
RDP tunnels use configured keys/agents in batch mode rather than prompting in a
hidden terminal.

SSH terminal entries have separate destination and optional jump-host ports,
usernames, passwords and key paths. Their default port is 22. Blank usernames
and keys use SSH configuration/agent defaults. Passwords are optional and masked;
OpenSSH askpass reads saved passwords from the existing database and returns them
through a pipe. Missing passwords, key passphrases and host-key confirmation are
prompted in the terminal. No sshpass dependency is required.

`remoteTerminalCommand` is a literal command prefix. Its default is
`["ghostty", "--gtk-single-instance=false", "--quit-after-last-window-closed=true", "-e"]`;
the SSH session command is appended. A configured terminal must keep its process
alive for the session and use a separate instance, so Disconnect cannot close
unrelated terminal windows. SSH arguments are separate from RDP arguments;
connection-field overrides, multiplexing controls and background detachment are
rejected to preserve session ownership. See [Remotes](features/launcher.md#remotes).

## n8n

Use n8n's Manage tab for multiple private instance connections: address, API key,
browser/profile, enabled state and Personal/Work category. Connections and each
instance's cached workflow list are stored in SQLite and encrypted backups.
Browser commands and available profile choices reuse `Config.browsers`;
work filtering reuses `pickerWorkStatus`. No API key or instance address belongs
in public Config, provider JSON or environment files. Refresh is explicit only.

## Optional battery and browser integrations

`Config.batteriesEnabled` defaults to `true`. Disabling it hides the Batteries
module, closes its tooltip and stops battery collection and receiver scans,
while retaining cached readings.

Enable `Config.twitchQutebrowserEnabled` to show Twitch
channel suggestions from qutebrowser's saved sessions. When off, no session-file
reader or suggestion refresh timer runs. Other Twitch features remain available;
`Config.twitchEnabled` controls the Twitch module independently.

Qutebrowser is optional: disable Twitch session suggestions, disable Bookmarks
or select another plain-text source, choose another `defaultBrowserId` and
remove its definition from `browsers` if unused. Existing entries must use
a remaining browser ID. Browser autofill userscripts/bindings are an optional
browser-side installation; Vault and password prompts do not require them.
