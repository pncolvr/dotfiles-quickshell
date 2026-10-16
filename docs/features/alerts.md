# Bar alerts

The alert panel appears beneath the right edge of the bar whenever messages are
present. It requires no hover, adds no bar icon and does not take keyboard focus.
Messages appear as text rows; the panel disappears when the last message is removed.
This panel is separate from desktop notifications and their history.
Each bar uses its own monitor's alert surface. Alerts use the overlay layer so
they remain visible over fullscreen applications without taking keyboard focus.
Long messages wrap within the monitor width.

## Custom messages

```sh
qs ipc call alerts post recording "Recording starting" success 1000
qs ipc call alerts dismiss recording
```

`post` takes an ID, text, severity and duration in milliseconds. Reusing an ID
replaces that message and resets its expiration. Duration `0` keeps the message
until explicitly dismissed. Supported severities are `info` (text color),
`success` (OK color), `warning` (warning color) and `error` (urgent color).
Empty IDs or text, unknown severities and negative durations are rejected.
Messages live in memory and are cleared when Quickshell reloads.

For scripts, select the configuration explicitly when multiple shells are running:

```sh
qs ipc -p "$HOME/.config/quickshell" call alerts post example "Custom message" info 3000
```

## Current callers

Backups use the `backup` ID for preparation, database/clipboard processing,
keyring access and encryption/restoration stages. Each stage replaces the prior
message. Progress stays visible while the operation runs. Export completion says
"Backup created:" followed by the saved archive path and lasts 15 seconds.
Failures expire after 1 minute and can be cleared sooner by the next backup/restore
prompt, explicit dismissal (`qs ipc call alerts dismiss backup`), or shell reload.
The error remains available through `qs ipc call backup status`. Restore reloads the shell
after completion and shows its result again from the saved import report.

Network connectivity is checked at startup by `Config.networkCheckCommand`, which
pings `1.1.1.1`. Failure posts the persistent error `no internet access`; success
dismisses it. Failed checks retry every `Config.networkRetryInterval` (5 seconds),
and successful checks repeat every `Config.networkAlertInterval` (1 minute).
A failed ping does not distinguish disconnection from blocked ICMP.

Work/personal mode changes use the `status-mode` ID with “Work mode” or
“Personal mode” for three seconds. Manual overrides, automatic detection and Reset
announce changes in the effective mode; selecting the same mode and restoring it
on startup/reload stay quiet. Rapid changes replace the same alert row. Work mode
can be disabled without emitting a mode-change alert.

The [recording worker](recording.md) uses the `recording` ID for starting,
finishing, cancelled, stopped and error messages. Starting and stopped messages
expire after 1 second; errors after 3 seconds. The starting message is explicitly
dismissed after the existing 1.1-second delay, before `wf-recorder` starts.
The finishing message acknowledges the stop immediately and remains until the
recorder has exited and audio cleanup has finished. It can appear in the final
captured frames. Other independently posted alerts also remain visible and can
appear in recordings.

[Documentation](../README.md)
