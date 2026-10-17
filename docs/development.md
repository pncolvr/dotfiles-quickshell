# Development

Run the following commands from the repository root.

Clipboard index checks: `bash tests/clipboard/fts/run.sh` exercises migrations,
safe literal queries, derived-index consistency, rollback, recovery and private
storage permissions. `bash tests/clipboard/fts/ui.sh` checks indexed/fuzzy search,
paging, composed image/pin filters, transitions and cleanup using synthetic data.
Set `CLIPBOARD_NARROW=1` or `CLIPBOARD_ZERO_MOTION=1` for layout/motion variants;
`CLIPBOARD_NATIVE=1` exercises the actual Wayland host. Its PNG rendering fixture
requires ImageMagick. Native fixtures that grab focus must run sequentially.
`bash tests/clipboard/fts/benchmark.sh` measures a synthetic 1,000-row/500 MB
rebuild and read-only query pipeline; `FTS_BENCH_BYTES` changes bytes per row.
These tests create temporary databases and never inspect live clipboard history.

## Theme palette checks

Run `bash tests/ui/theme.sh` to render both palettes in an isolated offscreen
fixture. It checks the original dark colors/alpha, live binding updates, shared
Theme alias identity, light text/selection/button/calendar contrast, pressed/hover
states, disabled controls, input focus and unchanged dimensions/motion settings.
Only the fixture makes darkMode writable; the real setting stays readonly.
`THEME_TEST_PREVIEWS=/tmp/theme-previews bash tests/ui/theme.sh` saves dark.png and
light.png for visual review without changing the live theme or desktop focus.
Mode selection and color/contrast policy belong in Theme.qml/ThemePalette.qml;
components consume Theme values rather than checking darkMode or reading palettes.

## Layout

```text
shell.qml          Quickshell entry point and startup pragmas
src/
  Bar.qml          Per-monitor bar
  bar/             Module placement and shared windows
  modules/         Feature UI
  services/        Native services, repositories and Bash helpers
  config/          Settings, Theme.qml link and singleton metadata
  theme/           Appearance settings, shared UI components and rendering utilities
  assets/          Images
docs/              Setup, usage and implementation details
tests/             Helper, QML and integration checks
data/              Local runtime database (ignored by Git)
config -> src/config  Settings-only link
```

Keep related QML directories together under `src/` so their relative imports
and asset URLs remain valid. Update test imports and copied fixtures when moving
files. Keep the root entry point and runtime data path stable.

The config directory contains `Config.qml`, a `Theme.qml -> ../theme/Theme.qml`
link and singleton metadata. The root `config -> src/config` link exposes both
settings files. The config module re-exports the canonical theme source so both
import paths share one singleton. `Timespan.qml` lives
under `src/services/time`, exported through both local and parent service modules.
The update helper lives at `src/services/system/update-check.sh`; cron and pacman
hooks must point there, rather than under `config/`.

Projects and Directories use `ManagedPickerFrame` for their outer geometry,
management shortcuts, focus restoration and close cleanup. Each feature supplies
its own list/form, focus target and service callbacks; draft validation and
persistence stay in those services. Ordinary and private picker hosts share their
size calculations through `PickerWindowContent`, while each host keeps its fixed
layer namespace.

Vault UI uses feature-owned `VaultEntryList`, `VaultEntryDetails` and
`VaultEntryEditor` components. `VaultPanel` coordinates selection and editing;
`RbwService` owns vault operations. Inputs use the shared `UI.SecretField` and
`UI.TextArea`; read-only notes masking belongs to the vault details view. Recent/folder file
helpers share local path identity and URI encoding through `file-records.jq`,
while each helper keeps its own source metadata and sorting.

## QML lint and editor

Run `bash tests/qml/lint.sh` to check every QML file with Qt 6, including unused
imports. The script rejects Qt 5 tools and accepts `QMLLINT` for a custom Qt 6
executable. VS Code uses the system Qt 6 language server and QML import directory
through `.vscode/settings.json`; reload the editor window after changing these
settings.

The check keeps `--max-warnings 0` and treats unused imports as warnings.
Standalone singletons are checked with their exporting `qmldir`; unrelated
modules are not injected into other files. Native screen/model metadata can be
opaque across Quickshell modules: geometry uses the existing `geometryScreen`
boundary, and audio retains the native models through explicit model references.

Singleton folders also carry local `qmldir` metadata so the language server can
recognize standalone files without the command-line check's explicit imports.
Parent modules continue exporting the same QML files; local and parent imports
resolve to the same runtime singleton instances. Theme's config export points at
its canonical source, while `config/Theme.qml` is an editing link. Lint checks
canonical sources once and prefers their local module metadata. Keep both listings synchronized
when adding a singleton, and retain existing helper components in local listings.
Run `bash tests/qml/singletons.sh` to check runtime identity and real language-server
diagnostics for every singleton. It uses a private database, Bash, Node.js and
the Qt language server (`QMLLS` can select another executable). The offscreen runtime
fixture uses a passive audio stub and the harness stops its host after assertions,
so metadata checks require neither a live audio server nor QML quit handling.
If VS Code retains a warning after metadata changes, run **Qt: Restart QML language
server** from the command palette. A full editor restart is unnecessary.

The QML files contain scoped lint exceptions for incomplete Quickshell type
metadata: runtime-selected `PanelWindow` backends, the missing
`QProcess::ExitStatus` enum, and the tray menu handle's outdated C++ type name.
Other warnings remain enabled, including signal checks outside those handlers.

Changing audio glyphs use `UI.FixedIconText`, with a centered icon in a fixed
slot. `AudioButton` uses `Theme.iconButtonWidth`; bar icons use `UI.BarIcon` and
the compact `Theme.barIconWidth` slot. All bar module icons share that width, so
their centers remain evenly spaced and state changes do not resize controls.

Static images use `UI.ScaledImage` for smooth filtering and mipmaps, with aspect
fit by default. Avatars and media artwork use `UI.CroppedImage`, which shares
those texture settings and conservatively trims embedded, thin saturated circular
frames. It analyzes a 128×128 sample once per source in a WorkerScript, then
applies normalized crop geometry to the original image. Raster sources retain
their native resolution; SVG sources rasterize at the current device size,
including after enlarging a view. Detection metadata has a 64-source memory cache
shared by Twitch, notifications, compact media cards and fullscreen media.
Ambiguous images retain their usual geometry. Set `circular` for avatar masking,
`removeBlackPadding` for edge-connected near-black padding removal, and
`detectionEnabled: false` for ordinary app icons. Small avatars add a minimal
inset to keep mipmap sampling inside the detected frame. Source files and stored
notification images remain unchanged. Active views retain their metadata after
cache eviction; closed or replaced views cancel pending analysis. There is no
idle analysis timer. Keep asynchronous loading at the call site when needed.
Masked display layers and their masks render at device resolution. Preserve
fractional mask alpha with `maskThresholdMin: 0.5` and `maskSpreadAtMin: 1.0`;
MultiEffect's sharp defaults discard the circle's antialiased edge coverage.
Live captures use `UI.ScaledScreencopyView`, which generates
smooth mipmaps through a source-resolution layer even during parent transforms.
Live capture pauses when its view or containing window is hidden.
Generated image masks use `UI.ScaledTexture`. These components read smooth
filtering and mipmap settings from the shared `UI.TextureSettings` singleton. Use these shared
components for new images and captures rather than duplicating their settings.

`bash tests/images/crops.sh` checks synthetic frame detection, rejection of
ambiguous shapes, shared cache reuse, original raster resolution, vector resizing,
source replacement, disposed requests and black-padding compatibility. It requires
ImageMagick and Qt's QML test runner. `bash tests/images/crops.sh --wayland` also
checks rendered GPU pixels for circular alpha, retained interior details and
small-avatar mipmap fringes. Native fixtures must run sequentially. Set
`CROP_TEST_SCREENSHOT` to save the synthetic composed preview. Offscreen checks
cover geometry and lifecycle; actual GPU masks require the Wayland run.
Set `QT_SCALE_FACTOR=2` on either command to exercise high-DPI sampling and masks.

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
shader's sine curve uses `PulseClock`'s shared elapsed-time origin, so later-starting or
reshown indicators join the same pulse phase. Each effect synchronizes once after
its first rendered frame, then disconnects that signal; no per-frame global timer
or JavaScript synchronization runs. The
layer and animation share one gate: a requested pulse, visible text, a visible
containing window and the shared motion policy. Hiding either stops the animation and releases the layer;
showing it again resumes the requested pulse. Muted mic and speaker indicators
pulse only while an application's active PipeWire link requests their default
device. Paused links and requests routed to another device do not keep them
animating. Screen sharing pulses while sharing is active. Duration and colors
remain in Theme.qml. Rendering still runs while the pulse is active.
Default-device link groups must be bound with `PwObjectTracker` before their
state can be used; an unbound group's state does not reflect active audio.
Run `bash tests/qml/pulse.sh` in a Wayland session to verify rendered colors and
stopping behavior, including an independently enabled status pulse with the master
off during sharing; software/offscreen tests cannot validate this GPU effect. The
fixture uses isolated Config switches and input-transparent native surfaces.
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
it checks that each completed countdown sounds exactly once. Database preparation
is deliberately delayed; tests reject early writes, verify persisted snapshots
between restarts, cover service creation before/after preferences load and confirm
that an overdue alarm plays once across subsequent restarts.
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

Run `bash tests/status/status.sh` for native SQLite sessions, stale-writer
protection, restart gaps, lock/suspend/inactive pauses, rolling twelve-month
retention, disabled mode and Today/week/month reports. The suite also checks
local-midnight/DST boundaries, app profiles and read-only desktop-state handling.
It uses isolated databases and mocked desktop commands.
Run `bash tests/status/reload.sh` to upgrade an already-loaded editor to the current
shared folder/process list component, exercise folder append/save, and verify
both explicit and component-file automatic reloads. This catches hot-reload type
failures that a fresh process cannot detect.
Run `bash tests/status/detection.sh` for stdin rules, distinct process/path
reporting, literal directory boundaries, quoted/newline paths and partial errors.
Run `bash tests/status/detection-ui.sh` for keyboard/name-click disclosure,
refresh/removal, narrow scrolling and manual/partial/empty presentation.
`bash tests/storage/backup.sh` covers encrypted restoration of sessions and
private detection rules alongside the other saved data.

## Clipboard validation

```sh
bash tests/clipboard/fts/run.sh
bash tests/clipboard/fts/contention.sh
bash tests/clipboard/fts/ui.sh
CLIPBOARD_NARROW=1 bash tests/clipboard/fts/ui.sh
CLIPBOARD_ZERO_MOTION=1 bash tests/clipboard/fts/ui.sh
CLIPBOARD_NATIVE=1 bash tests/clipboard/fts/ui.sh
bash tests/clipboard/fts/previews.sh
PREVIEW_NATIVE=1 bash tests/clipboard/fts/previews.sh
```

The migration fixture includes captured image JSON with empty text and repeat
capture/pin preservation. Qt can bind a decoded empty string as SQL NULL; the
repository normalizes that value before inserting into the non-null text column.
The contention fixture keeps a read lock while capturing and switching search
engines, and checks heartbeat delays, retention and FTS consistency.
The UI fixture simulates viewport changes and animation-policy changes without
altering real monitor or screen-capture settings; the native test checks the
moving input mask and restores desktop focus.

Preview tests use generated PNG/JPEG/WebP/GIF/BMP/TIFF files, a loopback-only delayed
HTTP response, and isolated windows at Qt scale factors 1, 1.25 and 2. Each run
snapshots its source files so editing the checkout cannot trigger a hot reload
inside a QtTest wait. Private provider configuration is excluded. They check
real-pane decode sizing, resize coalescing, loading/error feedback, stale replies,
retained frames, shared crossfades, disabled motion, unchanged-source reuse, rapid
navigation, immediate sharp loading without pixelated frames for single steps,
uncached frames during held-key navigation, immediate neighboring low-resolution
previews, final refinement, release of image sources and memory growth across repeated
navigation. They additionally require ImageMagick, socat, curl, procps and Linux /proc. Native tests use the current
Wayland/GPU backend. These scale/viewport simulations do not establish behavior
for physical monitor unplugging or every compositor fractional-scale protocol.

The 24-megapixel compressed PNG fixture can still reach roughly 0.7–0.8 GB peak
RSS on the tested native renderer, even with viewport-sized output. Repeated
navigation batches stabilized rather than continuing to grow. An eight-megapixel requested preview is not a total
memory cap: codec buffers, retained images, renderer allocations and allocator
arenas can exceed it and may remain allocated after the active source is cleared.
The fixture measures both peak RSS and batch-to-batch growth instead of requiring
immediate RSS reclamation.

## Projects

`bash tests/projects/choices-focus.sh` checks the real native project picker with
79 synthetic projects and a mocked editor. It covers first-row Enter/click,
filtered and other-row activation, Back, reopening, remembered workspace selection
and direct single-action launch. It briefly takes keyboard focus, leaves the
pointer in place and uses isolated storage. The native focus-grab regression
cannot be exercised by an offscreen window.

`node --test tests/projects/launchers.test.mjs` checks generic extension matching,
menu labels, literal argv expansion and invalid configuration.
`bash tests/projects/launchers.sh` checks mixed Code/Godot/custom-editor projects,
editor-specific arguments, app-specific profile mappings and category fallback, exclusion, direct opening of single-action projects, fallback app behavior and
restart/selection persistence with synthetic project files and mocked editors. The custom file type
is supplied only through the test's Config.qml rule. Scanner tests also cover
case-insensitive suffixes, generated Godot-cache exclusions and literal paths.


Run `bash tests/projects/projects.sh` for native project sources, workspace
selection/editing, category choices, manual refresh, failed scan preservation,
launch profiles and restart persistence. The suite uses isolated Git/non-Git
folders, mocked launch commands, Bash, jq, sqlite3 and an offscreen QML window.
Run `bash tests/projects/grouping.sh` for overlapping-owner priority, source
removal fallback, case/path sort ties, workspace inclusion, safe path keys and
failed-read snapshot preservation.
Run `bash tests/projects/manage.sh` for accent highlighting of repository names,
paths and workspaces, fuzzy/substring/smart-case matching, literal markup and
Unicode, and scroll preservation when editing, toggling workspaces, cancelling
or saving. It uses
an isolated synthetic database and an offscreen QML window.
`bash tests/projects/grouping-benchmark.sh` compares the working tree's reload
against the committed version using 2,000 synthetic projects, three owners and
three workspaces each. It also measures the existing fuzzy search. Set
`PROJECT_GROUPING_BENCH_COUNT=100` for a smaller dataset, or
`PROJECT_GROUPING_BASELINE=<git-ref>` to compare against an older commit.
Timing is reported without a fixed speed threshold; results depend on the local
machine and Qt build. Both fixtures use isolated databases and never scan actual
projects or launch applications.
Run `bash tests/projects/folder-picker.sh` in a Wayland session to verify that
Ctrl+A opens Add from focused Projects and Manage searches, and accepting or cancelling the native
folder picker keeps Manage open and restores its keyboard focus. This test
briefly shows an isolated picker and folder dialog.
`bash tests/launcher/providers.sh` also checks that code/GitHub dispatch to native
IPC without a project cache file.
`bash tests/launcher/launcher.sh` checks that legacy markup labels are normalized
before search while replies preserve original labels/results and ordinary grid
labels remain literal. It also checks compact input-only prompts, the QR viewer,
filename-only wallpaper lists and the mode/monitor selection flow.
`bash tests/launcher/native-pointer.sh` checks stationary pointer behavior across
ordinary/private menus, QR previews, clipboard pickers and the window overview.
It opens each picker with the pointer away from the panel, verifies keyboard
focus and search (including masked input), then closes it with Escape. Native
checks restore the original window focus and pointer position when they finish.

## Directories

`bash tests/directories/directories.sh` includes keyboard activation of unmatched
absolute, home-prefixed, environment-prefixed and home-relative local folders.
It covers symlinks, spaces and literal shell characters, invalid paths/files, unset
variables, saved-match priority, retained error focus and cancellation during an
actually delayed lookup after editing, Escape or replacement. Typed paths never
change the saved collection. File-manager actions are mocked; the existing CRUD,
virtual-location, status-filter and restart checks remain in the same suite.

The configured `directoryResolveCommand` supports `--open PATH` for local-only
validation/expansion, in addition to saved-location resolution and `--check` batches.


## Webapps

`node tests/webapps/model.mjs` checks browser profiles/window modes, literal
argument quoting and invalid entry rejection. `bash tests/webapps/manage.sh`
uses offscreen controls, a private database and mocked browsers. It checks shared
form keyboard input, configured profile combos, browser changes, main-form category
selection/persistence, CRUD, duplicate
rejection, disabled entries, hook failures,
browser argv (including Qutebrowser profile-window reuse and Vivaldi app-mode
isolation) and restart without legacy files. Shared button sizing checks verify
text actions fit their labels while icon-only actions retain their existing width. It verifies Manage has no import
controls and never reads real entries or launches a real browser. The storage
backup regression verifies webapp payloads survive encrypted restore.

`dbus-run-session -- bash tests/webapps/qutebrowser.sh` verifies actual
Qutebrowser profile/window behavior using offscreen browser instances, private
profiles and about:blank only. It checks repeated launches create tabs in one
window, different profiles stay separate, and explicit New window still works.
Its WebEngine sandbox override is test-only and never used by launcher commands.

## Notifications

```sh
bash tests/notifications/notifications.sh
bash tests/notifications/notifications.sh --wayland
bash tests/notifications/animations.sh
bash tests/notifications/animations.sh --wayland
bash tests/notifications/startup.sh
bash tests/storage/storage.sh
bash tests/directories/directories.sh
bash tests/qml/lint.sh
```

The standalone avatar padding-mask test imports the production `ImageCrop.mjs`
function directly, following the image-detector test pattern. Its five assertions
run under `qmltestrunner` without loading Quickshell-only UI services. Runtime
notification UI and protocol checks continue to run through `qs` below.

The notification tests use a private D-Bus session and temporary databases, with
Hypr commands mocked. They check protocol receipt, replacement, expiry and close
reasons; source policies; action/click behavior; durable images; pagination; schema
migration; and reload/restart persistence. `--wayland` also briefly displays the
test popup/manager on the current desktop, checks bounded layer surfaces and saves
a sample manager image to `/tmp/quickshell-notifications-preview.png`. The tests
also send a title-only notification with `notify-send` and verify its history
survives expiry and restart. The Bash runner uses `gdbus` for protocol calls and
signal monitoring, `jq` for assertions, and `sqlite3` for migration fixtures.
The animation fixture uses synthetic entries and a private D-Bus session. It
checks right-side entrance/exit and the small settling overshoot, stable card
identity on replacement, smooth stack movement, last-card window lifetime, rapid
and bulk dismissal, interrupted movement, screen-sharing policy and idle rendering.
The two-popup regression also removes the older bottom popup and checks that the
newer card's global position and the native surface size stay fixed throughout.
The standalone `--wayland` mode exercises the actual private popup window. These
checks also run as part of `notifications.sh`.
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
bash tests/storage/backup.sh
bash tests/storage/backup-ui.sh
```

The storage smoke test checks required table names instead of an exact table
count, and exercises module pinning with Qt mouse events in an offscreen window.

Run `bash tests/storage/storage.sh` to check first-run creation, dropdown actions,
restart persistence, transaction rollback, avatar downloads, schedule caching, and midnight labels
using an isolated database and mock Twitch/receiver commands.
Add `--ipc` to check the real IPC commands and retirement of the old Twitch export.

Backup checks use synthetic text/image clipboard payloads, SQLite fixtures, public
TOTP seeds and a fake keyring. They cover encrypted content/filenames, checksums,
replacement, pins/recency, keyring failure compensation and startup recovery.
The UI fixture checks the shared private prompt, generate/copy, Enter/Escape,
maintenance lifecycle, alert feedback, restoration of an open attached database
and actual backup IPC. Missing-folder/workspace fixtures verify preserved records,
Manage warnings, warnings clearing after paths return, unchecked remote locations
and import-report persistence through a fresh shell start. Set
`BACKUP_TEST_SCREENSHOT=/tmp/backup.png` for a masked prompt preview and
`BACKUP_WARNINGS_SCREENSHOT=/tmp/path-warnings.png` for Directory Manage warnings.
Tests require 7-Zip and local Unix sockets for IPC. The real manual round trip is
documented in [storage](storage.md#manual-backup-and-recovery-test).

`bash tests/qml/alerts.sh` checks alert replacement, validation, dismissal and
expiration. Add `--native` in a Wayland session to briefly render labeled test
messages and check the actual monitor, overlay layer, keyboard focus, placement
and progress/completion surface. `ALERT_TEST_SCREENSHOT=/tmp/alerts.png` saves the
isolated alert surface. Backup UI checks also verify keyboard-only submission,
streamed progress, the saved-path completion message and persistent destination errors.

Run `bash tests/storage/twitch-fallback.sh` for main/second-channel selection, database
migration, explicit linking, editing, unlinking, removal and Undo, restart
persistence, and main-only alerts. It also checks requests across the
[Helix 100-channel limit](https://dev.twitch.tv/docs/api/reference/#get-streams)
and preserves the previous live list when a later batch fails. Both storage
suites use Bash, jq, sqlite3, and isolated QML fixtures.
It also checks idle/live/pinned icon colors and an isolated disabled startup: no CLI
detection, Twitch API calls, browser discovery or alerts; unchanged Twitch tables;
and saved-channel polling after re-enabling. The disabled icon cannot be opened
through the shared bar-module shortcut handler. No native focus or real accounts
are used.

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
Set `MEDIA_FULLSCREEN_RING_FIXTURE=1` to exercise shared frame trimming and
device-resolution SVG rendering in the fullscreen artwork slot.
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
and description fallbacks. The runner isolates the production ScreencastModel
from shell-only singleton registrations without duplicating model logic.
`--native` additionally creates two disposable video
nodes on a private PipeWire server and checks their descriptions in the real
tooltip. The native fixture requires `pw-cli`; it does not affect desktop captures.

`bash tests/hyprland/capture-sync.sh` exercises the production coordinator without
any database service. Four isolated processes reload edited fixture Config.qml
values, while synthetic capture/compositor services and a slow command recorder
check capture readiness, Config changes while a command is busy, multiple captures,
compositor reload, disconnect/reconnect and the last share ending. Config changes
during sharing are honored when sharing ends. It uses isolated runtime/data
directories and private D-Bus sessions; no command reaches the desktop compositor.
No persisted animation preferences, animation IPC controls or Lua state owner are
involved.

`bash tests/ui/twitch-panel.sh` is an optional Wayland check that briefly opens
isolated panels and restores focus afterward. It checks explicit search activation,
on-demand focus after activation, stationary pointer position, repeated opens,
editor cancellation, manual pins, Escape, private TOTP, and volume without muting.
The tray shortcut shows the same `TrayContents` used by its passive bar expansion.
Avoid running native focus/pointer fixtures while the desktop is in use.

Bar modules declare `moduleName`; `TooltipArea` registers them with
`BarModuleService` and owns their left-click pin action and pin color. The tray
registers its own passive trigger and shares its app items with its keyboard popup.
Bar layout files only supply placement and window references. Capture detection lives in
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

## Panel lifecycle

```sh
python3 tests/ui/tooltip-search.py
bash tests/ui/module-pins.sh
bash tests/ui/tooltip-hover.sh
```

These offscreen checks never move the real pointer or desktop focus. They verify
search dismissal, scoped form editing, native-child cleanup and focus restoration,
manual pin preservation, multiple retention owners, keyboard replacement, Escape
hierarchy, and persistent manager drafts. All 14 bar modules are clicked to check
shared pinning/color. Pixel-bound checks verify the visible sharing/recording glyphs
are vertically centered at Theme.barHeight; the recording indicator is checked through idle, setup,
capture and finalization without changing sharing state; Calendar mappings and the Updates action buttons are also
checked with mocked desktop actions. Hover checks cover stationary source changes,
late hide requests, popup options, and leaving the panel.

`UI.WindowFocusHandler` owns activation, native-child handoff, cancellation of
stale focus callbacks and outside-click policy. Launchers activate explicitly;
`TooltipFocusHandler` is a thin passive-hover adapter with owner-scoped retention.
Vault and secret prompts use the persistent policy: changing apps keeps the view
alive without reclaiming focus. `UI.PanelFocusScope` provides outer Escape after
inner editors and popups; `UI.FolderDialog` shares native folder selection.
Focused inputs use `retainPanelWhileFocused` to retain their panel through pointer
leave without blocking replacement by another hovered module. Searches inherit
this temporary hold; query text alone never retains a panel after focus leaves.
Real form fields additionally use `retainPanelWhileEditing` to protect their owner
from replacement. Both holds end when the control or owning window loses focus.
Temporary holds and active drags never toggle the manual pin flag. Pointer polling
and the old global typing pause are removed.

Run `bash tests/ui/unlock-focus.sh` for a brief native synthetic unlock check.
It verifies password focus and typing while the manager yields, using private test
storage without accessing a vault or moving the cursor. The offscreen lifecycle
fixture also reproduces an initial map/deactivation race that must preserve the
explicit focus request. Hover adapters keep native keyboard input disabled until
interaction, and include their bar trigger window in an active focus grab.

Run `bash tests/ui/panel-input.sh` with the desktop keyboard idle. The native
fixture uses isolated storage and synthetic data without moving the cursor or
accessing a keyring. With animations on and off, it clicks the actual Countdowns,
Stats, private TOTP and Twitch fields, plus pre-focused and multiline controls.
It checks native activation, typing, selection/deletion, caret preservation,
repeated clicks, Tab traversal, named countdown creation, manual pins and passive
reopening. A synthetic Twitch list is filtered down to shrink the actual panel,
then pointer leave is simulated while typing continues past the dismissal delay. Run native focus fixtures sequentially.

Text controls may consume a press before an ancestor TapHandler sees it.
`UI.WindowFocusHandler` observes explicit mouse focus and attaches a passive
observer to the current focused control for repeated clicks. The observer is
recreated when Loader-owned fields change; it must not be a persistent handler
parented to a field that can be destroyed. Activation waits until event dispatch
has established the clicked control's focus and selection, and repeated interaction
keeps an established native grab. Hover and programmatic field focus stay passive.

Native folder portal and compositor focus behavior still require a desktop check
on the installed compositor; offscreen tests exercise their lifetime contracts.

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

`bash tests/launcher/screenshot.sh` uses synthetic capture, editor, clipboard and
file-manager tools to test region/output/window geometry, Portuguese OCR, QR text,
cancellation, timeout/failure, literal data, repeated QProcess-backed region/output
selection with explicit EOF, unique saves, editor cleanup, owned
process-group termination, invalid internal handoffs and offline Config. A separate
windowless fixture verifies that the prepared annotation worker survives an actual
Quickshell reload and reveals the saved file; unrelated clipboard WorkerScripts are
excluded from that fixture. The offscreen QML handoff fixture runs the
production native menu/service and panel motion: capture waits for both picker and
submap closing, other panels stay open, replacement cancels queued work, and native
alerts report results. With the keyboard idle,
`SCREENSHOT_TEST_NATIVE=1 bash tests/launcher/screenshot.sh` runs the same handoff
against the real public/private picker and SubmapWindow, without real capture,
pointer movement or clipboard access, then restores the previously focused window.

`bash tests/launcher/encode-qrcode.sh` exercises the real native QR service,
shared prompt/viewer and `qrencode`, with synthetic input and a mocked clipboard.
It compares PNG bytes with the original encoder defaults, including Unicode,
shell punctuation and trailing newlines. Checks cover blank/cancelled input,
Enter/Escape/replacement, cancellation during encoding/copy, reopening, encoder/copy/
image-load failures, native alerts and absence of temporary image files. A windowless
reload fixture verifies that the in-memory preview is released while copied PNG
bytes remain available. No desktop focus, input or real clipboard
is used. The launcher IPC suite also checks the immediate-return compatibility alias,
sharp integer scaling and compact hint-free geometry through the actual picker.

`bash tests/launcher/wallpaper.sh` runs the real native service and shared panels
offscreen with synthetic images and mocked desktop tools. It covers asynchronous
recursive discovery, literal/reserved-character/newline paths and preview loading,
focus, saved choices, per-session search/selection with history disabled, optional
work mode, separate mode/monitor steps, cancellation/replacement during reads and
application, errors/native alerts, custom/symlinked roots and native restore without
picker/config IPC. Separate retained-executor checks cover per-mode/output links,
legacy numeric slots, application failure, daemon readiness, custom Config storage
and offline restoration. The fixture isolates capture-state policy from live audio. It selects a non-first
row beyond the initial viewport and checks the rendered highlight/scroll position,
as well as continuously visible image → mode → monitor steps.
With the keyboard idle, run `WALLPAPER_TEST_NATIVE=1 bash tests/launcher/wallpaper.sh`
for the actual PickerWindow Enter/click handoffs with a delayed monitor read.
It uses synthetic images and mocked setters, restores original focus, never moves
the pointer and does not change the desktop wallpaper. The launcher IPC
suite loads a synthetic image through the real bounded preview loader, checks
wide/narrow layout, empty search and preview reset when ordinary menus open.
Rendered landscape, portrait and panoramic samples switch inside one session
and verify filled previews with preserved aspect ratio and screen limits. They
also verify stable placement footprint, search/list widths and list viewport
height, so changing preview dimensions cannot recenter or resize the column. It
checks that image-picker rows have empty image sources while ordinary menu rows
retain their thumbnails. It also checks the full image → mode → monitor flow, including preserved search and
image selection after setting or cancelling either target step. The wallpaper
flow uses a custom `Config.wallpaperDirectory` and verifies that the compatibility
alias returns immediately while all choices stay native.

`bash tests/launcher/providers.sh` checks native provider dispatch, offline idle Lock,
and isolation from obsolete `.env` files. It also exercises the shared screenshot/
recording file-reveal helper with mocked desktop tools: spaces, reserved URI characters,
commas, quotes, Unicode and newlines remain one encoded file URI, followed by the
existing file-manager focus request. Directory opening and missing-path fallback
keep their original commands. Obsolete interactive menu/audio mocks are removed;
recording setup and detached capture have their own suites below.

`bash tests/launcher/provider-config.sh` exercises the actual headless exporter,
shared environment handoff, fresh Config edits, offline wallpaper restoration,
strict live-response validation and FIFO cleanup on export failure. Synthetic
paths include spaces, quotes, newlines and shell expressions. The headless export
must not create the application database or run desktop actions. The full
launcher regression also checks the live provider Config API and configured
wallpaper image/state directories.

`bash tests/recording/setup.sh` drives the real RecordingSetup and shared picker
with synthetic monitor/audio/region tools. It checks original order/defaults,
all audio modes, default-first/off-profile filtering, virtual sources, cancellation
at each step, replacement during metadata loading, region readiness and stdin EOF,
repeated controller shortcuts, literal prepared arguments and cancelling unfinished
setup through an actual Config reload. It never starts a recorder or audio module.
For the real Wayland picker, run `RECORD_SETUP_NATIVE=1 bash tests/recording/setup.sh`
with the keyboard idle. It uses synthetic tools, restores the previous focus, and
leaves the pointer unchanged; it never starts recording or audio capture.

`bash tests/recording/worker.sh` uses actual detached workers, SQLite, process
identities and signals with synthetic recorder/audio helpers and prepared options.
Only the setup component is mocked for controller lifecycle checks; the real setup
has its own suite above. Coverage includes duplicate worker exclusion, delay and
startup-handoff cancellation, one-signal stopping, repeated stops, recorder
failure, stale identities, dead-owner recovery and audio cleanup retries. An
offscreen production RecordingService fixture applies Config changes during capture,
then restarts its Quickshell process and stops the same recorder. The edit writes
in place to preserve the watched inode. On the installed Quickshell 0.3.2, an
isolated probe misses `sed -i` atomic replacement while an in-place write triggers
reload; this is a file-watcher limitation, separate from recording ownership. The
regression still waits for automatic reload, without an explicit reload request. It needs Bash,
coreutils, jq, sqlite3, Node.js and Quickshell IPC; it never captures the desktop
or microphone. The backup regression also checks that runtime recording state is
excluded from archives and unchanged by restore.

[Documentation](README.md)

### rbw manager checks

`bash tests/security/rbw-manager/run.sh` exercises the Bash backend and actual
QML manager panel with synthetic rbw/clipboard processes. It covers stdin-only
secret writes, protected entries, stale baselines, generation, confirmations,
draft clearing, locking, copy expiry and late results. The optional
`bash tests/security/rbw-manager/native.sh` checks the manager's private namespace
through the compositor without accessing the real vault or clipboard.

Shared selection controls use `ComboSelector` for dropdowns and `SelectionList` /
`SelectionRow` for persistent option lists. Dropdowns use an explicit same-window
`Popup.Item`, constrained to the nearest `popupContentBounds` host (or the window
overlay for standalone windows). `TopPanelSurface` supplies these bounds so
private dropdowns stay in the existing private surface and its input mask.
Keep `selectedName` bound to application state; `selected(name)` requests a change.

Run `bash tests/qml/selection.sh` and `bash tests/qml/selection.sh --native` to
check fixed layout, placement outside clipped lists, private window ownership,
focus restoration, disabled options, keyboard navigation and outside clicks.
The native test uses synthetic entries and restores the previous focus and pointer.
Dropdowns animate on opening and dismiss immediately: Qt keeps popup input
filtering active throughout an exit transition, which can swallow the next click.

`TooltipPointerHandler` combines panel hover with the individual items in Qt's
popup overlay, so unpinned tooltips remain open while selecting dropdown options.
Hide requests and timer expiry both respect current trigger/panel hover, pinning,
typing protection and dragging. The observer resynchronizes hover after source,
screen or window visibility changes, including when the pointer stays still.
Run `bash tests/ui/tooltip-hover.sh` for offscreen regression checks covering late
hide requests over triggers, panels and popups, stationary source changes, and
normal dismissal after leaving. It never moves the real cursor. Run
`python3 tests/ui/tooltip-search.py` for typing protection and pinning coverage.
The observers follow popup/window lifetimes. They avoid making the full overlay
hoverable, which would steal hover and the hand cursor from buttons when their
hints appear. Run
`bash tests/qml/selection-hover.sh` in a Wayland session for above/below dropdown
hover, normal dismissal, module switching and private namespace coverage. It also
holds and moves the pointer over upper/lower action buttons while their delayed
hints are visible, checking that button hover does not churn in either host.
The test uses synthetic devices and entries with deterministic Qt mouse events;
it does not change audio routing or vault data.

## Shared motion and native folder handoff

Use `UI.MotionAnimation` and `UI.MotionUniformAnimator` for numeric and shader
animations. Set `animationDuration` for their normal timing. Their shared
`MotionGuard` settles running finite transitions when `UI.MotionPolicy.enabled`
changes. Use `UI.MotionBehavior on property` with `motionEnabled` for bound
properties; it snaps active behavior transitions while preserving their bindings.
All primitives enforce the global gate even when a component enables
its local animation option. Only `MotionPolicy` reads `animateDuringScreenShare`
and the active sharing state. Gate decorative frame callbacks and shader loops
with the same policy; functional model batching and expiry clocks stay active.

Top-panel consumers set `requestedVisible` and `requestedScreen` on
`TopPanelTooltip`, leaving physical `visible` to the shared presentation lifecycle.
`TopPanelSurface` releases its input region at logical close. Focus handlers
also observe logical visibility, so the closing visual cannot retain input.
`PanelMotion` coalesces lazy layout, interpolates geometry, reverses interrupted
open/close transitions, and reserves the larger native render area during resize.
Clipboard's own interpolated geometry uses `continuousGeometry` to avoid easing
it twice. Private hosts reuse the same implementation and private namespace.

Run `bash tests/ui/panel-motion.sh` for reveal, roll-up, resize, retargeting,
reversal, immediate input release, render-area cleanup, clipboard pass-through
and global policy interruption. `bash tests/ui/folder-dialog.sh` checks path
delivery before owner release, encoded paths and cancellation. The shared folder
dialog emits `folderSelected(path)` while `nativeDialogOpen` still retains its
owner. Focus restoration waits for a native frame before rearming outside-click
dismissal. `PanelFocusScope.interactionPending` forwards pending owner operations
to the hover lifetime adapter without changing pinning.

Recent Files uses its existing `folderAdded` acknowledgement to select the new
tab and enter the same alias editor as Edit, with the name fully selected.
`bash tests/files/recent-folder-native.sh` checks the full native handoff with a
slow folder scan, no hover hold, an unpinned panel, and keyboard replacement of
the selected name. It uses a private database and never moves the real cursor.

`bash tests/ui/panel-shadow.sh` checks real shadow pixels on the Wayland GPU
renderer. Its temporary panel accepts no input and never moves the cursor. It
captures only synthetic panel content, checking the fixed bar edge during
opening, module replacement and closing. Set `PANEL_SHADOW_FRAMES` to a directory
to retain those frames. The fixture uses private data and slower test-only timings;
production animation timings are covered by `tests/ui/panel-motion.sh`.

`bash tests/ui/panel-host.sh` checks a real native panel while switching between
tall and short tabs with motion disabled. Its buffer and top position stay fixed;
the visible panel and input region resize independently. The synthetic test window
accepts no input and never moves the cursor.

## Remotes validation

```sh
node tests/remotes/model.mjs
bash tests/remotes/worker.sh
dbus-run-session -- bash tests/remotes/manage.sh
```

The model checks endpoint/port/type validation, literal credential handling and
argument boundaries. Worker tests use private SQLite files and mock SSH, FreeRDP,
libvirt and network probes; they cover concurrent connections, duplicate exclusion,
stdin-only passwords, targeted disconnect, dead-owner recovery, stale PID protection,
cancellation and VM readiness failure. Manage tests use offscreen UI and the same
mock commands to check input focus, masked passwords, CRUD/rollback, disabled entries,
selected-VM shutdown and detached connections recovered after a shell restart.
They also cover Ctrl+R Running-only filtering composed with search, per-opening
filter reset, dynamic Connect/Disconnect hints, rapid Enter disconnects while a
controller request is in flight, and cancelling a connecting VM without launching
an RDP client. Disconnecting rows leave the running view immediately while the
picker stays open, including after its final connection stops.
No real server, VM, SSH configuration, credentials, pointer or desktop window is used.
Run Webapps Manage tests after shared collection changes, recording worker tests after
shared process-identity changes, and encrypted backup tests for schema/storage changes.

When changing QML launcher enum members, restart the running shell and exercise
the provider IPC route on that instance. A newly added member can remain undefined
after automatic or forced reload because QML type metadata is cached.
`launcher alive` alone does not verify that a newly added mode can open its panel.

## n8n validation

```sh
node tests/n8n/model.mjs
dbus-run-session -- bash tests/n8n/manage.sh
bash tests/storage/backup.sh
```

Model checks cover base paths, escaped cursors, connection validation and IDs
shared across instances. Manage checks use isolated SQLite, an offscreen picker,
a loopback Node API and a mocked browser. They exercise masked keys, native input,
Ctrl+W filtering, Ctrl+R refresh, pagination, batch reconciliation, independent
instance failure, invalid/repeated pages, redirects, authentication failures,
timeouts, size limits, SQL rollback, stale-response rejection and restart without
network requests. No real instance, credentials or workflow execution is used.
Backup fixtures retain multiple instances, private keys and independent caches.
Run Webapps and Remotes Manage checks after changing the shared collection or
browser fields, and QML lint after adding service registrations.

## Launcher opening focus

`bash tests/launcher/opening-policy.sh` checks the shared first-map focus policy
offscreen: activation before lazy content readiness, synchronous search preparation,
on-demand handoff, passive hover, blur and stale-focus cancellation.

With the desktop keyboard idle, run `bash tests/launcher/opening-focus.sh`. It uses
actual public/private picker hosts and Exposé with synthetic projects and storage,
checks initial/repeated/rapid opening with motion on/off, and sends the first input
as soon as the native window owns focus, before the opening animation completes.
It verifies complete text, editing, Escape and that the previous test window receives
no characters. The pointer stays still; original application focus is restored.
The logged timings measure native activation after the open request, not keybind
client startup. This cannot guarantee delivery of keys typed before native focus
transfers; test immediate Meta+P typing on the live desktop as well.

Run `bash tests/launcher/global-shortcuts.sh` in a Hyprland session to check all
45 production shortcut callbacks before and after reload, covering launcher and
recording actions, Vault, notification DND, shell reload, all 14 module shortcuts,
window cycling and all ten numbered window targets. It loads the unmodified
registry component with fixture-only feature services, captures reload through
a test override and uses a unique native shortcut namespace; it opens
no windows, sends no keys and never invokes the user's real bindings or actions.
Native shortcut app ID/name pairs must be unique across running processes, so do
not instantiate the production registry in a second test shell under its default
`quickshell` app ID. The fixture reports callback latency including the test client;
this does not measure the subsequent native window-focus transfer.

The installed Quickshell GlobalShortcut metadata references a private PostReloadHook
base that qmllint cannot resolve. The lint runner keeps that import diagnostic
visible as information for GlobalShortcutRegistry alone; other files remain strict.
The native regression checks runtime registration and re-registration directly.

The launcher Bash audit is documented in `docs/features/launcher.md`. Native
Hyprland entries use the shared global-shortcut registry; existing config-scoped IPC
and public shell aliases remain available. The retained aliases stay covered by
`tests/launcher/providers.sh`. Recording and wallpaper lifecycle, offline Config
export and external pinentry clients keep their existing regressions.

## Native Power menu

Run `bash tests/launcher/power.sh`. The fixture uses the real PowerService, picker
and grid offscreen, with an isolated database and mocked systemctl/loginctl/hyprctl
executables. It verifies action order/icons, filtering, Escape, all five selections,
exactly-once execution, status-pause ordering, replacement and reentrant native
callbacks. A failing mock IPC client proves that native execution has no callback
into the picker/status bridge and that direct idle Lock still works without a bar.
No real power/session action or native desktop input is performed.

`tests/launcher/launcher.sh` also checks the compatibility CLI opens Power with
an empty request directory and cancellation performs no action. Provider and native
shortcut regressions cover the alias and global entry points. Singleton smoke
checks verify the system-local and parent exports share the same PowerService.

## Native Bookmarks

Run `bash tests/launcher/bookmarks.sh`. It uses the real BookmarkService, shared
picker and asynchronous FileView with synthetic files, isolated storage and a
mock browser. Coverage includes sorted duplicate titles, search, multiple/typed
choices, literal URL/command arguments, Escape, cancellation or
replacement during loading, reload of changed files, direct single-entry opening,
empty files and missing-source errors. No real bookmarks or browser are accessed,
and the fixture uses offscreen windows without taking desktop focus.

Provider and global-shortcut suites cover compatibility IPC and native activation.
The existing external JSON/dmenu/secret protocol regression remains unchanged apart
from removing obsolete handle.sh adapter tests; native Bookmarks covers its former
selection/browser behavior. Singleton smoke checks parent/local exports share one
BookmarkService instance.

## Translations

Use `src/i18n/Translations.qml` for every shell-owned display string. Import
its directory from the component and use stable semantic IDs grouped by feature,
for example `common.actions.save`, `tabs.actions.remove` or
`stats.memory.usageHint`. English wording is a catalog value, never a lookup key.
Changing wording must not change an ID, a stored value or a dispatch argument.

Keep complete sentences and hints in the catalogs. Avoid translated prefixes,
suffixes and concatenating grammar around user data. Use a single call with
placeholders, and choose the ID before calling the translator:

```qml
hint: Translations.text("tabs.actions.remove", [tabButton.text])
text: Translations.text(root.searching ? "common.status.searching" : "images.preview.loading")
text: Translations.text("updates.status.available", [], UpdatesService.count)
```

Positional placeholders are `%1`, `%2`, etc. Counted messages use `%n` and an
object with `one` and `other` forms in each language. Formatting uses one pass,
so placeholder-like user content stays literal. Escape substituted user content
where a rich-text surface requires it; translation formatting itself does not
interpret or escape markup.

Pure models and workers return semantic diagnostic IDs, with `args` and `count`
when needed. `Translations.message(value)` handles a diagnostic object, its JSON
representation or an Error with a message ID and optional `args`. Unknown external
output remains literal. Detached alerts use the shared `alerts.postMessage` IPC
method, preserving their existing severity, duration and capture-readiness flags.
Decoded text and other user content continue through the ordinary literal path.

English and European Portuguese live in separate public JSON files. Add a new
message to both with the same ID, placeholder set and value shape. Calendar name
arrays must retain twelve months and seven Monday-first weekday headings. Do not
translate model keys, file paths, application names or saved user content. A new
language also needs an explicit locale mapping in `Catalog.mjs`, a catalog loader
in the singleton, and coverage in the configuration documentation and tests.

Run `bash tests/i18n/run.sh` for catalog parity, semantic IDs, missing references,
placeholder/plural compatibility, system/override selection, fallback, one-pass
interpolation and offscreen language changes. The UI fixture checks calendar
indexes, input focus, user text, shared selectors, memory labels and unchanged
power action codes in Portuguese. It uses isolated data and never takes native
keyboard focus. Existing test fixtures must include these public catalogs when
excluding private JSON. Run `bash tests/qml/lint.sh` after changing imports.
