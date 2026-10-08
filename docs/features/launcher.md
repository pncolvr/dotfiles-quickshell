# Launcher and clipboard

The launcher uses the same theme, search field, buttons and scrollbar as the bar.
Clickable rows, buttons and scrollbars show a pointing-hand cursor. It opens on
the focused monitor, centered horizontally and attached below the bar with the
same curved joins and shadow as tooltips. List modes and the power grid
use `Theme.pickerWidth` (clamped on small screens). The search field stays at the same horizontal position and
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
with the current workspace and the focused window preselected. The centered workspace strip shows large icons with
workspace names below. Tiles and icons scale down on smaller screens. Search
sits to the left of **Show all**, centered together above the workspace strip.
Window cards retain each window's original proportions and relative size,
packing wide and narrow windows together. A single window uses the largest
size that fits the preview area. Opaque rectangular title boxes sit above the previews. Click a workspace to see its windows, or **Show all** to show
every workspace. The All view orders windows by workspace, then top to bottom
and left to right within each workspace. Grouped workspaces use the same
alphabetical display-name order as the bar. `launcher.sh expose` also starts with the current workspace;
`launcher.sh expose all` opens all windows directly.
Empty workspaces remain available as drop targets. `Config.exposeWorkspaceIds`
provides the default numbered workspaces (1–10); other existing numbered
workspaces are added automatically.

**Ctrl+1–9** selects workspace views 1–9; **Ctrl+0** selects workspace 10.
**Ctrl+A** toggles Show all and the workspace view where the toggle started.
**Ctrl+Shift+1–9** and **Ctrl+Shift+0** move the selected window to that
workspace without following it or closing Exposé. Search text stays in place.

Type to filter window titles and applications. Hovering selects a window card;
arrow keys navigate the grid;
Enter or a click focuses the selected window. Escape or a background click
closes the overview. Opening zooms the whole view out from the focused window's
preview; selecting a window zooms its preview up to fit the usable desktop, then focuses
it after the overlay disappears. Escape and the Exposé keybind return to the
starting window, or zoom into its workspace miniature if that window is hidden by
search, scrolling, or another workspace view. All workspace tiles remain visible
by scaling the strip to fit the screen. Animations are disabled during screen
sharing. Keyboard focus is released as soon as closing begins. The overview
always opens even when there are only two windows.

Drag a window card onto a workspace tile to move that individual window
without following it or closing the overview. A grouped window is detached
before moving, so its other tabs remain in their workspace. The grid stays
stable throughout the pointer gesture; live compositor updates refresh it after
release. Dragged cards animate shrinking around the grab point so the destination stays
visible, then animate back to their full size. A tile highlights while it is the drop target. Empty workspaces can
receive windows without opening them first.

The background reads the current monitor's wallpaper from `awww query --json`.
Missing wallpapers fall back to the theme background. Workspace tiles show
large icons and names without wallpapers, with live miniature window layouts
below. Layouts refresh after moving a window between workspaces.

Native `ScreencopyView` captures window thumbnails while the overview is open.
Captures update as applications produce frames and preserve the captured image's
aspect ratio through resizes. Strongly downscaled previews use a source-resolution
Qt Quick layer with smooth mipmap filtering to reduce aliasing in miniatures.
The animation respects the monitor's reserved margins, including the bar, and
fits previews without cropping their content.
Applications can still suspend drawing themselves. Each changed window source
gets a fresh capture view. Windows without an available capture use their app
icon. After the closing animation, the overview destroys its preview grid and stops capture.
`Theme.exposeBackdropOpacity` controls wallpaper dimming;
`Theme.exposeAnimationDuration` sets the open/close animation duration (300ms).

## Bash pickers

```sh
picker="$HOME/.config/quickshell/src/services/launcher/launcher.sh"
chosen=$(printf 'first\nsecond\n' | bash "$picker" --dmenu -no-custom)
result=$(bash "$picker" --json options.json)
bash "$picker" --json-response options.json
```

JSON requests accept `prompt`, `allowTyped`, `allowMultipleSelection`, `sort`,
`smartCase`, `fuzzy`, `customAccept`, `query`, `layout` (`list` or `grid`), and
`items`. Each item has a `title` and a `result` (a string or JSON value), with
optional `subtitle`, `icon`, `glyph`, and `search` strings. `icon` names a desktop
icon; `glyph` uses the shared icon font in grid menus. `acceptLabel` optionally
names the submit action. Source indexes identify items;
duplicate labels cannot change the selected result. `--json` prints selected
results, one per line, and serializes objects as compact JSON. `--json-response`
returns the entire response object. The client never executes returned content.

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
Smart-case matching becomes case sensitive when the query contains uppercase.
Fuzzy matching uses stable subsequence ranking; its scores are not identical to fzf.

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
`web/` contains webapps, GitHub, Azure and n8n, and `remotes/` contains the VM/RDP
scripts. The other providers are named `<provider>.sh`. Browser selection,
work/personal filtering, editor profiles and cache rebuild flags are preserved.
Shared browser/status helpers remain in Zsh, and URL cleaning remains in Qutebrowser.

Private configuration lives beside its provider and stays Git-ignored:

- `_common/utils.env`: shared category settings.
- `web/webapps.env` and `web/n8n.env`: JSON picker entries.
- `remotes/hosts.json`: VM/RDP hosts; `hosts.json.sample` documents the format.
  RDP option strings support quotes and backslash escapes; shell expressions and
  wildcards are passed literally.
- `directories.env`: JSON directory entries.
- `screenshot.env`: Bash `SCREENSHOT_FOLDER` setting.
- `recording.env`: Bash `VIDEOS_FOLDER`, `HEADPHONES` and `MIC` settings.

Hyprland bindings call `launcher.sh provider NAME [ARGS...]`; new callers should
use this entry point rather than reaching into the provider tree. Books and Azure
use `--pick`; both also support `--rebuild-cache`. Qutebrowser's media shortcuts
call `provider media TITLE URL`. Run `:config-source` in an already-running
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
