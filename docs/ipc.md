# IPC

Call shell functions from scripts or Hyprland bindings. If multiple configurations
are running, select this one with `qs ipc -p "$HOME/.config/quickshell" call …`.

```sh
qs ipc call shell reload         # reload the whole shell and recreate windows
qs ipc call alerts post example "Custom message" info 3000 # milliseconds; 0 persists
qs ipc call alerts dismiss example # remove by message ID
qs ipc call notifications reload # resynchronize notification/capture status
qs ipc call notifications toggle # toggle DND
qs ipc call status reload        # refresh mode and any open timecard tooltip
qs ipc call windows next
qs ipc call windows prev
qs ipc call windows reload
qs ipc call windows focus 0      # grouped window index
qs ipc call bar open twitch      # open panel, focus search and move pointer
qs ipc call bar open totp        # open TOTP panel and focus search
qs ipc call bar open batteries   # open panel and move pointer to icon
qs ipc call twitch reload
qs ipc call twitch addUser streamer_login
qs ipc call twitch removeUser streamer_login
qs ipc call backup create /absolute/path/backup.7z # private password prompt
qs ipc call backup restore /absolute/path/backup.7z # replaces saved data and TOTP entries
qs ipc call backup status        # progress, errors and recovery location
qs ipc call updates reload       # reread the package update cache
qs ipc call recentfiles reload   # reread desktop recent files
qs ipc call launcher apps        # application picker
qs ipc call launcher projects    # Projects picker; Ctrl+M toggles Manage
qs ipc call launcher directories # directory picker; Ctrl+M toggles Manage
qs ipc call launcher projectUrls # project remote URLs with multiple selection
qs ipc call launcher windows all # searchable window picker
qs ipc call launcher windows current # tiled windows on the current workspace
qs ipc call launcher clipboard   # text/image history with copy and paste
qs ipc call clipboard togglePause # pause/resume history capture
qs ipc call clipboard importCopyq # import text/image history without changing CopyQ
```

**Meta+Period**, then **R**, reloads Quickshell from Hyprland's tools submap.
The submap exits after selection. Reload closes open panels and rebuilds the shell.

See [bar alerts](features/alerts.md) for severities, replacement and expiration.

`qs ipc call recording toggle` starts setup, cancels the starting delay, or stops
the current owned recorder. `qs ipc call recording status` returns its state,
active flag and destination as JSON. The detached worker survives bar restarts
and Config/theme reloads; see [screen recording](features/recording.md).

Backups include the database, clipboard payloads and TOTP secrets in a password-protected
7z archive with encrypted filenames. The existing private secret picker offers
Generate and Copy buttons when creating a backup. Enter starts the operation;
Escape cancels the prompt. Progress uses the bar alert tooltip. Creation success
shows the saved archive path for 15 seconds; errors expire after 1 minute and can
be cleared sooner by dismissal or another attempt/reload. IPC returns whether
the prompt opened; use `backup status` for completion and `.report` for the last
import's unavailable paths and unchecked remote locations, even after reload.
A successful restore reloads
the shell. Existing output files are never overwritten. See [backups](storage.md#backups).
`backup status` also returns `completed` and `output` for the current operation;
`busy: false` can indicate either completion or failure, so check `error` too.
`twitch exportUsers` has been removed; Twitch users and second-channel associations
are included in the database backup.

**Meta+I** enters a one-shot module submap. Selection, Escape, or an unassigned
key exits it. `bar open` returns false for hidden or unknown modules and targets
the focused monitor. It opens panels by hover without triggering click actions.
Repeated selection reuses the open panel. Pointer placement follows bar layout
changes and targets the full module button; the tray expands immediately.
Twitch and TOTP also focus search. The capture-state and submap badges have no
panels. Available module names and shortcut keys:

| Key | Module | Key | Module |
| --- | --- | --- | --- |
| `u` | `updates` | `c` | `clock` |
| `f` | `files` | `r` | `timers` |
| `m` | `mic` | `v` | `volume` |
| `s` | `stats` | `t` | `twitch` |
| `w` | `status` | `p` | `totp` |
| `b` | `batteries` | `n` | `notifications` |
| `a` | `tray` | `h` | `sharing` |

[Documentation](README.md)
