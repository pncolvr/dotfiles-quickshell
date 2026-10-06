# Development

Run the following commands from the repository root.

## Layout

```text
shell.qml          Quickshell entry point and startup pragmas
src/
  Bar.qml          Per-monitor bar
  bar/             Module placement and shared windows
  modules/         Feature UI
  services/        Native services, repositories and Bash helpers
  config/          Settings, intervals and update helper
  theme/           Styling and shared UI components
  assets/          Images
docs/              Setup, usage and implementation details
tests/             Helper, QML and integration checks
data/              Local runtime database (ignored by Git)
config -> src/config  Compatibility link for existing update hooks
```

Keep related QML directories together under `src/` so their relative imports
and asset URLs remain valid. Update test imports and copied fixtures when moving
files. Keep the root entry point and runtime data path stable.

## QML lint and editor

Run `bash tests/qml/lint.sh` to check every QML file with Qt 6, including unused
imports. The script rejects Qt 5 tools and accepts `QMLLINT` for a custom Qt 6
executable. VS Code uses the system Qt 6 language server and QML import directory
through `.vscode/settings.json`; reload the editor window after changing these
settings.

The QML files contain scoped lint exceptions for incomplete Quickshell type
metadata: runtime-selected `PanelWindow` backends, the missing
`QProcess::ExitStatus` enum, and the tray menu handle's outdated C++ type name.
Other warnings remain enabled, including signal checks outside those handlers.

## Notifications

```sh
bash tests/notifications/notifications.sh
bash tests/notifications/notifications.sh --wayland
bash tests/notifications/startup.sh
bash tests/storage/storage.sh
bash tests/qml/lint.sh
```

The notification tests use a private D-Bus session and temporary databases, with
Hypr commands mocked. They check protocol receipt, replacement, expiry and close
reasons; source policies; action/click behavior; durable images; pagination; schema
migration; and reload/restart persistence. `--wayland` also briefly displays the
test popup/manager on the current desktop, checks bounded layer surfaces and saves
a sample manager image to `/tmp/quickshell-notifications-preview.png`. The tests
also send a title-only notification with `notify-send` and verify its history
survives expiry and restart. Tests need `notify-send`, `python-dbus`, PyGObject and
QtTest; these are test dependencies only.
The startup test briefly launches a temporary copy of the complete shell on the
current Wayland desktop with notifications enabled by default. It checks
the real module loader, with a private D-Bus session and mocked startup commands.

## Storage and Twitch

```sh
bash tests/storage/storage.sh
bash tests/storage/storage.sh --ipc
```

Run `bash tests/storage/storage.sh` to check first-run creation, dropdown actions,
restart persistence, transaction rollback, avatar downloads, schedule caching, and midnight labels
using an isolated database and mock Twitch/receiver commands.
Add `--ipc` to check the real IPC commands and redirected export too.

## TOTP

Verification uses public test seeds and a fake keyring, without accessing desktop
secrets:

```sh
bash tests/security/totp.sh
bash tests/security/totp.sh --qml-smoke # headless Quickshell interaction check
```

To check native tooltip imports on the current Wayland desktop:

```sh
bash tests/security/totp.sh --qml-smoke --native-imports
```

## Audio

```sh
bash tests/audio/audio.sh
bash tests/audio/audio.sh --native-imports
```

Run `bash tests/audio/audio.sh` for routing, profile, and QML interaction checks.
Add `--native-imports` to check the complete bar, real device/profile mapping,
sorted lists, and system default bindings without changing your audio settings.

## Batteries

```sh
bash tests/system/batteries.sh
bash tests/system/batteries.sh --native-imports
```

Run `bash tests/system/batteries.sh` for the headless battery discovery and QML
card checks, including live updates, duplicates, disconnection, and scrolling.
Add `--native-imports` to verify the complete bar and live tooltip on Wayland.

## Panel search

```sh
python3 tests/ui/tooltip-search.py
```

This uses a fake compositor socket and checks typing, focus, mouse movement,
and dismissal without moving the real mouse.

[Documentation](README.md)
