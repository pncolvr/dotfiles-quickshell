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
qs ipc call twitch reload
qs ipc call twitch addUser streamer_login
qs ipc call twitch removeUser streamer_login
qs ipc call twitch exportUsers > twitch-users.txt # one login per line
qs ipc call updates reload       # reread the package update cache
qs ipc call recentfiles reload   # reread desktop recent files
qs ipc call launcher apps        # application picker
qs ipc call launcher windows all # searchable window picker
qs ipc call launcher windows current # tiled windows on the current workspace
qs ipc call launcher clipboard   # text/image history with copy and paste
qs ipc call clipboard togglePause # pause/resume history capture
qs ipc call clipboard importCopyq # import text/image history without changing CopyQ
```

Twitch exports contain lowercase logins as ordinary text. New databases start
with an empty list; there is no users-file import. See [Twitch](features/twitch.md).

[Documentation](README.md)
