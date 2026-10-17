# Quickshell

A desktop bar for Hyprland, built with QML and Quickshell.

## Features

- Workspaces and windows with focus and next/previous navigation
- Clock with month and year calendars
- Countdowns and elapsed timers with pause/resume, alarms and bar time remaining
- CPU, memory, temperature and network stats
- Microphone and volume controls with device selection and audio profiles
- Screen-sharing status and sound notifications
- Package update indicator
- Twitch follows, live streams and schedules
- TOTP codes with copying and token management
- Laptop and peripheral battery levels
- Notifications with saved history, DND and per-app settings
- Recent files and saved folder tabs with newest-first lists and file drag into other applications
- Work/personal mode with daily totals and detailed timecards
- System tray, keybind hints and alerts
- IPC commands for scripts and Hyprland bindings
- Application/window launcher, reusable Bash pickers and text/image clipboard history

## Dependencies

Quickshell (currently checked with 0.3.2), Qt 6.10+, Hyprland with its Lua API, Bash, coreutils, `jq`, and
`sqlite3` with FTS5 support (SQLite 3.42+).
Fonts: Noto Sans Mono, JetBrains Mono and Font Awesome 7 Free Solid.

Individual features use PipeWire, `pactl`, UPower, BlueZ, a Secret Service provider,
`secret-tool`, `oathtool`, the Twitch CLI and other desktop tools.
See [setup](docs/setup.md) for the full dependency list and optional integrations.
Start with the [Arch installation guide](docs/install-arch.md) and the
[first-run checklist](docs/setup.md#first-run-checklist). Installation instructions
currently cover Arch only.
Optional switches are grouped at the top of `config/Config.qml`; the tracked
configuration currently enables them, so review that block before first launch.

## Running

Place the repository at `~/.config/quickshell`, review the
[configuration](docs/configuration.md) for your desktop, then start it:

```sh
qs -p "$HOME/.config/quickshell"
```

No manual QML build step is required; the optional audio spectrum helper compiles
on first use. This configuration includes a native notification
server; see [setup](docs/setup.md#notification-ownership) if another server is running.

## Checks

```sh
bash tests/qml/lint.sh
```

See [development](docs/development.md) for feature and integration tests.

## Documentation

[Browse the docs](docs/README.md) for setup, configuration, feature guides,
IPC commands, storage details and troubleshooting. Source files live in `src/`;
local runtime data lives in `data/`.
