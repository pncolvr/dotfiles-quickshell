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

## Internal dispatch

`PickerService.Mode` identifies the internal modes: `None`, `Menu`, `Projects`,
`Directories`, `Apps`, `Windows`, `Clipboard` and `Secret`. Acceptance and panel selection
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
bash "$picker" provider azure --pick
```

Providers live together in `src/services/launcher/providers/`, reusing the existing
Bash actions and cache locations. Available
names are `code`, `webapps`, `github`, `azure`, `n8n`, `remotes`, `bookmarks`,
`books`, `directories`, `media`, `power`, `screenshot`, `recording`, `encode-qrcode`, and `wallpaper`.
Their shared JSON handler and direct menu calls invoke `launcher.sh`; no Rofi
adapter or PATH override is required. `_common/` holds the shared Bash helpers;
`web/` contains webapps, Azure and n8n, and `remotes/` contains the VM/RDP
scripts. Projects, GitHub and directories dispatch directly to native QML services; their
former Bash providers are removed. The other providers are named `<provider>.sh`. Browser selection,
work/personal filtering, editor profiles and cache rebuild flags are preserved.

`launcher.sh provider encode-qrcode` opens a text prompt in the launcher.
Type or paste text and press Enter to generate a QR PNG, copy it to the Wayland
clipboard and display it in a native image viewer. Enter or Escape closes the
compact viewer and leaves the clipboard image available. The viewer has no footer
hints and uses `Theme.qrPreviewSize` (360px by default). QR modules use sharp scaling
without smoothing; input uses the field placeholder and footer without an extra
empty-state label. Escape in the input cancels. Encoding uses `qrencode` with its original
defaults: error correction L, 3-pixel modules and a 4-module margin. Text is passed
through stdin, preserving pipes, quotes, Unicode and leading dashes. Success and
failure use bar alerts; a failed encode leaves the clipboard untouched. Temporary
input and image files are private, retained while the QR viewer is open, and
removed when the provider exits.
Hyprland's existing tools-submap **E** binding calls this provider; its former
YAD dialog and QR-specific window positioning rules are removed.

`launcher.sh provider wallpaper` opens the image picker at `Config.wallpaperDirectory`,
which defaults to `~/Pictures/wallpapers` in `src/config/Config.qml`.
Search and preview an image, press Enter, choose personal/work mode, then choose
the connected monitor in a separate step. The focused monitor appears first. After
applying, browsing resumes with the same image selected and the same search terms.
Escape in either target step returns to image browsing; Escape in the image picker
ends the session. Target choices use the standard picker without prompt labels.
The wallpaper list shows filenames without thumbnails, so rows do not load or
cache images. Only the highlighted image loads in the large preview, beside the
list on wide screens or below it on narrow screens, using the same bounded loader
as clipboard image previews. Application errors show an alert
and return to browsing with the same image and search.
Image paths containing spaces, quotes, Unicode or newlines are passed literally.
Animated GIFs can be set with `awww`; previews show a still image. Video files
are excluded because `awww` accepts images.

The provider saves per-mode, per-output symlinks under `~/Pictures/.runtime`.
Existing `wallpaper_personal_1`, `wallpaper_work_1` (DP-1) and `_2` (HDMI-A-1)
choices are preserved; additional outputs use their connector name as the suffix.
Failed application preserves the previous saved choice. `provider wallpaper restore
[personal|work]` restores available choices on connected monitors without a picker;
startup defaults to personal. Hyprland startup and the Zsh status manager use this
route. The daemon still starts from Hyprland. Tools-submap **W** opens the native
picker; the former terminal picker, setter, restore and terminal-preview scripts
are removed, along with wallpaper-only terminal positioning. The music-player
window rule remains.

Use `provider wallpaper [pick] DIRECTORY` for another image folder, or
`provider wallpaper set OUTPUT personal|work FILE` for a direct set. Numeric
outputs `1` and `2` retain the legacy DP-1/HDMI-A-1 mapping. Optional
`providers/wallpaper.env` can set `WALLPAPER_STATE_DIRECTORY` for saved choices.
The image root comes from `Config.wallpaperDirectory` unless a directory argument
is supplied. Direct setting and restore work without reading launcher configuration.

Azure rebuilds reuse the `portkey` container, start it if stopped, or create it
from `portkey:latest` with `~/Projects/helpers/portkey` mounted at
`/workspaces/scripts/azure/portkey`. Subscription queries run
`scripts/list-subs.sh` in that same container, without requesting a TTY.
Rebuilds validate the response and replace the cache atomically; failed queries
keep the previous cache. To customize the helper setup, set
`AZURE_PICKER_CONTAINER`, `AZURE_PICKER_IMAGE`, `AZURE_PICKER_SOURCE`,
`AZURE_PICKER_SCRIPT`, or `AZURE_PICKER_VOLUME`. `AZURE_PICKER_ENV_FILE` optionally
supplies the Portkey configuration when creating a container. Existing containers
retain their configured environment.

Legacy `-markup-rows` requests are normalized by the launcher bridge before
searching/rendering. Original labels remain available for dmenu replies and
action results. Other requests display labels literally, including grid views.
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
hover highlighting. Each row has a copy button for its full path or location URI.
Removing an entry removes only the shortcut, leaving the
folder intact. Empty lists show the add form immediately.

Manage checks local folder availability without changing saved entries. Missing or
inaccessible folders show "Folder missing or unavailable" below the path. Remote
and virtual URIs show "Location not checked"; no connection is attempted. Reopen
Manage after a folder or mount returns to clear its availability warning.

Entries live in SQLite. The former JSON provider is removed, and there is no
automatic import or migration script. `FolderForm`, `ManagementActions` and
`FolderCategoryButton` share the path/name fields, browse dialog, category colors
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
If no project files are found, it saves immediately without a checklist. Otherwise
it shows the project-file choices before Save. Detected `.code-workspace` and `.godot` project files
start included. Deselect any, select none, or Cancel without adding the source.
With no included project files, the folder opens in the configured default app. Paths can start with `~/` and retain spaces.

Manage groups projects under each added path. Repository roots list subfolders
by name, with dividers and hover highlighting. Added paths have edit, refresh and
remove buttons. Edit opens the bottom form while keeping the source list, search
and scroll position visible. It supports the folder path, native folder picker,
folder type, category and included project files. Add and Edit reuse the same form.
Manage keeps hints and actions on one footer line. Add stays visible but disabled
while a form is open; Cancel and Apply follow it on the right.
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

Private configuration lives beside its provider and stays Git-ignored:

- `_common/utils.env`: shared category settings.
- `web/webapps.json` and `web/n8n.json`: JSON picker entries.
- `remotes/hosts.json`: VM/RDP hosts; `hosts.json.sample` documents the format.
  RDP option strings support quotes and backslash escapes; shell expressions and
  wildcards are passed literally.
- `screenshot.env`: Bash `SCREENSHOT_FOLDER` setting.
- `recording.env`: Bash `VIDEOS_FOLDER` setting. [Recording](recording.md) runs in a detached worker and survives bar/config reloads.
- `wallpaper.env`: optional Bash `WALLPAPER_STATE_DIRECTORY` setting; set the image root with `Config.wallpaperDirectory`.

Recording offers no audio, desktop audio, microphone audio, or both. Audio modes
open the relevant output and microphone pickers, with the current defaults first
so Enter accepts them immediately. Capture, output, framerate and audio choices
keep their existing order and defaults; choosing no audio skips the device pickers.
Devices belonging to cards with an off profile are excluded from both pickers.
The [bar alert](alerts.md) for starting lasts one second and is explicitly dismissed
after a 1.1-second wait before capture begins. The stopped alert and file-manager
action follow only after the recorder exits successfully. Errors show an error
alert instead. Recording status messages therefore stay outside the capture.
Recordings are encoded directly to MP4; there is no separate conversion stage.

Hyprland bindings call `launcher.sh provider NAME [ARGS...]`; new callers should
use this entry point rather than reaching into the provider tree. Books and Azure
use `--pick`; both also support `--rebuild-cache`. Qutebrowser's media shortcuts
call the separate `to_mpv` userscript in
`~/.local/share/qutebrowser/userscripts/` for direct mpv playback.
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
