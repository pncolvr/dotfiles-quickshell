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

Scrollable modules use `UI.ScrollBar` from `src/theme/ui/components/ScrollBar.qml`.
It overlays the content with an accent-colored thumb during scrolling or hover,
then fades away. Keep content and row widths equal to the viewport width; do not
reserve a gutter or change panel dimensions when a scrollbar appears. The shared
component draws above the content and handles both vertical and horizontal bars.

Inline editors use `UI.EditorActions` for a neutral Cancel button followed by an
accent Apply button. Recent files, TOTP, and Twitch share this component.

## Countdowns and timers

Run `bash tests/time/timers.sh` for timestamp-based countdown and elapsed timer
behavior, pause/resume, resets, reuse of completed countdowns, bar priority,
warning colors, UI controls, scrolling and restoration across shell restarts.
The offscreen test uses isolated runtime data and mocks `canberra-gtk-play`;
it checks that each completed countdown sounds exactly once.
Set `TIMERS_TEST_SCREENSHOT=/tmp/timers.png` to save a panel preview.

## Recent files

Run `bash tests/files/recent-files.sh` for startup module and tooltip resolution,
XBEL source filtering, age/count limits, missing files, URI escaping, dependency
errors, active-tab refresh, folder selection/removal, panel actions, default-tab persistence and deletion fallback,
alias persistence, Apply/Cancel styling, Cancel and Escape dismissal,
unlimited folder contents, directory double-click navigation, Go up, navigation refresh and tab resets,
newest-first and natural filename ordering, bounded lists, tab overflow, scrolling, multiple selection, double-click-to-open,
drag dismissal protection, filename tooltip interaction, document pin/unpin buttons,
conditional Pinned tabs, independent pin persistence, Recent/Pinned default selection,
default-star accent colors, pin-drop URL validation, multiple-file and queued imports,
duplicate pins, deleted-file cleanup, and model-update deferral during drag.
The pin-order fixture also checks delayed tab activation and cancellation,
source survival across tab changes, insertion positions, grouped moves,
self-drops, and ordering after a shell restart.
The tests use temporary history, folders, and a
private database; they do not alter desktop history or saved folder preferences.
Set `RECENT_FILES_TEST_SCREENSHOT=/tmp/recent-files.png` to save a panel preview.
Set `RECENT_FOLDERS_TEST_SCREENSHOT=/tmp/folder-tabs.png` for a folder tab preview.
On the Wayland desktop, drag a row into another app that accepts files and verify
the destination receives the file. Also drop files from a file manager onto the
Pinned header and list. The offscreen tests exercise the pin-drop adapter and
storage, and keep an internal drag source alive across a tab change. Check native
cross-tab hover, reordering, and edge scrolling on Wayland; the offscreen platform
cannot transfer a native drag between applications.

## Status and timecard

Run `bash tests/status/status.sh` to check the existing timecard executable against
isolated logs, today's summary and blocks, current/last week boundaries, empty days, malformed
events, source preservation, module imports, scrolling, refresh, and mode actions.
The status manager is mocked, so the tests do not change the desktop mode,
wallpaper, or activity log. `TIMECARD_TEST_EXECUTABLE` can point to another build.
Set `STATUS_TEST_SCREENSHOT=/tmp/status-timecard.png` to save a tooltip preview.

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

Audio and notification panels share `UI.TabBar`, including the active underline,
hover styling, and keyboard navigation.

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

## Stats

Run `bash tests/system/stats.sh` for Bash process snapshots, IPv4/IPv6 and UDP
socket ownership, parent/name grouping, launcher boundaries, ambiguous PIDs, capture failures, native file readings, process
deltas and sorting, tab activation, typing and focus retention, filtering, stable panel height, expand/collapse, subprocess usage and PID copying, expansion persistence, scrolling and pinning.
The tests use private storage and a mock clipboard; power controls are mocked.
The checks cover helper-role labels, table headers, count badges and separate
network rate columns. Set `STATS_TEST_SCREENSHOT=/tmp/stats.png` to save a CPU
tab preview, or `STATS_TEST_NETWORK_SCREENSHOT=/tmp/stats-network.png` for Network.

## Panel search

```sh
python3 tests/ui/tooltip-search.py
```

This uses a fake compositor socket and checks typing, focus, mouse movement,
and dismissal without moving the real mouse.

## Service failure regressions

```sh
bash tests/system/services.sh
bash tests/system/update-cache.sh
bash tests/launcher/providers.sh
```

These use private runtime data and mocked desktop commands. They check that failed
clipboard database reads preserve payloads, cleanup failures can be retried,
removed network interfaces stop contributing traffic, rates use elapsed time,
escaped NetworkManager fields retain their names and connection states, and failed
or malformed update reads preserve the last successful list. Update-cache checks
cover atomic publication of populated and empty snapshots and query/write failures.
Provider checks include recording cancellation at each picker and literal shell
characters in RDP credentials, recording paths, and audio devices.

[Documentation](README.md)
