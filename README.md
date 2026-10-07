# Quickshell

A desktop bar for Hyprland, built with QML and Quickshell.

## Features

- Workspaces and windows with focus and next/previous navigation
- Clock with month and year calendars
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

## Dependencies

Quickshell (developed with 0.3.1), Qt 6.10+, Hyprland, Bash, coreutils and `jq`.
Fonts: Noto Sans Mono, JetBrains Mono and Font Awesome 7 Free Solid.

Individual features use PipeWire, `pactl`, UPower, BlueZ, a Secret Service provider,
`secret-tool`, `oathtool`, the Twitch CLI and other desktop tools.
See [setup](docs/setup.md) for the full dependency list and optional integrations.

## Running

Place the repository at `~/.config/quickshell`, review the
[configuration](docs/configuration.md) for your desktop, then start it:

```sh
qs -p "$HOME/.config/quickshell"
```

No build step is required. This configuration includes a native notification
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
