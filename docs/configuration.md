# Configuration

## Files to edit

| File | Controls |
| --- | --- |
| [`src/config/Config.qml`](../src/config/Config.qml) | Commands, intervals, defaults, namespaces and feature settings |
| [`src/theme/Theme.qml`](../src/theme/Theme.qml) | Fonts, glyphs, colors, dimensions and spacing |
| [`src/bar/LeftModules.qml`](../src/bar/LeftModules.qml) | Workspaces and windows |
| [`src/bar/CenterModules.qml`](../src/bar/CenterModules.qml) | Clock, package updates and Twitch |
| [`src/bar/RightModules.qml`](../src/bar/RightModules.qml) | System, status, TOTP, batteries, notifications and tray |
| [`shell.qml`](../shell.qml) | Entry point, startup environment and dedicated windows |

## Desktop integrations

Review these defaults when adapting the configuration:

- `_internal.statusManager` points to `~/.config/zsh/scripts/status/manager.sh`.
- `submapParserCommand` points to `~/.config/hypr/scripts/keybinds/parser.sh`.
- Screen-sharing commands expect `HideApplications(active)` and related Hyprland rules.
- Update installation opens Ghostty and runs `yay`. The refresh helper is
  `src/config/update-check.sh`. The root `config` symlink preserves the old path
  for the installed pacman hook and any existing cron jobs. When those references
  use the new path, the compatibility link can be removed. See the helper's
  comments for examples.
- The temperature command reads `/sys/class/thermal/thermal_zone1/temp`.
- `calendarUrl` opens Google Calendar. `mixerCommand` opens `pavucontrol`.

Helper commands resolve relative to the configuration source. Persistent data
resolves from the shell root, so `data/quickshell.db` stays outside `src/`.

## Panels and search

Search matches streamer logins, categories and stream titles as you type, and
temporarily expands Offline to show matching results. TOTP searches token names;
notification Emitters searches names and desktop IDs above the policy filters.
Each search has a clear button and resets when its panel closes. Adding a streamer
or token temporarily hides search and suspends filtering, then restores the query.
Focusing or typing in an input pauses hover dismissal until the mouse moves.
Manual pinning remains independent; Escape clears search and releases focus.

## Shared controls

Twitch and TOTP use shared `UI.ActionButton` and `UI.InputField` controls. Shared
action glyphs such as add, cancel, delete, and check are defined once in `Theme.qml`.

TOTP and the notification manager reuse `src/bar/PrivateTooltipWindow.qml` for
their monitor selection, positioning, keyboard focus, and private layer namespace.
Both modules declare `ownsTooltipWindow`, so the shared tooltip window leaves
their content to the dedicated window without checking module names.

Feature guides describe the individual controls and settings:
[notifications](features/notifications.md), [Twitch](features/twitch.md),
[TOTP](features/totp.md), [audio](features/audio.md), [batteries](features/batteries.md).
Recent-file source and limits are described in [recent files](features/recent-files.md).

[Documentation](README.md)
