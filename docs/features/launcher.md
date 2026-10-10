# Launcher and clipboard

The launcher uses the same theme, search field, buttons and scrollbar as the bar.
Clickable rows, buttons and scrollbars show a pointing-hand cursor. It opens on
the focused monitor, centered horizontally and attached below the bar with the
same curved joins and shadow as tooltips. List and power-grid launchers temporarily
raise the bar on their monitor above fullscreen applications; closing restores
the bar's normal layer. These modes use `Theme.pickerWidth` (clamped on small
screens). The search field stays at the same horizontal position and
height across picker modes. It keeps keyboard focus while the pointer moves, and closes
with Escape or an outside click.
Picker headers contain search. Prompt titles are hidden by
default; set `Config.pickerShowPrompt` to `true` to display them below search.
`Theme.pickerBackgroundOpacity` controls background transparency (0–1), keeping
text and controls opaque. Escape dismisses the picker.
The list keeps its opening size while filtering or deleting entries, so the
dialog and footer stay in place.
`PickerPanelBase` shares layout, search and navigation. `ClipboardPickerPanel`
and `MultiSelectPickerPanel` extend it with their own shortcuts and action buttons;
`PickerPanel` loads the appropriate panel.

## Commands

```sh
qs ipc call launcher apps
qs ipc call launcher windows all
qs ipc call launcher windows current
qs ipc call launcher expose all
qs ipc call launcher expose current
qs ipc call launcher clipboard
```

Applications use native desktop-entry metadata and `gtk-launch`, including terminal
applications. Rows show only application names. Recent launches are ordered first. Window modes reuse `WindowService`;
Enter focuses a window, Ctrl+Enter focuses without dismissing, and two-window lists
switch immediately to the previous window. Focusing a grouped window activates
its tab using live group membership. Current-workspace mode considers tiled
windows and falls back to all windows if fewer than two are available.

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
size that fits the preview area. Opaque rectangular title boxes sit above the previews. Click a workspace to see its windows, or press **Ctrl+A** to show
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
slot. Dragged cards animate shrinking around the grab point so the destination stays
visible. A tile highlights while it is the drop target. Empty workspaces can
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
aspect ratio through resizes. Strongly downscaled previews use a source-resolution
Qt Quick layer with smooth mipmap filtering to reduce aliasing in miniatures.
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
`Config.exposeAnimateDuringScreenShare` to `true` in `config/Config.qml` to allow them.

## Bash pickers

```sh
picker="$HOME/.config/quickshell/src/services/launcher/launcher.sh"
chosen=$(printf 'first\nsecond\n' | bash "$picker" --dmenu -no-custom)
result=$(bash "$picker" --json options.json)
bash "$picker" --json-response options.json
```

JSON requests accept `prompt`, `allowTyped`, `allowMultipleSelection`, `sort`,
`customAccept`, `query`, `selectionKey`, `layout` (`list` or `grid`), and
`items`. Each item has a `title` and a `result` (a string or JSON value), with
optional `subtitle`, `icon`, `glyph`, and `search` strings. `icon` names a desktop
icon; `glyph` uses the shared icon font in grid menus. `acceptLabel` optionally
names the submit action. Source indexes identify items;
duplicate labels cannot change the selected result. `--json` prints selected
results, one per line, and serializes objects as compact JSON. `--json-response`
returns the entire response object. The client never executes returned content.

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
bash "$picker" provider azure --pick
```

Providers live together in `src/services/launcher/providers/`, reusing the existing
Bash actions and cache locations. Available
names are `code`, `webapps`, `github`, `azure`, `n8n`, `remotes`, `bookmarks`,
`books`, `directories`, `media`, `power`, `screenshot`, and `recording`.
Their shared JSON handler and direct menu calls invoke `launcher.sh`; no Rofi
adapter or PATH override is required. `_common/` holds the shared Bash helpers;
`web/` contains webapps, Azure and n8n, and `remotes/` contains the VM/RDP
scripts. Projects, GitHub and directories dispatch directly to native QML services; their
former Bash providers are removed. The other providers are named `<provider>.sh`. Browser selection,
work/personal filtering, editor profiles and cache rebuild flags are preserved.
Shared browser/status helpers remain in Zsh, and URL cleaning remains in Qutebrowser.

### Directories

`launcher.sh directories`, `launcher.sh provider directories` and
`qs ipc call launcher directories` open the native directory picker. Each opening
starts in **Directories**, with the work-status filter enabled. Personal folders
remain available; work folders appear while the status is `directoryWorkStatus`.
**Ctrl+W** toggles all directories for the current opening. **Ctrl+M** toggles
**Manage**. **Ctrl+A** opens the bottom-right Add form only in Manage; while
editing a field it retains Select all. Both tabs show shortcut hints. Commands,
status and shortcuts live in `src/config/Config.qml`.

Add a local path, `~/` path, or choose a folder with the native browse button.
The dialog returns focus to the input and keeps Manage open. Local folders must
exist; symlinks resolve to their canonical path. File-manager locations such as
`computer:///`, `trash:///`, `network:///` and `smb://server/share` are detected
automatically and kept as URIs, without checking or connecting to them on Add.
Opening sends the stored location directly to the configured file manager.
No administrative permission or separate system-folder setting is needed.

The form offers an optional display name and a Personal/Work button. Save hides
the form; Edit lets you change the path, name and category together, and Cancel
discards changes. Duplicate paths are rejected. Manage searches names and paths
with the shared fuzzy matcher and shows both categories, with row dividers and
hover highlighting. Removing an entry removes only the shortcut, leaving the
folder intact. Empty lists show the add form immediately.

Entries live in SQLite. The former JSON provider is removed, and there is no
automatic import or migration script. `FolderPathField` and `ManagementRow` are
shared with project management, along with the existing tabs and editor actions.

### Projects

`launcher.sh projects` and `launcher.sh provider code` open the native project
picker. Every opening starts in **Projects**, with the first alphabetical row
selected. **Ctrl+M** toggles between **Manage** and the Projects picker. This
shortcut and discovery/launch policy live in `src/config/Config.qml`.
Projects use the work-status filter by default on every opening. **Ctrl+W**
toggles between that filter and all projects, including in the GitHub URL picker
(`projectShowAllShortcut`). The footer shows the current filter and shortcuts.

In Manage, the add form starts with the folder path and browse, cancel and add
buttons. Use the folder-open button to choose a path in the native folder picker.
Accepting or cancelling the folder picker keeps Manage open and returns focus
to the path field; selecting a folder does not start a scan.
Two buttons show the current options: **Single folder** / **Repositories root**
and **Personal** / **Work**. Clicking a button switches to its other option.
Once sources exist, the plus button at the bottom right expands into the add
controls in the footer, while search and projects remain above. **Ctrl+A** opens
the same controls only in Manage (`projectAddShortcut` in Config.qml).
Both views show shortcut hints. In the GitHub Projects picker, Ctrl+A selects
visible URLs or clears the selection; it never opens the add form. While the add
form is open, Ctrl+A retains the input field's Select all behavior. Save or Cancel
collapses the form. With no sources, the form appears immediately.
A repositories root includes each immediate
child directory; neither kind requires Git. The add action scans the source.
If no workspaces are found, it saves immediately without a checklist. Otherwise
it shows the workspace choices before Save. Detected `.code-workspace` files
start included. Deselect any, select none, or Cancel without adding the source.
**Open folder** is always available. Paths can start with `~/` and retain spaces.

Manage groups projects under each added path. Its edit button opens the category
and all its detected workspaces, including excluded ones. Category changes are
saved with workspace choices; Cancel discards both. A root's category applies
to all its projects. Repository roots also list subfolders by name with individual
workspace edit buttons when workspaces exist. Subfolder rows have dividers and
highlight on hover to associate each edit button with its folder.
The search field filters paths and
repository names using the shared fuzzy matching. The refresh icon at the top
right of Manage rescans all configured sources. Each added path also has a
refresh icon to rescan only that folder; for a repositories root, it rescans its
subfolders. Both actions preserve choices and ask about newly found workspaces.
Existing choices survive. When new workspaces are found, Manage opens a checklist
of those new choices, initially checked. **Apply refresh** saves your choices and
the refreshed list; **Cancel refresh** keeps the previous list so the next refresh
asks again. No background scanning or scanning on picker opening occurs.
Missing or unreadable sources retain their previous results and show an error.
Removing a source removes its listing, without modifying project files.

Projects inherit their source's category. Change it inside the source's edit
view. By default, work projects are hidden outside the configured work status;
personal projects remain available. Ctrl+W can temporarily show both categories.
Manage always shows both categories. Sources with overlapping
projects share workspace choices; a single-folder source takes category priority.
Projects with identical names remain distinct by path.

Within each project, **Open folder** stays first, followed by alphabetically
ordered included workspaces. The last folder/workspace choice is remembered per
project without rearranging rows. Opening focuses a matching VS Code window when
available, otherwise launches the selected folder/workspace with its source's
configured editor profile.

`launcher.sh provider github` uses the same stored projects, filtering by category
and offering unique remote URLs with multiple selection. Git origin URLs, SSH
aliases and tracked folders from the bare dotfiles repository are supported.
SSH remote hosts resolve through `HostName` in `~/.ssh/config` (the path is
`projectSshConfig` in Config.qml). OpenSSH evaluates wildcard hosts and `Include`
files locally, without connecting. Unmapped hosts retain their original name.
Workspace discovery is recursive and excludes `*/.config/Code/*` by default.

Sources, projects and workspace choices live in SQLite. The project JSON cache,
Zsh updater and `g` wrapper are removed. Existing JSON is not imported; the
project list starts empty until you add sources. Private paths remain in the
local database and are not committed.

Private configuration lives beside its provider and stays Git-ignored:

- `_common/utils.env`: shared category settings.
- `web/webapps.json` and `web/n8n.json`: JSON picker entries.
- `remotes/hosts.json`: VM/RDP hosts; `hosts.json.sample` documents the format.
  RDP option strings support quotes and backslash escapes; shell expressions and
  wildcards are passed literally.
- `screenshot.env`: Bash `SCREENSHOT_FOLDER` setting.
- `recording.env`: Bash `VIDEOS_FOLDER` setting.

Recording offers no audio, desktop audio, microphone audio, or both. Audio modes
open the relevant output and microphone pickers, with the current defaults first
so Enter accepts them immediately. Capture, output, framerate and audio choices
keep their existing order and defaults; choosing no audio skips the device pickers.
Devices belonging to cards with an off profile are excluded from both pickers.
The Hyprland start notification lasts one second, followed by a 1.1-second wait
before capture begins. The stop notification and file-manager action follow only
after the recorder exits successfully, keeping both notifications out of the video.
Recordings are encoded directly to MP4; there is no separate conversion stage.

Hyprland bindings call `launcher.sh provider NAME [ARGS...]`; new callers should
use this entry point rather than reaching into the provider tree. Books and Azure
use `--pick`; both also support `--rebuild-cache`. Qutebrowser's media shortcuts
call `provider media TITLE URL` for direct mpv playback without a picker.
Meta+I, then T, opens Twitch through `qs ipc call bar open twitch`; the live-streamer JSON
export and combined Twitch/YouTube picker are removed. Run `:config-source` in an already-running
Qutebrowser to refresh these bindings. Hypridle calls `provider power Lock`.

Hyprland uses Super+D for applications and Super+V for clipboard history.
Existing shortcuts retain their keys. Window-switching shortcuts call launcher
IPC directly. CopyQ is no longer started automatically.

`bash tests/launcher/providers.sh` checks every provider with synthetic configuration
and mocked actions. `bash tests/launcher/launcher.sh` exercises actual Bash/QML
IPC in an isolated offscreen shell. Neither test opens applications on the desktop.

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

The window uses the `quickshell-picker` layer namespace. Its Hyprland layer rule
excludes launcher and clipboard contents from screen capture independently of
the bar's screen-sharing toggle.

## Checks

```sh
bash tests/launcher/launcher.sh
bash tests/launcher/expose.sh
bash tests/clipboard/clipboard.sh
bash tests/launcher/wayland.sh
bash tests/qml/lint.sh
```

The first two use temporary databases and mocked clipboard/input commands.
The Wayland check briefly displays an isolated picker without capturing the real
clipboard, saves `/tmp/quickshell-picker-preview.png`, then restores the original
window focus.
