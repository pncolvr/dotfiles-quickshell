# Recent files

Hover the file icon beside the clock to see recently used files. Click the
icon to pin the list. Each row shows the filename, its folder, and when it was
last used. Click a row to open the file with its default application, or drag it
into a file manager, editor, chat, or another application that accepts files.

The drag supplies the actual file's `file://` URI as `text/uri-list` and offers
the copy action. The destination decides whether to open, attach, or copy it.
The source file stays in place. The panel stays open and its list stops refreshing
until the drag finishes, even when the pointer leaves the panel.

## Folder tabs

The panel always opens on **Recent**. Use the **+** at the far right to pick a
directory and add its own tab. The picker pins the panel so it stays open while
you choose. Each folder tab has a small **×** to remove it from the panel;
removing a tab leaves its folder and files in place. Saved folder tabs survive
shell restarts. Picking the same folder again, including through a symlink,
selects its existing tab.

Each folder shows at most 20 readable files directly inside it, newest first.
Recency uses the later of its modified and creation timestamps; where creation
time is unavailable, modified time applies. Both Recent and folder tabs use
natural filename order when timestamps match (`Track 2` precedes `Track 10`),
before limiting the list. Folder tabs use the same file rows,
click-to-open, and native drag as Recent. The Recent age/count settings apply to
the Recent tab. Refresh updates the selected tab.

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
readable local files are shown; directories, remote URLs, and records marked
private by their application are skipped. Applications that do not register
their files in this store will not appear here.

The panel reuses the shared tooltip and scrollbar. File drag uses
[Qt Quick's native Drag API](https://doc.qt.io/qt-6.11/qml-qtquick-drag.html), with
`Drag.Automatic` to reach other applications. Test the final drop on the Wayland
desktop with a destination that supports file drops; the offscreen test backend
cannot perform a cross-application drop.

[Development checks](../development.md#recent-files)
