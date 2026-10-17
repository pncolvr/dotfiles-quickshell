# Launcher and clipboard

The launcher uses the same theme, search field, buttons and scrollbar as the bar.
Clickable rows, buttons and scrollbars show a pointing-hand cursor. It opens on
the focused monitor, centered horizontally and attached below the bar with the
same curved joins and shadow as tooltips. List and power-grid launchers temporarily
raise the bar on their monitor above fullscreen applications; closing restores
the bar's normal layer. These modes use `Theme.pickerWidth` (clamped on small
screens). The search field stays at the same horizontal position and
height across picker modes. Launchers take keyboard focus without moving the pointer,
and close with Escape or an outside click. This includes webapps, clipboard menus,
multi-step prompts, image viewers and the window overview. A QR/image preview focuses
the image panel itself, so Escape and Enter work with the pointer outside the panel;
no text field or button is needed. `LauncherFocusHandler` shares activation and
outside-click handling across ordinary/private pickers and the overview, using
`UI.WindowFocusHandler`. It activates once, then returns to on-demand keyboard
focus; returning from a native child dialog uses the same controller.
Explicit launcher surfaces request exclusive activation from their first native map,
and prepare the ready input synchronously. Activation returns to on-demand after
the native handoff. Opening motion does not gate keyboard readiness, including in
Exposé. Keys delivered to another application before the compositor transfers
focus cannot be recovered by the launcher.
Legacy JSON `movePointer` fields are ignored and dmenu `--keep-pointer` remains
accepted for compatibility; callers cannot enable pointer movement.
Input-only prompts reserve no empty list row.
Picker headers contain search. Prompt titles are hidden by
default; set `Config.pickerShowPrompt` to `true` to display them below search.
`Theme.pickerBackgroundOpacity` controls background transparency (0–1), keeping
text and controls opaque. Escape dismisses the picker.
The list keeps its opening size while filtering or deleting entries, so the
dialog and footer stay in place.
`PickerPanelBase` shares layout, search and navigation. `ClipboardPickerPanel`
and `MultiSelectPickerPanel` extend it with their own shortcuts and action buttons;
`PickerPanel` loads the appropriate panel. JSON menus with `previewImages: true`
use `ImagePickerPanel` to preview the highlighted row's `image` URL.
Shortcut hints keep each key and action together when wrapping. Project and
directory hints fit one line; GitHub groups its selection shortcuts on separate lines.

## Launcher script responsibilities

| Entry point | Responsibility |
| --- | --- |
| Native Hyprland shortcuts | Dispatch to feature services through one shared `GlobalShortcutRegistry`, without starting a shell or IPC client per keypress. |
| `launcher.sh` | Synchronous dmenu/JSON request and reply protocol, validation, cancellation, provider dispatch and compatibility CLI aliases. |
| `secret_prompt.sh` / `pinentry-rbw` | External password clients, owner tracking and pinentry protocol; secret values remain on private pipes. |
| `provider-config.qml` and `--provider-config` | Shared Config export while the bar is running, plus the existing offline exporter needed by wallpaper restoration. |
| `_common/utils.sh` | Shared provider configuration, temporary directories and external file-manager actions. |
| Bookmarks | BookmarkService reads the existing file and owns selection/opening through the shared native picker. |
| Power | Noninteractive command execution and offline idle locking. PowerService owns the native choices and action order. |
| Screenshot | ScreenshotService owns native choices and capture readiness. The prepared worker owns slurp/grim/hyprpicker, Portuguese OCR/QR decoding and detached Satty save/reveal. |
| Recording | RecordingSetup owns native choices and metadata; RecordingService passes prepared arguments to the detached worker. The obsolete interactive provider is removed. |
| QR encoding | QrEncodeService owns native input/preview; qr-encode.sh encodes and copies PNG data in memory without temporary files or picker IPC. |
| Wallpaper | WallpaperService owns native browsing and mode/output choices. The noninteractive helper discovers files, applies/saves assignments and supports offline restore. |

The detached recording worker and runtime process/database helpers are retained;
they perform independent lifecycle work rather than only forwarding a launcher
command. Moving these workflows into QML is a separate feature change, not required
to remove the native launchers' forwarding overhead.

## Internal dispatch

`PickerService.Mode` identifies the internal modes: `None`, `Menu`, `Projects`,
`Directories`, `Apps`, `Windows`, `Clipboard`, `Secret`, `Webapps`, `Remotes` and `N8n`. Acceptance and panel selection
use switches on that enum; panels and services use the same values for their
mode checks. `begin()` accepts an enum value. IPC command names and provider
request/reply formats stay unchanged; enum numbers are not part of that protocol.

`ProjectService.Operation` identifies scan operations: `None`, `Add`, `Refresh`
and `Discard`. A switch handles completed scans. Cancelling a pending add marks
it as `Discard`, so its results are not applied. These are internal states;
source kinds, categories and scan JSON retain their existing strings.

Use enums for mutually exclusive internal states and switches for dispatch on
one state. Keep conditions for validation, overlapping facts and priority rules,
such as the calendar's day-style resolver. Protocol values can use switches
directly without introducing a duplicate enum and translation layer.

## Commands

```sh
qs ipc call launcher apps
qs ipc call launcher power
qs ipc call launcher windows all
qs ipc call launcher windows current
qs ipc call launcher expose all
qs ipc call launcher expose current
qs ipc call launcher clipboard
```

Applications use native desktop-entry metadata and `gtk-launch`, including terminal
applications. Launches strip the IDE-only `ELECTRON_RUN_AS_NODE` variable so
Electron applications start normally even if the shell inherited it. Rows show only application names. Recent launches are ordered first. Window modes reuse `WindowService`;
Enter focuses a window, Ctrl+Enter focuses without dismissing, and two-window lists
switch immediately to the previous window. Focusing a grouped window activates
its tab using live group membership. Current-workspace mode considers tiled
windows and falls back to all windows if fewer than two are available.

## Bookmarks

Meta+B dispatches `quickshell:launcher-bookmarks` to `BookmarkService`. It reads
`Config.bookmarkFile` (`~/.config/qutebrowser/bookmarks/urls` by default) each time
it opens, using an asynchronous FileView without generating JSON or waiting for
shell replies. The existing shared picker supports sorted titles, search, typed
URLs and multiple selection. A single bookmark opens directly; an empty file
performs no action. Missing/unreadable sources show an error and still allow a
typed URL. Cancelled or replaced menus ignore late file reads.

Each accepted URL is passed as a literal argument to `Config.bookmarkBrowserCommand`,
which inherits `projectBrowserCommand` (`["xdg-open"]`) by default. Projects and
Bookmarks therefore use the desktop's default browser association. The configured command is
launched directly, preserving its arguments and normal inherited environment.
The service assumes no shell configuration directory; any additional environment
setup belongs in the configured command. Selection closes the menu before opening
URLs; Escape opens nothing.

`launcher.sh provider bookmarks` remains a compatibility entry point that invokes
the same native service. The former `bookmarks.sh`, `_common/handle.sh` and unused
URL/named-temporary-file helpers are removed. External JSON/dmenu and secret
request/reply interfaces are unchanged.

## Power menu

Meta+Escape dispatches `quickshell:launcher-power` to `PowerService`. The menu
reuses the normal native picker grid, preserving Reboot, Lock, Logout, Shutdown
and Bios in that order with their existing glyphs. The five `Theme.power*Icon`
properties own those glyphs; reboot inherits `rotateIcon` and lock inherits
`lockIcon`. Search, arrow/Enter navigation,
Escape and outside-click cancellation use the shared picker components. There is
no JSON request file, FIFO or shell process waiting for the choice.

`PickerService.promptMenu(title, rows, callback, presentation, options)` is the shared
native-menu entry point. It normalizes rows through the same helper as external
requests, invokes the selected-row callback after logical closure, and clears the
callback on cancellation or replacement. Optional `allowMultipleSelection`,
`allowTyped`, `sort` and `acceptLabel` settings reuse the same menu controls; rows
share normalization/sorting with external requests. `previewImages` reuses the image
picker, and `imageOnly` uses the shared compact viewer. `query`, `selectedResult`
and `selectionKey` restore search/selection through the same helper as external requests.
The selected-row callback also receives a second argument, `{query}`, captured before closure.
`onClosed(reason)` runs once with `accepted`, `cancelled` or `replaced`, after its reference
is cleared. Workflows can return from a cancelled child step without reopening after
replacement by another launcher. A callback may open the next native step.
Optional `keepOpen` preserves the mapped surface for that synchronous handoff;
if the callback opens no next menu, the picker closes normally.
External JSON/dmenu requests retain their existing request/reply behavior.

On acceptance, PowerService pauses tracking directly and dispatches the chosen
action to the small noninteractive `providers/power.sh` executor. It never calls
back into the picker. `launcher.sh provider power` and the no-argument provider
script remain CLI aliases for opening the native menu. Explicit actions such as
`launcher.sh provider power Lock` execute directly, retaining the best-effort
status notification and working even when the bar is unavailable; Hypridle keeps
that direct Lock path. No confirmation step or action order change is introduced.

## Exposé overview

**Meta+Shift+E** toggles a fullscreen overview on the focused monitor, starting
with the current workspace and the focused window preselected.
The centered workspace strip shows large icons with
workspace names below. Tiles and icons scale down on smaller screens. Search
is centered above the workspace strip.
Ordinary workspace views follow the desktop's window layout, preserving which
windows sit beside or above each other and scaling them together to fill the
available space. Captions and gaps stay clear without overlapping previews.
Views with floating windows or grouped application tabs, and the All view, use
the packed card layout. Window cards retain their original proportions and
relative size. A single window uses the largest
size that fits the preview area. Opaque rectangular title boxes sit above the previews.
Click a workspace tile's miniature preview to close Exposé into that workspace.
Click its header or outer area to see its windows within Exposé, or press **Ctrl+A** to show
every workspace. The All view orders windows by workspace, then top to bottom
and left to right within each workspace, including special workspaces.
Tabs in the same window group use alphabetical display-name order.
`launcher.sh expose` also starts with the current workspace;
`launcher.sh expose all` opens all windows directly.
Empty workspaces remain available as drop targets. `Config.exposeWorkspaceIds`
provides the default numbered workspaces (1–10); other existing numbered
workspaces are added automatically. Existing special workspaces also have tiles,
so their windows use the same workspace transitions.

**Ctrl+1–9** selects workspace views 1–9; **Ctrl+0** selects workspace 10.
**Ctrl+A** toggles the All view and the workspace view where the toggle started.
**Ctrl+Shift+1–9** and **Ctrl+Shift+0** move the selected window to that
workspace without following it or closing Exposé. Search text stays in place.

Type to filter window titles and applications. Hovering selects a window card;
arrow keys select windows in their displayed direction;
Enter or a click focuses the selected window. Escape or a background click
closes the overview, as does the round close button in the upper-right corner.
Opening always zooms the whole view out from the starting workspace's miniature.
Selecting a window zooms into that window's workspace miniature, then focuses
the window after the overlay disappears. Dismissing the overview zooms back into
the starting workspace's miniature, including after searching, scrolling, or
switching workspace views. All workspace tiles remain visible
by scaling the strip to fit the screen. Animations are disabled during screen
sharing. Keyboard focus is released as soon as closing begins. The overview
always opens even when there are only two windows.

Drag a window card onto a workspace tile to move that individual window
without following it or closing the overview. A grouped window is detached
before moving, so its other tabs remain in their workspace. The grid stays
stable while the pointer remains in the grid. Moving toward the workspace strip
animates the remaining windows into the space the dragged window leaves; returning
to the grid animates room for it again. Accepted drops keep that layout while the
compositor confirms the move. Rejected or unconfirmed moves restore the original
slot and card, including when the window's metadata is unchanged. Dragged cards hide their outline and animate shrinking around the grab point
so the destination stays visible. A tile highlights while it is the drop target. Empty workspaces can
receive windows without opening them first.

Switching workspaces slides the new windows in from the selected workspace's
direction and slides the previous windows out the opposite way.
`Theme.exposeRearrangeAnimationDuration` controls workspace slides and grid
rearrangement (250ms).

The background reads the current monitor's wallpaper from `awww query --json`.
Missing wallpapers fall back to the theme background. Workspace tiles show
large icons and names without wallpapers, with live miniature window layouts
below. Layouts refresh after moving a window between workspaces.
Empty workspace previews show the Exposé grid icon. Hovering a dragged window
over a workspace crossfades to its prospective miniature; accepted moves keep
that preview while the compositor updates the layout. Returning or a failed move
fades back to the empty placeholder.

Native `ScreencopyView` captures window thumbnails while the overview is open.
Captures update as applications produce frames and preserve the captured image's
aspect ratio through resizes. Window cards and workspace miniatures share
`WindowPreview` and `UI.ScaledScreencopyView`, using a source-resolution Qt Quick layer with smooth mipmap
filtering. The layer stays enabled during parent scaling, including drag zooms,
so dragging retains the same image filtering as the workspace previews.
The animation respects the monitor's reserved margins, including the bar, and
fits previews without cropping their content.
Open and close animations target the fitted usable desktop inside the workspace miniature,
excluding preview padding, and remain opaque until the layout reaches full size.
Applications can still suspend drawing themselves. Each changed window source
gets a fresh capture view. Windows without an available capture use their app
icon. After the closing animation, the overview destroys its preview grid and stops capture.
`Theme.exposeBackdropOpacity` controls wallpaper dimming;
`Theme.exposeAnimationDuration` sets the open/close animation duration (300ms).
Exposé skips these animations during screen sharing by default. Set
`Config.animateDuringScreenShare` to `true` in `config/Config.qml` to allow them.
Fullscreen media uses the same setting for opening, closing and player switches.

## Bash pickers

```sh
picker="$HOME/.config/quickshell/src/services/launcher/launcher.sh"
chosen=$(printf 'first\nsecond\n' | bash "$picker" --dmenu -no-custom)
result=$(bash "$picker" --json options.json)
bash "$picker" --json-response options.json
```

JSON requests accept `prompt`, `private`, `allowTyped`, `allowMultipleSelection`, `sort`,
`customAccept`, `query`, `selectionKey`, `layout` (`list` or `grid`), and
`items`. Each item has a `title` and a `result` (a string or JSON value), with
optional `subtitle`, `icon`, `glyph`, and `search` strings. `icon` names a desktop
icon; `glyph` uses the shared icon font in grid menus. `acceptLabel` optionally
names the submit action. Source indexes identify items;
duplicate labels cannot change the selected result. `--json` prints selected
results, one per line, and serializes objects as compact JSON. `--json-response`
returns the entire response object. The client never executes returned content.
Set `private: true` to display a JSON menu in `quickshell-private`; rbw entry
selection uses this flag. Secret-input prompts always use the private window.

Menus with a `selectionKey` (or dmenu `--selection-key KEY`) remember the last
accepted result in the preferences database and highlight it when reopened.
Remembered selections survive shell restarts and row reordering; missing results
fall back to the first matching row. Cancellation leaves the saved choice unchanged.
`Config.pickerRememberSelection` controls this behavior and defaults to `true`.

Escape/outside click exits 1, errors/timeouts exit 2, acceptance exits 0, and
Ctrl+Enter exits 10 when `customAccept` is enabled. Multi-selection rows toggle
with a click or Shift+Space, including while typing in search. Shift+Space also
moves the highlight to the next result, stopping at the last row. Arrow keys move
the highlighted entry; plain Space still types a space in search. Checkboxes
show the selection. Ctrl+A and the Select visible button add the current filtered
results, preserving earlier selections. When all visible results are selected,
the action toggles to Deselect all and clears selections across every search.
Ctrl+Shift+A always clears every selection. Enter and the submit button use the
selected entries, or the highlighted row when none are selected. A typed value
with no matches can still be submitted when the provider allows it. Browser menus label submission
Open links, which opens each selected URL through the existing browser helper.
All launcher modes, including applications, windows, Exposé, clipboard, provider
menus and JSON/dmenu requests, share the search settings in `src/config/Config.qml`.
`pickerFuzzySearch` defaults to `true`: `bna` matches Banana, `ptt` matches Potato,
and `tmt` matches Tomato. Characters must appear in order; this does not correct
substitutions or transposed letters. Ranking favors consecutive letters, word starts,
camel-case initials and title matches; equal scores preserve the source order.
Each query word must match, independently of word order. An empty query keeps the
initial order. Set `pickerFuzzySearch` to `false` for substring matching.
`pickerSmartCase` defaults to `true`: only mixed-case queries are case sensitive.
Lowercase and uppercase-only queries ignore capitalization: `ban` and `BAN` both
match Banana, while `Ban` respects case and `bAn` does not match Banana.
Set it to `false` to always ignore case.
Requests cannot override these settings. Legacy JSON `smartCase`/`fuzzy` fields
and dmenu `-case-smart`, `-i`, and `-sorting-method` options are ignored.

Requests and reply FIFOs live in a private `$XDG_RUNTIME_DIR/quickshell-picker`
directory and are cleaned up on completion or interruption. The default timeout
is ten minutes; `QS_PICKER_TIMEOUT` overrides it. `QS_PICKER_CONFIG` selects a
different shell root. IPC functions open requests asynchronously so the UI never
blocks while a Bash client waits.

## Providers

```sh
bash "$picker" provider bookmarks
bash "$picker" provider code
```

The public provider names are `code`, `webapps`, `github`, `n8n`, `remotes`,
`bookmarks`, `directories`, `power`, `screenshot`, `recording`,
`encode-qrcode`, and `wallpaper`. Interactive choices belong to native feature
services and the shared picker; the compatibility CLI forwards to their IPC entry
points. Browser selection, work/personal filtering and editor profiles are preserved.
The unused Books provider and its Meta+Shift+Period binding are retired.

Only noninteractive executors remain under `src/services/launcher/providers/`:
Power executes allowed session actions, including offline idle Lock; Wallpaper
handles filesystem discovery, assignment and offline restore; Screenshot runs the
capture/decoder tools and detached Satty editing. Recording uses its detached
worker under `src/services/recording/`, and QR encoding keeps its memory/pipe worker.
`_common/utils.sh` supplies Config export and shared completed-file reveal.

`launcher.sh` stays for the two Userscripts clients (`select_urls` and
`lib/rbw_client.py`), JSON/dmenu request/reply transport, pinentry/secret transport,
offline Config export and compatibility aliases. These are supported interfaces,
not pending migrations. No Rofi adapter or PATH override is required.

The tools-submap **E** binding dispatches `quickshell:launcher-encode-qr` to
`QrEncodeService`. `launcher.sh provider encode-qrcode` remains a compatibility
entry that opens the same native text prompt and returns immediately.
Type or paste text and press Enter to generate a QR PNG, copy it to the Wayland
clipboard and display it in a native image viewer. Enter or Escape closes the
compact viewer and leaves the clipboard image available. The viewer has no footer
hints and uses `Theme.qrPreviewSize` (360px by default). QR modules use sharp scaling
without smoothing; input uses the field placeholder and footer without an extra
empty-state label. Escape in the input cancels. Encoding uses `qrencode` with its original
defaults: error correction L, 3-pixel modules and a 4-module margin. Text is passed
through stdin, preserving pipes, quotes, Unicode and leading dashes. Success and
failure use native bar alerts; a failed encode leaves the clipboard untouched.
The service sends literal text through a private stdin pipe to the noninteractive
`qr-encode.sh` worker. The worker encodes into a PNG in memory, copies those bytes
and returns a PNG data URI to the shared viewer. No input, request or temporary
image files are created. Each tool pipeline has an owned process group for
cancellation. Enter, Escape, replacement and config reload release the preview
without changing the copied image. The shared image viewer clears its image rows
on close to release the data.
Opening another picker or restarting QR input cancels pending encoding/copy work
so a late completion cannot replace the new menu. Image-load failures report an
error through the shared preview signal. The interactive `providers/encode-qrcode.sh`
is removed; its former YAD positioning rules remain removed.

Tools-submap **W** activates `quickshell:launcher-wallpaper` through the shared
native registry. `WallpaperService` opens the existing image picker immediately and
loads image paths asynchronously from `Config.wallpaperDirectory`, which defaults
to `~/Pictures/wallpapers` in `src/config/Config.qml`. The compatibility command
`launcher.sh provider wallpaper` forwards to the same service and returns immediately.
No JSON request files or shell process wait for choices. Image → mode → monitor
keeps the native surface open and preserves its established focus through content
changes, so a delayed grab-clear event cannot dismiss the next step.
Search and preview an image, press Enter, choose personal/work mode, then choose
the connected monitor in a separate step. The focused monitor appears first. After
applying, browsing resumes with the same image selected and the same search terms.
Escape in either target step returns to image browsing; Escape in the image picker
ends the session. Target choices use the standard picker without prompt labels.
The wallpaper list shows filenames without thumbnails, so rows do not load or
cache images. Only the highlighted image loads in the large preview, beside the
list on wide screens or below it on narrow screens, using the same bounded loader
as clipboard image previews. On wide screens the popup and preview pane fit the
selected image’s aspect ratio within the available width/height, preserving the
whole image without cropping or stretching. The popup uses a fixed placement
footprint and list viewport height while browsing, so the search/list column
stays in place as previews change shape; only the preview-side width/height adapts. This reuses header dimensions from the existing loader;
the last known aspect is retained while the next image loads.
Application errors show an alert
and return to browsing with the same image and search.
Image paths containing spaces, quotes, Unicode or newlines are passed literally.
Animated GIFs can be set with `awww`; previews show a still image. Video files
are excluded because `awww` accepts images.

The provider saves per-mode, per-output symlinks under `~/Pictures/.runtime`.
Existing `wallpaper_personal_1`, `wallpaper_work_1` (DP-1) and `_2` (HDMI-A-1)
choices are preserved; additional outputs use their connector name as the suffix.
Failed application preserves the previous saved choice. `provider wallpaper restore
[personal|work]` restores available choices on connected monitors without a picker;
startup defaults to personal. Hyprland startup uses this offline-capable route;
the native Status service calls `WallpaperService.restore()` directly. The daemon
still starts from Hyprland. The native workflow reuses shared focus, preview and
motion components; the former terminal picker, setter, restore and terminal-preview scripts
are removed, along with wallpaper-only terminal positioning. The music-player
window rule remains.

Use `provider wallpaper [pick] DIRECTORY` for another image folder, or
`provider wallpaper set OUTPUT personal|work FILE` for a direct set. Numeric
outputs `1` and `2` retain the legacy DP-1/HDMI-A-1 mapping. `Config.wallpaperStateDirectory` sets the folder for saved choices.
The image root comes from `Config.wallpaperDirectory` unless a directory argument
is supplied. Direct setting and restore also read Config through the shared bridge; its headless
fallback works before the bar starts. Native set/restore instead pass Config values
directly to the helper's `--configured` execution path, with native alerts and no
worker-to-picker IPC. Native restores run sequentially and retain the latest requested
mode while a previous restore finishes. Discovery and target cancellation end the
owned pending read; late results cannot replace a newer launcher. An accepted apply
may finish after replacement, without reopening browsing.

Legacy `-markup-rows` requests are normalized by the launcher bridge before
searching/rendering. Original labels remain available for dmenu replies and
action results. Other requests display labels literally, including grid views.
Shared browser/status helpers remain in Zsh, and URL cleaning remains in Qutebrowser.

### Shared Manage layout

Webapps, Remotes, n8n, Projects and Directories expand to a Vault-style two-pane
Manage view, 780 px wide before screen bounds. The existing panel motion policy
controls expansion and content changes; screen sharing disables decorative motion
by default. Work Manage keeps its original compact, stacked rules editor.

The toolbar below the tabs spans both panes, with search and Add on the right.
The next row holds category (only with work mode enabled) and feature filters,
all initially set to All. Webapps/n8n offer enabled state and browser; Remotes
offers enabled state and connection type; Projects offers source type and path availability;
Directories offers availability. Manage includes disabled entries.

Fixed-height rows fill the left pane, with the first matching entry selected by
default. Details reuse the edit forms with read-only textboxes and Edit/Delete
controls in the right pane. Add and Edit use the same pane without a duplicate
title; Cancel/Apply stay at its bottom right. Ctrl+E edits the selected entry.
Search, filters, Add and item selection are disabled during editing.
Lists and details scroll independently; empty results clear selection and details.
Empty collections offer Add without opening an editor automatically. Saving keeps
the affected entry selected when it remains in the current filter.

Forms retain native folder selection and masked credentials. Browser/profile
controls share a row, with the full-width window-mode selector below. All fields
remain visible without an Advanced toggle. Enabled uses a checkbox; source type
and Personal/Work category use combos. Turning Work mode off removes only the
category filter, and the other filters expand to fill the row. Shortcut hints are
always horizontally centered at the bottom of the panel and vertically centered
in their final row, with no content below them.

### Webapps

Open with `launcher.sh provider webapps` (or `launcher.sh webapps`). The existing
binding opens the native Webapps picker. **Ctrl+M** switches to **Manage**;
**Ctrl+A** adds an entry while managing. Manage lists disabled entries too.
Editing, search, Escape and focus reuse the shared managed-picker components.

Entries have a name, HTTP(S) URL, browser, optional browser profile, window mode
and enabled state. Category is a Personal/Work dropdown in the main form; Work
follows the current work-status filter. The form includes literal browser arguments,
and optional before/after commands. Quote arguments containing spaces; variables,
command substitutions and shell operators are never evaluated. The before command
must succeed before the browser is dispatched; after means after dispatch, without
waiting for the browser window to close. Browsers run detached from the bar.

`Config.webappBrowsers` defines browser commands, argument templates and profile
choices (`profiles: [{id, name}]`). Manage selects a profile from the browser's
combo rather than entering a profile name. Browser default uses no explicit
profile arguments. A removed profile is reported as unavailable until another
configured profile is chosen; saved selections are not silently replaced. Qutebrowser
supports isolated named profiles. Its default **Reuse profile window** opens a
new tab in the profile's existing window, creating a window when none is running;
**New window** remains an explicit per-entry choice. If a profile already has
several windows, Qutebrowser chooses its target window using its own settings;
existing windows are not merged. Vivaldi retains its existing profile/app-window
behavior. System default delegates to `xdg-open`. Entry values live in the
local SQLite database, including profile choices and command arguments, and are
covered by the existing encrypted backup/restore flow.

Add, edit and remove entries directly in Manage. Webapps requires no provider JSON
or browser environment file; its saved entries restore with the database backup.

### n8n workflows

**Meta+Shift+N**, `launcher.sh provider n8n`, `launcher.sh n8n` and
`qs ipc call launcher n8n` open the native workflow picker. It combines cached
workflows from every eligible instance, with the instance name on each row.
Each instance also has an **Open instance** row, available before its first refresh.
Search matches workflow names, instance names and editor URLs.

**Ctrl+M** switches to Manage; **Ctrl+A** adds an instance there. Store each
instance's name, address (including any base path), API key, browser/profile,
window mode, Personal/Work category and enabled state. Browser fields are shared
with Webapps and use `Config.webappBrowsers`. Keys use the shared masked secret
field. Private connection settings and workflow caches live in the main SQLite
database and its encrypted backup, with no provider JSON or Grimoire dependency.

Personal instances remain available; Work instances appear while work status is
active. **Ctrl+W** toggles all/status filtering, resetting on each opening.
Disabled instances remain in Manage and are excluded from launching and Refresh.

**Refresh** or **Ctrl+R** fetches the currently eligible instances. Opening the
picker uses its cache immediately and makes no API requests. Refresh is explicit
only: no periodic or stale-on-open polling. Each instance's complete paginated
response replaces its own cache in one transaction, reconciling names, additions
and deletions by workflow ID. Identical IDs on different instances are independent.
Failed, incomplete, repeated, oversized or timed-out responses keep that instance's
last good list; successful instances still update. A valid empty list removes old
workflows while retaining the instance-home row. Changing an instance address
hides its old-source workflows until a successful refresh.

Create a key in n8n's **Settings → n8n API** and enter it in Manage. The client
only sends GET requests to `api/v1/workflows`, follows pagination and stores names,
IDs and editor links. It never invokes workflows. API keys travel through stdin
in the shared bounded JSON GET component, not process arguments; redirects are
rejected. Enterprise installations can restrict the key to `workflow:list`;
non-Enterprise keys have broader account access according to the
[n8n authentication documentation](https://docs.n8n.io/api/authentication/).

### Remotes

`launcher.sh remotes`, `launcher.sh provider remotes` and
`qs ipc call launcher remotes` open the native Remotes/Manage picker.
It reuses the Webapps collection controller, repository and UI components.
Ctrl+M switches Manage, Ctrl+A adds a record while managing, and Ctrl+W toggles
the work-status filter. Disabled records remain editable in Manage.

Choose RDP through an SSH tunnel or a local libvirt VM. The form masks passwords;
Category is a Personal/Work combo; the form includes domain, window title
and literal RDP arguments. Quoted arguments are parsed without shell evaluation.
Shared legacy arguments are migrated into each record, including private paths.

A detached worker owns each managed connection across bar/theme/config reloads.
Enter or clicking a row connects an idle host and disconnects an active one.
The Enter hint follows the selected row. **Running only** (Ctrl+R) filters to
running and connecting sessions, alongside the search query. It starts off each
time Remotes opens. Disconnecting rows leave this view immediately so repeated
Enter presses can disconnect several in a row. The picker stays open after
disconnecting, including when the running list becomes empty. Pending control
requests are queued individually. **Disconnect** also stops only the selected
managed RDP connection and its own SSH tunnel; it leaves a VM running.
**Shut down VM** requests shutdown for the selected VM. Active entries
cannot be deleted until disconnected. Active connections remain listed for control
even if their entry is disabled or the work-status filter changes; this does not
allow another connection to a disabled host. Other SSH/RDP processes are untouched.
The list distinguishes Connecting, RDP running and Disconnecting; RDP running
means the client process is alive, without claiming remote authentication succeeded.
SSH resolves target names locally when possible, then falls back to jump-host DNS.
Absolute and `~/` SSH key paths are supported. Failures post a generic alert without logging credentials or private host details.

The main database stores hosts and credentials and is included in encrypted backups.
Temporary ownership records live in `remotes-runtime.db` beside it, excluded from
backup and restore. Boot IDs and process start times protect against reused PIDs;
dead owners trigger cleanup of their own surviving children. FreeRDP receives its
arguments through stdin rather than exposing passwords in its process command line.
The compatibility provider is only a native IPC entrypoint; there are no host JSON
readers, import controls, global process-kill actions or hardcoded VM names.

### Directories

`launcher.sh directories`, `launcher.sh provider directories` and
`qs ipc call launcher directories` open the native directory picker. Each opening
starts in **Directories**, with the work-status filter enabled. Personal folders
remain available; work folders appear while the status is `directoryWorkStatus`.
**Ctrl+W** toggles all directories for the current opening. **Ctrl+M** toggles
**Manage**. **Ctrl+A** opens the right-pane Add form only in Manage; while
editing a field it retains Select all. Both tabs show shortcut hints. Commands,
status and shortcuts live in `src/config/Config.qml`.

When no saved entry matches, press Enter to open the local folder path typed into
search. Absolute paths, `~`, `~/…`, `$VAR` and `${VAR}` are supported;
relative paths resolve from your home directory. Substitutions are processed once
as path data; shell commands and glob patterns are never evaluated. Symlinks resolve
to their canonical folder. Invalid paths, files and unset variables keep the picker
open with its query and focus intact, showing an error that clears on editing.
Saved matches take priority. Typed paths are never added to saved directories.
Editing, closing or replacing the picker cancels a pending lookup.

Add a local path, `~/` path, or choose a folder with the native browse button.
The dialog returns focus to the input and keeps Manage open. Local folders must
exist; symlinks resolve to their canonical path. File-manager locations such as
`computer:///`, `trash:///`, `network:///` and `smb://server/share` are detected
automatically and kept as URIs, without checking or connecting to them on Add.
Opening sends the stored location directly to the configured file manager.
No administrative permission or separate system-folder setting is needed.

The form offers an optional display name and a Personal/Work button. Save returns
to the selected folder's details; Edit changes path, name and category together,
and Cancel discards changes. Duplicate paths are rejected. Manage searches names
and paths with the shared fuzzy matcher. Copy/Edit/Delete actions belong to the
selected folder's details pane. Removing an entry removes only the shortcut,
leaving the folder intact.

Manage checks local folder availability without changing saved entries. Missing or
inaccessible folders show "Folder missing or unavailable" below the path. Remote
and virtual URIs show "Location not checked"; no connection is attempted. Reopen
Manage after a folder or mount returns to clear its availability warning.

Entries live in SQLite. The former JSON provider is removed, and there is no
automatic import or migration script. `FolderForm`, `ManagementActions` and
`FolderCategorySelector` share the path/name fields, browse dialog, category combos
and copy/edit/refresh/remove controls with project management. They build on
`FolderPathField`, `ManagementRow` and the existing tabs and editor actions.
Panels supply their own service callbacks and enable only relevant controls.
`ManagedPickerFrame` shares the outer management layout, shortcuts, focus and
close cleanup. Project workspace drafts and directory validation remain in their
respective services.

### Projects

`launcher.sh projects` and `launcher.sh provider code` open the native project
picker. Every opening starts in **Projects**, with the first alphabetical row
selected. **Ctrl+M** toggles between **Manage** and the Projects picker. This
shortcut and discovery/launch policy live in `src/config/Config.qml`.
Projects use the work-status filter by default on every opening. **Ctrl+W**
toggles between that filter and all projects, including in the GitHub URL picker
(`projectShowAllShortcut`). The footer shows the current filter and shortcuts.

In Manage, the right-pane Add form starts with the folder path and browse button.
Cancel and Apply remain anchored below the form. Use the folder-open button to choose a path in the native folder picker.
Accepting or cancelling the folder picker keeps Manage open and returns focus
to the path field; selecting a folder does not start a scan.
Two buttons show the current options: **Single folder** / **Repositories root**
and **Personal** / **Work**. Clicking a button switches to its other option.
The plus button next to search opens the Add form in the right pane. **Ctrl+A**
opens the same controls only in Manage (`projectAddShortcut` in Config.qml).
In the GitHub Projects picker, Ctrl+A retains its URL-selection behavior; in an
editor it remains Select all. Save or Cancel returns to source details. Empty
source lists offer Add without opening a form automatically.
A repositories root includes each immediate
child directory; neither kind requires Git. The add action scans the source.
If no project files are found, it saves immediately without a checklist. Otherwise
it shows the project-file choices before Save. Detected `.code-workspace` and `.godot` project files
start included. Deselect any, select none, or Cancel without adding the source.
With no included project files, the folder opens in the configured default app. Paths can start with `~/` and retain spaces.

Manage lists added source folders on the left. The selected source's right pane
shows its projects, path warnings and project-file choices. Edit opens the same
right-pane form used by Add, keeping the selected source identity visible. It
supports path, native folder selection, source type, category and included project
files. Add stays visible but disabled while editing; Cancel and Apply sit at the
bottom right of the details pane.
Changing Single folder / Repositories root rescans before saving. Repository
subfolders have project-file edit
buttons; their paths are derived from the configured root. Both added paths and
repository subfolders have a copy button that copies their full folder path to
the clipboard.
The search field filters paths, repository names and project-file names using the
shared fuzzy matching. Matching characters use the accent color; path and
project-file matches are shown under the owning repository when filtering.
Opening an editor, cancelling (including Escape), and saving preserve the list's
scroll position, bounded by the space available if the results change.
Toggling project-file inclusion also preserves the editor's scroll position.
The refresh icon at the top
right of Manage rescans all configured sources. Each added path also has a
refresh icon to rescan only that folder; for a repositories root, it rescans its
subfolders. Both actions preserve choices and ask about newly found project files.
Existing choices survive. When new project files are found, Manage opens a checklist
of those new choices, initially checked. **Apply refresh** saves your choices and
the refreshed list; **Cancel refresh** keeps the previous list so the next refresh
asks again. No background scanning or scanning on picker opening occurs.
Missing or unreadable sources retain their previous results and show an error.
Removing a source removes its listing, without modifying project files.

Opening Manage also performs a read-only availability check of saved source folders,
projects and project files. Missing paths have warning text in the existing rows;
project summaries count missing project files, and the project-file editor identifies
each affected file. This check does not scan repositories or prune records. Reopen
Manage to recheck paths after recreating folders or mounting drives. Full-state import
reports the same availability issues and preserves all saved entries.

Projects inherit their source category. Edit saves category and project-file choices
together. Changing a source path scans the replacement before saving; duplicate
or unavailable paths leave the original source intact. Project-file choices follow
matching relative paths, and newly discovered project files require confirmation.
Cancel keeps the original source and choices. By default, work projects are hidden
outside the configured work status;
personal projects remain available. Ctrl+W can temporarily show both categories.
Manage always shows both categories. Sources with overlapping
projects share project-file choices; a single-folder source takes category priority.
Projects with identical names remain distinct by path.

Each project builds its actions from the included files and `Config.projectApps`.
One action opens directly: a Godot-only project opens in Godot, while a plain
folder opens in Code by default. With Code workspaces, **Open in Code** offers the
folder alongside named workspace files. Godot files add **Open in Godot** to the
same list. Multiple Godot files show their relative paths to distinguish actions.
There is no separate **Open folder** row. The last choice is remembered per
project without rearranging rows; previous workspace selections remain valid.
Opening choices and returning to Projects retain the existing native keyboard
focus grab; these transitions focus search without reactivating the window.

App names, extensions, commands, optional folder actions and existing-window
matching come from `projectApps`; `projectDefaultApp` controls the fallback.
Code keeps its category profile and window reuse; Godot uses editor mode without
Code flags. Additional apps use the same discovery, inclusion and launch path.
See [project app configuration](../configuration.md#project-apps). Refresh a source
in Manage to discover newly supported files in an existing project.

In the GitHub picker, **Shift+Space** toggles the highlighted repository and moves
to the next row without adding a space to search. Repeat to select repositories,
then press Enter to open the selected URLs. Plain Space still types in search.
`launcher.sh provider github` uses the same stored projects, filtering by category
and offering unique remote URLs with multiple selection. Git origin URLs, SSH
aliases and tracked folders from the bare dotfiles repository are supported.
SSH remote hosts resolve through `HostName` in `~/.ssh/config` (the path is
`projectSshConfig` in Config.qml). OpenSSH evaluates wildcard hosts and `Include`
files locally, without connecting. Unmapped hosts retain their original name.
Project-file discovery is recursive. `projectFileExclusions` excludes Code
configuration, generated Godot caches and Git metadata by default.

Sources, projects and workspace choices live in SQLite. The project JSON cache,
Zsh updater and `g` wrapper are removed. Existing JSON is not imported; the
project list starts empty until you add sources. Private paths remain in the
local database and are not committed.

Simple provider settings live in Config.qml:

- `screenshotDirectory` and `recordingDirectory`: capture destinations.
- `wallpaperDirectory` and `wallpaperStateDirectory`: image browsing and saved choices.
- `pickerWorkStatus`: the shared work category.

`launcher.sh --provider-config` exports an explicit, validated JSON object. The
common helper passes these settings as literal process environment values, using
the live bar or the read-only `provider-config.qml` exporter when offline. It
reuses private launcher FIFOs and saves no settings cache. Old screenshot,
recording, wallpaper and shared-helper `.env` files are no longer read.

Webapps, Remotes and n8n use native Manage tabs and SQLite; their old private JSON
files are not read and no manual import interface is required. RDP option strings
support quotes and backslash escapes; shell expressions and wildcards stay literal.

Recording offers no audio, desktop audio, microphone audio, or both. Audio modes
open the relevant output and microphone pickers, with the current defaults first
so Enter accepts them immediately. Capture, output, framerate and audio choices
keep their existing order and defaults; choosing no audio skips the device pickers.
Devices belonging to cards with an off profile are excluded from both pickers.
The [bar alert](alerts.md) for starting lasts one second and is explicitly dismissed
after one second; shared readiness waits only for panels opting into
`hideForCapture`, without waiting for notice animations. The stopped alert and file-manager
action follow only after the recorder exits successfully. Errors show an error
alert instead. The finishing alert can appear in the final captured frames;
see [recording](recording.md) for the detached lifecycle and bar indicator.
Recordings are encoded directly to MP4; there is no separate conversion stage.

Native Hyprland bindings use `hl.dsp.global("quickshell:NAME")`. One
`GlobalShortcutRegistry` owns the action list and registers it; `shell.qml` creates
one instance. Its callbacks call existing feature-service methods, and its reload
method is shared by the shortcut, shell IPC and backup-restore callback. The registry covers applications, Projects, project URLs,
Directories, Webapps, Remotes, n8n, Bookmarks, QR encoding, Power, clipboard, window lists, Exposé, recording,
Vault, notification DND, shell reload, window cycling, grouped-window selection
and the 14 bar-module shortcuts. Module and numbered-window registrations share
array-generated actions rather than separate registration components. Quickshell re-registers them across configuration reloads; the companion
Hypr config retains the key combinations. This uses Hyprland's native global-shortcut
protocol, without a per-press shell/IPC process or a desktop-portal shortcut dialog.
The existing config-scoped IPC methods remain available to command-line callers.
QML controls call their feature services directly. External JSON/dmenu clients,
password/pinentry clients and browser selections retain argument/result IPC; their
requests are not routed through compositor shortcuts. Full restart/recovery stays
external so it remains possible when the bar is not running.

The native service-backed bindings, Bookmarks, QR encoding, Power, Wallpaper and
Screenshot/OCR/QR and Recording setup orchestration are migrated. RecordingSetup
uses the shared independent capture-menu session and existing picker controls,
and passes prepared options to the detached worker;
its former interactive provider and --prepare round trip are removed. Unfinished
recording setup cancels on reload. Detached recording/session lifetimes and offline
wallpaper restore remain supported.

ScreenshotService presents the original five capture choices through
CaptureMenuService, an independent MenuSession rendered by the existing picker
window and controls. This preserves another launcher or Manage view, including
its query, selection and draft. Meta+Print opens this capture chooser and follows
the same capture policy as the direct screenshot shortcuts.
The main screenshot shortcuts and tools-submap OCR/QR bindings call it through the
native registry. `launcher.sh provider screenshot [METHOD]` is a compatibility IPC
entry. The prepared executor `providers/screenshot.sh METHOD` remains available for
explicit noninteractive/offline use through the shared Config exporter.

Panels have one `hideForCapture` property for both screenshots and recording.
It defaults to false: ordinary launchers, Manage and bar panels remain visible.
Capture controls set it to true. CaptureHandoffService closes only opted-in panels
and waits for actual closing motion/native unmap through CaptureOverlay.
CaptureHandoffService then reads the active compositor animation settings and
waits for layer/fade-out completion plus a display refresh before capture starts.
Inherited durations and disabled animations are respected. No transparent frame
is inserted. Panel hosts
route captureHideRequested to the owning service close action; the shared top-panel
host reads the property from its capturePanel. Private namespace exclusions are
separate compositor rules and are unchanged.

Capture sessions protect ordinary panels from focus/hover dismissal while capture
controls or selectors take focus. Completion and cancellation release that
protection without requesting another panel closure.
There is no fixed picker-dismissal delay; the existing short
hyprpicker freeze-initialization delay is separate. The worker bounds selection and
capture to 30 seconds, validates geometry, accounts for monitor scale/rotation when
clipping windows, and stops only its own process groups. Escape cancels quietly;
selection/capture/tool failures produce native bar alerts without starting later
stages. hyprshot and global pgrep/pkill cleanup are no longer used.
Region/output selectors receive explicit empty stdin: slurp reads optional rectangle
input before mapping, so inheriting an open QProcess pipe would stall selection.
Window selection instead receives the prepared rectangle file.

OCR keeps Portuguese Tesseract and QR decoding keeps zbarimg. Successful text is
copied unchanged and shown through native alerts; empty results and errors have
separate messages. Completed screenshots go to Satty in a detached worker so an
annotation draft survives bar/theme reloads. Saved images use unique names under
Config.screenshotDirectory and retain file-manager reveal/focus; closing Satty
without saving removes the empty filename reservation and temporary capture. The
annotation worker uses only the existing alert IPC endpoint for feedback, never a
picker or Config round trip.

Shell-backed workflows use
`launcher.sh provider NAME [ARGS...]`; callers should use this entry point rather
than reaching into the provider tree. Qutebrowser's media shortcuts
call the separate `to_mpv` userscript in
`~/.local/share/qutebrowser/userscripts/` for direct mpv playback.
Meta+I, then T, opens Twitch through the native `quickshell:bar-twitch` action; the live-streamer JSON
export and combined Twitch/YouTube picker are removed. Run `:config-source` in an already-running
Qutebrowser to refresh these bindings. Hypridle calls `provider power Lock`.

Hyprland uses Super+D for applications and Super+V for clipboard history.
Existing shortcuts retain their keys. Window-switching shortcuts use native global
actions. Meta+Shift+Escape preserves its existing notification DND toggle; the
Notifications module shortcut opens its panel. CopyQ is no longer started automatically.

`bash tests/launcher/providers.sh` checks native compatibility dispatch, offline idle
Lock and shared file reveal with mocked actions. Feature-specific suites cover the
remaining capture, recording, Wallpaper and QR workers.
`bash tests/launcher/launcher.sh` exercises actual Bash/QML IPC in an isolated offscreen shell. Neither test opens applications on the desktop.

## Clipboard

Regular clipboard text and supported images are captured through supervised
`wl-paste --watch` processes; primary selection is not recorded. Watcher groups
are cleaned up on reload, including active capture workers. Stalled transfers
time out after five seconds without blocking other copies. The picker shows
text previews and images across the row width, preserving their aspect ratio.
`Theme.clipboardImagePreviewHeight` sets the image preview height (200px by default).
Click selects, double-click/Enter pastes into
the window active before opening, and Ctrl+C restores without pasting.
Paste inserts the highlighted entry into the original window. The red trash
button removes that entry, while Clear history removes only unpinned entries.
The thumbtack button or Ctrl+P toggles the highlighted entry's pin. Pinned entries
show a thumbtack and survive restarts, repeated copies, history clearing, and
automatic pruning. The Pinned only button or Ctrl+Shift+P toggles a pinned-entry
filter, highlighted with the accent color when active. Search still applies
within the filtered entries; opening the picker again starts with all entries.
Clipboard search defaults to case-insensitive FTS5 word/prefix matching. Terms
must all match; punctuation separates words and typed FTS operators are literal
words. Results arrive in pages with bounded previews. The Fuzzy button switches
to the existing subsequence matcher, including smart case and cached candidate
reuse. Only this option loads full searchable text. Closing the picker releases
its search state; background captures do not hydrate a closed clipboard list.
Rapid typing replaces queued queries, and only the latest results are displayed.
Enter and Ctrl+C pressed during a search wait for its results before pasting or
copying; changing the query or closing the picker cancels that pending action.

**Images only** or **Ctrl+Shift+I** filters images and expands the existing picker
across the focused monitor. The list keeps its normal width and moves left; a
large aspect-fit preview pops in on the right. Turning the filter off reverses
the transition. Narrow monitors use a stacked preview. Pinned only and search
compose with this filter. Image search covers MIME metadata, without OCR.
Normal openings start with indexed search and both filters off.
Thumbnails and previews use shared smooth filtering and mipmaps, asynchronous
loading and display-scale-aware source sizing. The large preview avoids image
caching and has an eight-megapixel target budget (`Config.clipboardPreviewMaxPixels`).
Small images remain centered at their original pixel size; only images larger
than the viewport are scaled down to fit. A Bash helper reads local image header
dimensions with ImageMagick before choosing decode/display sizes, so the decoder
does not enlarge small images either. Decode dimensions are capped by the actual
preview pane in physical pixels, including when the compositor constrains a
high-DPI window. Shared filtering remains enabled.
The shared preview retains the previous ready image while the next one loads,
then fades between them over `Theme.imagePreviewFadeDuration` (140ms by default).
Wallpaper and clipboard use the same component and source-change handling.
Opening an image or stepping through images normally starts a sharp decode
immediately and keeps the previous sharp frame visible until it is ready. Small
previews stay hidden during ordinary selection. Changes less than 100ms apart
switch to 192-pixel previews for rapid browsing. When idle, the two nearest
images in each direction are prefetched. Seven small image slots bound this
temporary memory working set; there is no persistent thumbnail cache or list-thumbnail generation.
Only one small decode runs at a time. Held arrow keys replace the queued selection
without cancelling each in-flight decode; completed intermediate selections can
still display while navigation continues. During rapid browsing, cached neighbors
display immediately.
After rapid browsing pauses for 150ms, the final image decodes at the pane's
physical resolution. Small previews and fades share the same component for both
menus. A stale completion cannot replace the final selection. The sharp incoming
and outgoing frames are released after their fade, and all image sources are
released when the preview closes. Missing/corrupt images show an explicit error.
Row refreshes with the same image URL do not reload it. PNG and other codecs may
still decompress the complete source to produce a small preview. Viewport/display-scale changes are coalesced over 100ms, and unchanged
effective dimensions do not restart a decode. The complete decode size is set
before loading the new file. These bounds limit the requested preview, not the
image codec's temporary buffers or the renderer's total memory. A small compressed
file can still contain a very large image.
Layout transitions use `Theme.clipboardLayoutDuration` (160ms by default); layout
and image fades use the shared `UI.MotionPolicy.enabled` gate for
`animateDuringScreenShare` and active sharing. Repeated toggles retarget
the current motion.
Pins count toward the entry and total-size limits, but are
never removed to satisfy those limits; if pins alone exceed a limit, they are
kept and new unpinned entries cannot be retained. Explicitly deleting a pinned
entry still removes it.
Delete also removes the highlighted entry while search has focus; use Backspace
to edit the search query. Errors are
shown when the panel next opens. The IPC pause toggle stops saving new copies
and persists across restarts.

`clipboard.sh` owns byte capture, restoration, cleanup and paste injection. QML
owns SQLite metadata. Payloads live in private `data/clipboard/` files, indexed
by MIME type and content hash; metadata lives in `data/quickshell.db` schema 5.
The defaults retain at most 1,000 entries and 500 MB total, controlled by
`Config.clipboardMaxItems` and `Config.clipboardMaxTotalBytes`, with a 10 MB image
limit and 1 MB text limit. Empty, oversized, unsupported and sensitive-marked copies
are skipped. TOTP codes copied by this shell are excluded. This does not identify
unmarked passwords copied by other applications.

Paste uses `ydotool` and an available daemon/socket. The destination must still
exist and be focused before injection. Common terminal classes receive
Ctrl+Shift+V; other applications receive Ctrl+V. Applications with different
shortcuts can use Copy and paste manually. Restoration offers a single MIME type;
rich text and alternate formats are not retained together.

```sh
qs ipc call clipboard togglePause
qs ipc call clipboard importCopyq
qs ipc call clipboard state
```

Import reads up to 200 existing text/image entries through CopyQ's CLI without
modifying CopyQ's source history. CopyQ must be running. No clipboard contents
are printed to application logs.

The window uses the `quickshell-picker` layer namespace. A namespace alone does
not exclude it from screen capture: that requires an enabled compositor rule.
The current Hyprland picker exclusion is commented out; this implementation
preserves that capture behavior. Index migration, maintenance and rollback are
documented in [Clipboard index maintenance](../clipboard-index.md).

## Checks

```sh
bash tests/launcher/launcher.sh
bash tests/launcher/clipboard-search.sh
bash tests/launcher/expose.sh
bash tests/clipboard/clipboard.sh
bash tests/launcher/wayland.sh
bash tests/qml/lint.sh
```

The first two use temporary databases and mocked clipboard/input commands.
The Wayland check briefly displays an isolated picker without capturing the real
clipboard, saves `/tmp/quickshell-picker-preview.png`, then restores the original
window focus.

## Secret input and rbw

`launcher.sh --secret --prompt "Master Password"` opens a masked field that
bypasses search and remembered selections. It uses the `quickshell-private`
namespace shared by TOTP and notifications. The eye button reveals the value on
request; every new prompt starts masked. Enter confirms and Escape cancels,
without Unlock or Cancel buttons. Secret prompts take keyboard focus without
moving the pointer, then stay open when you use another desktop window,
so you can copy a value elsewhere and
click back into the field to paste it. The exact value returns through a
private reply FIFO; only public prompt metadata is written to disk. Cancellation,
timeout and client death clear the field. The Bash helpers `secret_prompt.sh` and
`pinentry-rbw` connect this UI to rbw; secret replies are decoded from stdin with
jq and streamed to stdout without putting the password in command arguments.
JSON menus can set `showPrompt: true` to always display their destination label.
See [rbw integration](rbw.md) for setup, limitations and cross-repository tests.

## Private windows and vault manager

`UI.PrivatePanelWindow` owns the fixed `quickshell-private` namespace.
`PrivateTopPanelTooltip` combines it with the shared `TopPanelSurface` layout;
`PrivateTooltipWindow` adds tooltip placement, and `PrivatePickerWindow` uses the
same picker content/focus behavior as `PickerWindow`. The ordinary and private
hosts are separate because a connected Wayland surface cannot change namespace.
Picker modes select content; JSON `private: true` routes generic menus into the
private host. Sensitive modules use a private window directly.

**Meta+W** opens the private [rbw vault manager](rbw.md#vault-manager), with a
single searchable view, folder/type filters and New/Edit/Delete actions. A single
click opens details; reveal/copy stay explicit. Explicit opening focuses Search;
switching to another app releases focus while keeping the manager and draft open.
Returning does not refocus Search over an editor. Escape discards a draft before
closing. Background lock checks do not interrupt the controls or move the list.

With `Config.workModeEnabled: false`, category controls and status-filter shortcuts
are hidden across native pickers. All categories remain visible; explicit saved
browser profiles are preserved. Wallpaper skips mode selection and uses Personal.
