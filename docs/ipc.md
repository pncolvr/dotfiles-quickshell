# IPC

Call shell functions from scripts or Hyprland bindings. If multiple configurations
are running, select this one with `qs ipc -p "$HOME/.config/quickshell" call …`.

```sh
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
qs ipc call twitch exportUsers > twitch-users.txt # one login per line
qs ipc call updates reload       # reread the package update cache
qs ipc call recentfiles reload   # reread desktop recent files
qs ipc call launcher apps        # application picker
qs ipc call launcher projects    # Projects picker; Ctrl+M toggles Manage
qs ipc call launcher projectUrls # project remote URLs with multiple selection
qs ipc call launcher windows all # searchable window picker
qs ipc call launcher windows current # tiled windows on the current workspace
qs ipc call launcher clipboard   # text/image history with copy and paste
qs ipc call clipboard togglePause # pause/resume history capture
qs ipc call clipboard importCopyq # import text/image history without changing CopyQ
```

Twitch exports contain lowercase main-channel logins as ordinary text; second channel
associations remain in the database. New databases start
with an empty list; there is no users-file import. See [Twitch](features/twitch.md).

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
