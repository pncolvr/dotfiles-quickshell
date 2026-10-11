# Bar alerts

The alert panel appears beneath the right edge of the bar whenever messages are
present. It requires no hover, adds no bar icon and does not take keyboard focus.
Messages appear as text rows; the panel disappears when the last message is removed.
This panel is separate from desktop notifications and their history.

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

Network connectivity is checked at startup by `Config.networkCheckCommand`, which
pings `1.1.1.1`. Failure posts the persistent error `no internet access`; success
dismisses it. Failed checks retry every `Config.networkRetryInterval` (5 seconds),
and successful checks repeat every `Config.networkAlertInterval` (1 minute).
A failed ping does not distinguish disconnection from blocked ICMP.

The recording provider uses the `recording` ID for its starting, stopped and error
messages. Starting and stopped messages expire after 1 second; errors after
3 seconds. The starting message is explicitly dismissed after the existing
1.1-second delay, before `wf-recorder` starts. Completion and error messages are
posted after the recorder exits. These messages replace Hyprland notifications;
they are not displayed during capture by this provider. Other independently
posted alerts remain visible and can appear in recordings.

[Documentation](../README.md)
