# Recent files

Hover the file icon beside the clock to see recently used files. Click the
icon to pin the list. Each row shows the filename, its folder, and when it was
last used. Click a row to select it, double-click to open it with its default application, or drag it
into a file manager, editor, chat, or another application that accepts files.
Hover a filename or its folder text to read the full name or folder path when
the row truncates it.

Ctrl-click toggles individual files; Shift-click selects a range from the last
clicked file. Ctrl+Shift-click adds a range to the existing selection. Ctrl+A
selects all files in the tab, and Escape clears the selection. Dragging a selected
row sends all selected files; dragging an unselected row selects it first.
Selection survives refresh for files still listed and clears when switching tabs
or navigating folders.

The drag supplies each selected file's `file://` URI as `text/uri-list` and offers
the copy action. The destination decides whether to open, attach, or copy it.
The source file stays in place. The panel stays open and its list stops refreshing
until the drag finishes, even when the pointer leaves the panel.

## Pinned files

Use the **pin** button at the right of a file row to keep the document in
**Pinned**. The highlighted pin marks a saved document; click it again in any
tab to unpin that file. Directories do not have pin buttons.

Drop files onto the **Pinned** tab header, or anywhere in its file list, to pin
them. Multiple files can be dropped together, including from Recent or folder
tabs. The target highlights in the accent color. Drops keep the current tab in
place and skip existing pins, directories, and missing or unreadable files.
Only local files are accepted; pinning does not move or copy their contents.
When no pins exist, use a row's pin button to create the first one and reveal
the Pinned tab.

The Pinned tab appears only when pinned documents exist. Pins survive shell
restarts, removal of their original folder tab, and the Recent age/count limits.
They also survive clearing the desktop's recent-file history. Pinned uses the
same file rows, selection, double-click opening, and drag behavior as other tabs.
Pinning a document keeps the current tab and selection in place.

Pins are stored independently in the existing preferences database. They are
removed only by manually unpinning a file or when its path no longer exists.
Existence is checked when the panel opens, on refresh, and every
`recentFilesRefreshInterval`, including while the panel is closed. An unreadable
document is retained; a check that cannot access its parent directories does not
remove it. Deletion cleanup waits for an active drag to finish. Removing the last
pin hides Pinned and returns to Recent if Pinned was selected.

## Default tab

Select **Recent**, **Pinned**, or a folder tab and use the **star** button beside
its description or path to make it the default. The current default's star uses
the accent color; other tabs show a neutral star. The choice survives closing the
panel and restarting the shell. Existing folder defaults are preserved.

Click the highlighted star on Pinned or a folder to reset the default to Recent,
or select Recent and use its star directly. Removing the default folder or the
last pinned document resets its default to Recent.

## Folder tabs

Use the **pen** button beside the selected folder's path to edit its tab name.
Enter its alias and press Enter or the accent check button to apply; Cancel or
Escape dismisses the form without saving.
Saving a blank name restores the folder's original name. Aliases survive restarts and do not change the folder path,
file list, selection, or default choice. Removing a tab also removes its alias.

Use the **+** at the far right to pick a
directory and add its own tab. The picker pins the panel so it stays open while
you choose. Select a folder and use the red **trash** button beside its path to
remove its tab; removing a tab leaves its folder and files in place. Saved folder tabs survive
shell restarts. Picking the same folder again, including through a symlink,
selects its existing tab.

Folder tabs list all readable files and directories directly inside the current
folder, with directories first and newest-first sorting within each group.
Double-click a directory to browse it in the same tab;
use **Go up** beside the path to return to its parent. Go up is disabled at the
tab's starting folder. Refresh rescans the folder currently being browsed.
Selecting a tab or reopening the panel returns to its starting folder. Aliases,
default choice, and removal apply to the saved tab throughout navigation.
Recency uses the later of its modified and creation timestamps; where creation
time is unavailable, modified time applies. Both Recent and folder tabs use
natural filename order when timestamps match (`Track 2` precedes `Track 10`),
before limiting Recent. Folder tabs use the same file rows, selection,
double-click-to-open for files, and native drag as Recent. The Recent age/count
settings apply only to the Recent tab; its default item limit is 20.

When many tabs exceed the header width, the tab strip scrolls horizontally by
dragging, touchpad, or mouse wheel.
The **+** button stays fixed at the far right.

## Limits and source

In `src/config/Config.qml`:

- `recentFilesMaxItems`: maximum number of files, newest first; defaults to 20.
- `recentFilesMaxDays`: only files used within this many days; defaults to 7.
- `recentFilesRefreshInterval`: refresh while the panel is open; defaults to 30 seconds.
- `recentFilesPath`: the desktop's `recently-used.xbel` store in `$XDG_DATA_HOME`
  or `~/.local/share`.

Both limits apply together. Set either limit to `0` to disable it; for example,
`recentFilesMaxDays: 0` gives the latest 20 files regardless of age. Opening the
panel refreshes it immediately, and the refresh button or
`qs ipc call recentfiles reload` requests another refresh.

The Bash helper reads the desktop's
[XBEL bookmark store](https://wiki.freedesktop.org/www/Specifications/desktop-bookmark-spec/)
using `xsltproc` for XML and `jq` for JSON. It requires Bash, GNU coreutils,
`jq`, and `libxslt` (which supplies `xsltproc`). Folder scans also use GNU
`findutils`. It reads the existing store
without modifying it. Only existing,
readable local files are shown in Recent; directories, remote URLs, and records marked
private by their application are skipped. Applications that do not register
their files in this store will not appear here.

The panel reuses the shared tooltip and scrollbar. File drag uses
[Qt Quick's native Drag API](https://doc.qt.io/qt-6.11/qml-qtquick-drag.html), with
`Drag.Automatic` to reach other applications. Test the final drop on the Wayland
desktop with a destination that supports file drops; the offscreen test backend
cannot perform a cross-application drop.

[Development checks](../development.md#recent-files)
