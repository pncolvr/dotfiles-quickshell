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

Changing audio glyphs use `UI.FixedIconText`, with a centered icon in a fixed
slot. `AudioButton` uses `Theme.iconButtonWidth`; bar icons use `UI.BarIcon` and
the compact `Theme.barIconWidth` slot. All bar module icons share that width, so
their centers remain evenly spaced and state changes do not resize controls.

Static images use `UI.ScaledImage` for smooth filtering and mipmaps, with aspect
fit by default. Keep source sizing, cropping and asynchronous loading at the
call site when needed. Live captures use `UI.ScaledScreencopyView`, which generates
smooth mipmaps through a source-resolution layer even during parent transforms.
Live capture pauses when its view or containing window is hidden.
Generated image masks use `UI.ScaledTexture`. All three components read smooth
filtering and mipmap settings from the shared `UI.TextureSettings` singleton. Use these shared
components for new images and captures rather than duplicating their settings.

Panel-only polling runs while a panel is open and stops when its last instance
closes. Recent files and pinned-file existence checks share that lifecycle.
Notifications schedule a single timer for the next expiration; persistent or
hover-paused notifications do not poll; popup countdown animations also stop
when their window is hidden. Closed panels release their loaders,
including media position queries and Exposé captures. Bar state still needs
clock updates, running countdowns, periodic connectivity/battery/Twitch checks
and event subscriptions. Mute and screen-sharing pulses deliberately keep
rendering while active; measure truly idle CPU with no ongoing animation.

Pulsing text caches its glyph in a layer and blends colors in the shared
`PulseText` shader. `UniformAnimator` runs the existing two-second sine pulse on
the render thread, avoiding per-frame JavaScript and text-color updates. The
shader's sine curve uses a shared elapsed-time origin, so later-starting or
reshown indicators join the same pulse phase. Each effect synchronizes once after
its first rendered frame, then disconnects that signal; no per-frame global timer
or JavaScript synchronization runs. The
layer and animation share one gate: a requested pulse, visible text and a visible
containing window. Hiding either stops the animation and releases the layer;
showing it again resumes the requested pulse. Muted mic and speaker indicators
pulse only while an application's active PipeWire link requests their default
device. Paused links and requests routed to another device do not keep them
animating. Screen sharing pulses while sharing is active. Duration and colors
remain in Theme.qml. Rendering still runs while the pulse is active.
Default-device link groups must be bound with `PwObjectTracker` before their
state can be used; an unbound group's state does not reflect active audio.
Run `bash tests/qml/pulse.sh` in a Wayland session to verify rendered colors and
stopping behavior; software/offscreen tests cannot validate this GPU effect.
The shader source and compiled bundle are both tracked. After changing it, rebuild:

```sh
/usr/lib/qt6/bin/qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 \
  -o src/theme/shaders/pulse.frag.qsb src/theme/shaders/pulse.frag
```

Scrollable modules use `UI.ScrollBar` from `src/theme/ui/components/ScrollBar.qml`.
It overlays the content with an accent-colored thumb during scrolling or hover,
then fades away. Keep content and row widths equal to the viewport width; do not
reserve a gutter or change panel dimensions when a scrollbar appears. The shared
component draws above the content and handles both vertical and horizontal bars.

Large expandable lists can use `UI.BatchedListModel` to add a few rows per
rendered frame while preserving existing delegates. Run
`bash tests/qml/batched-model.sh` for expansion, collapse and source-change checks.

Button and slider focus decorations use Qt's `visualFocus`, which indicates
keyboard navigation, rather than `activeFocus`. Clicking must not leave a focus
border after release. Shared buttons and custom controls use `UI.PointerFocus`
to change an existing keyboard focus to pointer focus on press. Run
`bash tests/qml/button-focus.sh` to check pointer/keyboard transitions and clicks.
Selected tabs, active devices and input-field borders
continue to indicate their own states.

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
`STATUS_TEST_DETECTION_SCREENSHOT` saves Today's automatic detection section.
Run `bash tests/status/detection.sh` for distinct process/path reporting, literal
directory boundaries, quoted/newline paths, detector failures and read-only manager
output. It uses mocked processes and `lsof` data; `STATUS_DETECTION_SCRIPT` and
`STATUS_MANAGER_SCRIPT` can point to a prepared copy of the zsh manager/helper.

## Projects

Run `bash tests/projects/projects.sh` for native project sources, workspace
selection/editing, category choices, manual refresh, failed scan preservation,
launch profiles and restart persistence. The suite uses isolated Git/non-Git
folders, mocked launch commands, Bash, jq, sqlite3 and an offscreen QML window.
Run `bash tests/projects/folder-picker.sh` in a Wayland session to verify that
Ctrl+A opens Add from focused Projects and Manage searches, and accepting or cancelling the native
folder picker keeps Manage open and restores its keyboard focus. This test
briefly shows an isolated picker and folder dialog.
`bash tests/launcher/providers.sh` also checks that code/GitHub dispatch to native
IPC without a project cache file.

## Notifications

```sh
bash tests/notifications/notifications.sh
bash tests/notifications/notifications.sh --wayland
bash tests/notifications/startup.sh
bash tests/storage/storage.sh
bash tests/directories/directories.sh
bash tests/qml/lint.sh
```

The notification tests use a private D-Bus session and temporary databases, with
Hypr commands mocked. They check protocol receipt, replacement, expiry and close
reasons; source policies; action/click behavior; durable images; pagination; schema
migration; and reload/restart persistence. `--wayland` also briefly displays the
test popup/manager on the current desktop, checks bounded layer surfaces and saves
a sample manager image to `/tmp/quickshell-notifications-preview.png`. The tests
also send a title-only notification with `notify-send` and verify its history
survives expiry and restart. The Bash runner uses `gdbus` for protocol calls and
signal monitoring, `jq` for assertions, and `sqlite3` for migration fixtures.
Tests also need `notify-send` and QtTest; these are test dependencies only.
Offscreen tests verify the legacy Twitch URL request in Qt's log; `--wayland`
also verifies that request reaches the mocked browser opener.
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

Run `bash tests/storage/twitch-fallback.sh` for main/second-channel selection, database
migration, explicit linking, editing, unlinking, removal and Undo, restart
persistence, and main-only alerts. It also checks requests across the
[Helix 100-channel limit](https://dev.twitch.tv/docs/api/reference/#get-streams)
and preserves the previous live list when a later batch fails. Both storage
suites use Bash, jq, sqlite3, and isolated QML fixtures.

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
bash tests/audio/media.sh
bash tests/audio/spectrum.sh
bash tests/audio/media-visualizer.sh
bash tests/audio/media-visualizer.sh --native
bash tests/audio/media-visualizer.sh --gpu
bash tests/audio/media-fullscreen.sh
bash tests/audio/audio.sh --native-imports
bash tests/audio/screencast.sh
bash tests/audio/screencast.sh --native
```

Run `bash tests/audio/audio.sh` for routing, profile, and QML interaction checks.
`bash tests/audio/media.sh` checks transport capabilities, artwork loading,
the all-player list, timeline dragging and capability checks, screen-height
limits, track metadata changes, late position responses, elapsed-time limits,
preserved scroll position, stream-control visibility and safe association with app audio streams
using isolated player fixtures without controlling desktop playback.
`bash tests/audio/media-visualizer.sh` checks both flip directions, effect
selection of all 17 presets, stable card sizing, independent frequency bands, PCM
waveforms, opaque scrolling effect rows, full-card layers on both faces, and
pause/visibility gates. A fresh engine checks that the selected effect survives
restart and applies to new cards from the same app, while other apps keep their
own effects. It also checks desktop identity normalization and the previous global default.
Idle checks verify that paused, muted, transparent, hidden and offscreen cards
stop analysis, detach their texture source, clear native geometry and unload both
face renderers. Shader presets skip native geometry calculations.
`bash tests/audio/spectrum.sh` builds the native helper and feeds deterministic
PCM into cavacore to check bass/treble separation, opposite-phase stereo, silence,
normalized spectrum/signed-waveform frame bounds and rejection of a default-output target.
`--native` creates a private D-Bus session and PipeWire server, disables hardware
discovery in its WirePlumber instance, and plays separate bass and treble apps into
one silent virtual sink. It checks that only the matched app's bands appear, and
that its shared native analyzer exits during flips and resumes on either face. Desktop playback
is unaffected. Set `MEDIA_VISUALIZER_FRONT` and `MEDIA_VISUALIZER_BACK` to PNG
paths to save previews of each face.
`--gpu` briefly opens the fixture on Wayland, verifies Qt Quick's GPU curve
renderer, and cycles all styles to check the compiled CAVA shader pipelines and
pause/unload behavior. On Hyprland it restores the previous focus and pointer
afterward. Set `MEDIA_VISUALIZER_STYLE_DIR` to save a PNG of every preset.

`bash tests/audio/media-fullscreen.sh` briefly opens a fullscreen Wayland fixture
on the current monitor and restores focus and pointer position afterward. It
checks opaque single-view fullscreen, scrolling effect selection, native-resolution
live rendering without an intermediate texture, cached artwork, two-percent bottom margins, player navigation, both
slide directions, frozen-frame cleanup, and repeated-navigation handling, plus
shared playback and stream controls. Exit checks cover focused lists and sliders,
entry and slide cancellation, Alt+F4, and a deliberately stalled closing animation to verify
the cleanup deadline. It also checks pause/mute gates, saved effects, player
removal and disabled animations. Set `MEDIA_FULLSCREEN_SCREENSHOT` to save a
preview, or `MEDIA_FULLSCREEN_TRACE=1` for fixture phase logging.
GPU checks also verify that fresh audio levels request a frame without an ongoing
animation, reach the band texture, interpolate to intermediate pixels, and stop
interpolating on pause.

The original CAVA 1.0.0 shader sources, Qt ports, and compiled bundles are tracked
under `src/theme/shaders/cava`. Rebuild all shader stages with:

```sh
python3 src/theme/shaders/cava/build.py
```
Add `--native-imports` to check the complete bar, real device/profile mapping,
sorted lists, and system default bindings without changing your audio settings.
The screencast checks use Qt 6 tests for independent captures, webcam exclusion,
and description fallbacks. `--native` additionally creates two disposable video
nodes on a private PipeWire server and checks their descriptions in the real
tooltip. The native fixture requires `pw-cli`; it does not affect desktop captures.

`bash tests/ui/twitch-panel.sh` briefly opens isolated panels on Wayland and
restores focus and pointer afterward. It verifies Twitch and TOTP search focus,
pointer targeting, repeated opens, editor cancellation, pins, Escape, `twi`
typing in TOTP, hidden-module handling, and volume opening without clicking.
It also checks panel reuse, pointer placement after bar layout changes, and
tray expansion without an extra mouse movement, button-edge hover, and dismissal
when the pointer leaves.
The TOTP keyring and runtime storage are isolated.

Bar modules declare their own `moduleName`; Twitch and TOTP also set
`moduleFocusSearch: true`. `TooltipArea` registers those modules with
`BarModuleService`, while the tray registers its own trigger. Bar layout files
only supply placement and window references. Capture detection lives in
`services/audio/ScreencastModel.qml`, whose stream list follows its native
PipeWire node and link inputs.

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

Run `bash tests/ui/twitch-panel.sh` on Wayland to check Twitch open IPC,
opening without auto-pinning, search focus and typing, on-demand focus after
activation, pointer placement on the icon, repeated opening, add cancellation,
manual pin preservation, Escape and mouse-click pin toggling. When a window was
focused before the test, it also checks focusing that window while Twitch is
manually pinned, then refocusing Twitch through IPC. It briefly opens an
isolated panel, then restores the previous window focus and pointer position.

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
cover UTF-8 query/IPC locales, pacman database lock deferral,
repository/AUR queries, yay age suffixes, atomic publication of populated
and empty snapshots, query/write failures, interrupted runs, locking and stale
temporary file cleanup.
Provider checks include recording cancellation at each picker and literal shell
characters in RDP credentials, recording paths, and audio devices.

[Documentation](README.md)

### rbw manager checks

`bash tests/security/rbw-manager/run.sh` exercises the Bash backend and actual
QML manager panel with synthetic rbw/clipboard processes. It covers stdin-only
secret writes, protected entries, stale baselines, generation, confirmations,
draft clearing, locking, copy expiry and late results. The optional
`bash tests/security/rbw-manager/native.sh` checks the manager's private namespace
through the compositor without accessing the real vault or clipboard.
