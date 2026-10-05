## Main features

- Clock with month and year view tooltips
- Hyprland window list with focus, next/prev navigation
- System stats: CPU and memory with tooltips, temperature, and network speeds with graph tooltip
    - Network tooltip shows connected networks with per-interface speeds and top 10 processes by bandwidth
    - Process bandwidth requires `bandwhich`
- Microphone and output controls with device lists, system defaults, and audio profiles
- Screencast/screenshare status with sound notifications
- Package update indicator
- Easily follow Twitch streamers
    - manage streamers in the dropdown or through IPC
- TOTP codes beside the tray, with a hover panel, click to pin, copying, and inline add/edit/delete
- Batteries beside TOTP, with live levels for laptop batteries and attached devices
- Native notifications with durable history, emitter settings, and a pinned manager
- Submap window for Hyprland keybind hints
- Alert window
- IPC commands for reloading and toggling modules
 
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

Quickshell handles notifications directly whenever the shell starts. No
environment variable or separate notification-center package is required.

Hover the bell to open the manager and left-click to pin/unpin
it. The manager provides **History** and **Emitters** tabs. Emitter groups start
collapsed with their latest notification visible. Both groups and their entries
are ordered newest first; **Load older** controls keep older records accessible.
**Clear emitter** and **Clear all** delete history and dismiss current notifications
while preserving source settings and DND. The manager uses the shared tooltip
panel with underlined tabs on the left and DND/Clear all controls on the right.
Pinning is controlled through the bell.
Buttons, tabs, scrollbars and clickable cards use the pointing-hand cursor;
passive text and panel space use the normal pointer.

Low, normal, and critical notifications are saved in SQLite until manually deleted;
transient notifications are popup-only. Each emitter header shows
a plain **+/-** marker, its count, and its name, followed by **Show/Hide**,
**DND blocked/allowed**, **History on/off**, and a trash button to clear history.
These buttons show the current state; clicking toggles it. New emitters start
with notifications shown, DND blocked, and history on. The visibility filter is **Hidden**.
Groups with one notification hide the expand marker and leave their heading passive.
The same source settings are available in the Emitters tab. These
settings are independent and persist after clearing history. DND blocks every
source by default, including critical notifications; allowing a source does not
override mute. Excluding history affects future notifications and replacements,
and retains existing records. Turning off DND or unmuting never replays a backlog.

Popups follow Hypr's focused monitor, falling back to the last connected screen
or another available screen. Moving the stack keeps notification identities and
deadlines. Popups use the SwayNC reference's dark background at 95% opacity, rounded
corners and bold monospace text. App icons occupy a left-hand column beside the
content, with the timestamp after the app name. File icons supplied through
`notify-send`, including the custom Twitch logo, use this same left icon slot.
Twitch sends low-urgency, nontransient notifications under its own emitter name,
so its notifications and icons are retained in history. Clicking a Twitch
notification or its **Open Twitch** button opens the configured Twitch URL,
including from saved history after expiry or restart.
Discord user/group images overlap the app icon with an offset down and
right, leaving the Discord icon visible above and to the left. Timed popup
outlines drain symmetrically from the bottom center up both sides to the top
center, synchronized with rendered frames as in TOTP. The close
button is circular and turns red on hover. History cards use a complete outline
in their urgency color. Application timeouts take
priority over the configured low/normal/critical defaults. Left-click runs a usable
default action, then falls back to focusing a matched existing app only when no
default action is usable. Explicit action buttons invoke their own
actions. Right-click dismisses a popup without deleting its history; right-click
in history deletes that entry. Action identifiers and labels are saved with
history. Default actions are displayed in history unless their label duplicates
a named action. Generic app actions remain visible but disabled after their live notification closes; their callbacks
cannot be restored, as the notification protocol invalidates their IDs on
closure. See the [notification protocol](https://specifications.freedesktop.org/notification/latest/protocol.html).
The locally implemented Twitch action stays available. Focus lookup includes
other workspaces and desktop `StartupWMClass`.

Outline trimming uses Qt 6.10 or newer's
[ShapePath trim](https://doc.qt.io/qt-6/qml-qtquick-shapes-shapepath.html#trim-prop).

Quickshell 0.3.1 exposes notification replacements through property changes.
An identical-content replacement produces no QML change event, so it cannot
restart the timeout through this API. See the upstream
[notification receipt implementation](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/services/notifications/server.cpp).

Schema version 3 adds saved action metadata to the history, emitter preferences
and reload metadata introduced in version 2, without replacing existing Twitch/battery/preferences tables. Image snapshots are stored
as PNG data URLs in SQLite. QML renders provider images outside the bar viewport;
the Bash helper uses `stat`, `od` and `base64` to validate, encode and remove the
temporary PNG. No extra notification-center package is needed. History and emitter
settings are local to `data/quickshell.db`.

Qt's platform services register with the portal after `qt6ct` has already used
that D-Bus connection. A scoped `QT_NO_XDG_DESKTOP_PORTAL=1` default in `shell.qml`
skips that late registration and the unused native color-picker probe. This
startup setting takes effect after restarting Quickshell. See Qt's
[platform service initialization](https://github.com/qt/qtbase/blob/v6.11.2/src/gui/platform/unix/qdesktopunixservices.cpp).

Discord's tray item omits `IconName` and rejects Quickshell's refresh requests,
so the repeated warning comes from Quickshell's native tray implementation.
It requires an upstream fix; this QML configuration cannot change its polling.

### Handover from SwayNC (manual)

The service and Hypr configuration have not been changed by this implementation.
Both the popup and manager use the layer namespace `quickshell-notifications`.
The existing capture rule still targets SwayNC until you make this one-value edit
in `~/.config/hypr/config/windowrules.lua`:

```lua
match = { namespace = "quickshell-notifications" },
```

Keep `NotificationsHidden`, `no_screen_share`, and `HideApplications(active)`.
The shell synchronizes capture state on native startup, screen-sharing changes
and Hypr configuration reloads. After the namespace edit, verify that both
notification surfaces remain visible locally but disappear from a shared stream,
and become screenshot-visible again when sharing ends.

For a deliberate switch, stop the existing Quickshell instance, stop/mask SwayNC,
make the namespace edit, reload Hypr, then start the shell:

```sh
systemctl --user mask --now swaync.service
qs -p "$HOME/.config/quickshell"
```

Verify ownership with `busctl --user status org.freedesktop.Notifications` and send
a sample with `notify-send`. SwayNC's installed D-Bus activation files can start
its systemd unit on demand, so disabling it alone does not block activation.

To restore SwayNC, stop Quickshell, restore `swaync-notification-window` in the
Hypr rule, reload Hypr, and unmask/start SwayNC:

```sh
systemctl --user unmask swaync.service
systemctl --user start swaync.service
```

Use a Quickshell configuration without the native notification server before
starting Quickshell alongside SwayNC. The new history database can be retained.
Only one handler should own the notification interface. Live screen-sharing
checks remain part of this manual handover.

### Notification verification

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

## IPC

Quickshell supports calling functions through IPC, I used this to integrate hypr on some edge cases.

```sh
qs ipc call notifications reload # used to manually reload notification status
qs ipc call notifications toggle # used to toggle notification status
qs ipc call status reload # custom script i have to change working mode of my pc
qs ipc call windows next # go to next window
qs ipc call windows prev # go to previous windodw
qs ipc call windows reload # manually reload window list
qs ipc call windows focus [0-9] #index of the grouped window to move to
qs ipc call twitch reload # refresh Twitch
qs ipc call twitch addUser streamer_login
qs ipc call twitch removeUser streamer_login
qs ipc call twitch exportUsers > twitch-users.txt # one login per line
```

Hover the Twitch icon to see followed streamers and their next scheduled streams.
Click **+** to enter a streamer login or Twitch URL, then **+** or Enter to save;
**×** or Escape cancels. While adding, channels open in qutebrowser appear below
the field as buttons you can click to follow. **Add all** follows every currently
displayed suggestion at once. Already followed channels are hidden.
Suggestions read current tab entries from whichever of `_autosave.yml` or
`default.yml` was saved most recently in `$XDG_DATA_HOME/qutebrowser/sessions`
(defaulting to `~/.local/share/qutebrowser/sessions`). They refresh every three
seconds while the editor is open, so manually saving the default session updates
suggestions even before the next autosave. They use Bash and `yq` (the jq-compatible
YAML reader); missing or unreadable sessions simply show no suggestions.
Only the newest snapshot is read; previous browsing history is excluded.
The trash button removes a streamer. Left-click the Twitch icon to pin/unpin the
dropdown, with an accent color while pinned, as in TOTP and notifications.
Clicking a streamer's avatar or details opens their Twitch page in the default browser.
Logins are stored in lowercase and duplicates are rejected. A new database starts
with an empty list; there is no users-file import. Exported lists are ordinary text
files that you can save or share.

`DbService` owns a versioned SQLite database, with separate repositories for Twitch
users, schedules and avatar images, Logitech receiver battery snapshots, and user preferences.
The clock's seconds toggle is saved across restarts. Quickshell creates
`data/quickshell.db` inside this config on first run. The data folder is ignored
by Git apart from its empty-directory marker; no database is shipped in the
repository. `DbService` uses native SQLite `ATTACH` to open that path through
Qt Quick LocalStorage. Qt keeps an empty connection database in its default
storage directory; all application tables and schema versioning live in
`data/quickshell.db`. No preparation script is needed. `Config.databasePath`
uses `Quickshell.shellPath("data/quickshell.db")` and `Config.databaseName` is
the fixed name `quickshell`. Tests run their entrypoint in a temporary config
folder so their databases stay isolated.

Twitch schedules store absolute start times and refresh at most hourly while
cached, or sooner once the cached start has passed. Relative labels update with
the clock, including across midnight. Failed requests preserve the previous
cache. Avatar image payloads are stored as base64 data URLs in SQLite and displayed
directly by QML. A changed profile-image URL refreshes the cached image; failed
downloads retain the previous one. Removing a streamer deletes its schedule and
avatar too. The picker JSON remains a runtime export.

Twitch and TOTP use shared `UI.ActionButton` and `UI.InputField` controls. Shared
action glyphs such as add, cancel, delete, and check are defined once in `Theme.qml`.

Run `bash tests/storage/storage.sh` to check first-run creation, dropdown actions,
restart persistence, transaction rollback, avatar downloads, schedule caching, and midnight labels
using an isolated database and mock Twitch/receiver commands.
Add `--ipc` to check the real IPC commands and redirected export too.

The TOTP module stores each name and seed together in the desktop Secret Service. Its
UI is native QML; a Bash helper uses `secret-tool`, `jq`, and `oathtool`. On Arch:

```sh
sudo pacman -S --needed libsecret jq oath-toolkit
```

Run a Secret Service provider such as GNOME Keyring, or enable Secret Service support
in KeePassXC. Hover the key icon, click **+**, enter a name and a Base32 seed or an
`otpauth://totp/…` URI, then click **+** again. Copy a seed from Bitwarden manually;
this module uses its own keyring entries and does not synchronize with Bitwarden.
The pencil edits both fields, **✓** saves, and **×** cancels. Enter submits the token
field; Escape cancels. The trash button deletes the entry immediately.
Click the key icon to pin the panel open; click again to return to hover behavior.
The icon uses the accent color while pinned.

Tokens support SHA1, SHA256, SHA512, 6–8 digits, and custom periods from TOTP URIs.
Bare seeds use the defaults in `config/Config.qml` (SHA1, six digits, 30 seconds).
The countdown sits between the list and bottom controls, with seconds on the left
and a line that empties from right to left. It is hidden when the list is empty.
The list reserves at least ten
rows and grows up to 45% of the current monitor height, with a scrollbar when needed.
Adding a token uses a reserved footer row so the popup height stays stable.

Commands, keyring namespace, timing, and the height fraction are in `Config.qml`;
glyphs, sizes, spacing, and colors are in `theme/Theme.qml`. Keyring attributes are
`application=quickshell`, `type=totp`, `vault=<totpVault>`, and `id=<entry UUID>`.
Names and seeds are inside each item's secret payload. Secrets travel through
pipes, never command arguments or plaintext config files. Closing the tooltip
stops updates, clears its model, and exits the helper after any pending write.
The copied code remains on the clipboard until it is replaced.

Verification uses public test seeds and a fake keyring, without accessing desktop
secrets:

```sh
bash tests/security/totp.sh
bash tests/security/totp.sh --qml-smoke # headless Quickshell interaction check
```

Hover the mic or volume icon to see the available devices, with a level slider,
mute control, **Use now**, and **Set default** on each device. **Use now** moves
current PulseAudio-compatible recording or playback apps without changing the
system default. **Set default** changes the system default input or output; both
bar modules always control that default. Mic activity status and both process
lists remain visible and update live. Each app has its own mute button and a
compact device selector. These affect just that app's current streams, keeping
other apps and the system default unchanged. Apps with several streams are
grouped by their process. Selectors show their current device or **Multiple devices**
when their streams use different devices. Devices are sorted by their displayed
name.
Left-click a bar icon to mute; scroll it to adjust its default device. Right-click
pins its panel; middle-click opens `pavucontrol`.

Sliders support dragging, keyboard adjustment, and the mouse wheel, with up to
150% volume or microphone gain. `audioMaxVolume` and `audioVolumeStep` are in
`config/Config.qml`; panel width and maximum height are in `theme/Theme.qml`.
Long lists scroll within the current monitor. Device cards include their own
profile selector when profiles are available. Profiles affect the whole device,
including playback and recording; devices with an **Off** profile can be enabled
from the same selector. Bash helpers use `pactl`, `jq`, and `timeout` for current-app
routing and profiles; level, mute, default selection, activity, and process lists
use the native PipeWire service. Profile data refreshes only while a panel is open.

Run `bash tests/audio/audio.sh` for routing, profile, and QML interaction checks.
Add `--native-imports` to check the complete bar, real device/profile mapping,
sorted lists, and system default bindings without changing your audio settings.

Hover the battery icon immediately to the right of TOTP to see all detected
batteries. Each battery card fills from left to right and shows the device
name, percentage, charging status, and an estimate such as **Full in 1 h 20 min**
or **Empty in 3 h**. A plug icon identifies external power when reported, including
laptop batteries connected to AC while charging is paused or complete. Card fills
use green for normal levels, orange at 20% or below, and red at 10% or below. The
bar always uses a full battery glyph; any low or critical device changes its color
to orange or red. Otherwise it keeps the normal text color. Thresholds are in
`config/Config.qml`, and the shared colors are in `theme/Theme.qml`.

The module uses Quickshell's native UPower and Bluetooth services, updates as
devices change, and merges devices reported by multiple sources. Install and run
`upower`; Bluetooth battery reporting also needs BlueZ. When `solaar` is installed,
a Bash helper uses `jq` to read its public `solaar show` output at startup and every
minute, including while the tooltip is closed, to include Logitech receiver devices
missing from UPower, including the ERGO M575S Trackball
and supported headsets. The installed Solaar version must support the device.
`batteryReceiverInterval` and `batteryReceiverCommand` are in `config/Config.qml`.
Devices must expose their battery information to one of these services. Missing
charging status is labeled **Status unavailable**. The time line is shown only
when the device reports a charge or discharge estimate.
The tooltip content is created only while hovering. Battery readings and the bar's
warning color update from startup without needing to open the tooltip. Refreshes
keep the previous readings and bar color until a successful scan replaces them;
failed reads retain the cached data. A successful empty scan removes disconnected
receiver devices. Cached receiver readings and warning colors survive configuration
reloads and Quickshell restarts, and a connected device temporarily reporting no percentage keeps its last
known level. Brand information is shown alongside the model when available.
Native UPower
and Bluetooth levels continue to follow system updates without polling.
Disconnected Bluetooth devices and absent laptop batteries are excluded. Long
lists scroll within the current monitor. Font Awesome glyphs, their readable
icon names, battery card dimensions, and colors are in `theme/Theme.qml`.

Run `bash tests/system/batteries.sh` for the headless battery discovery and QML
card checks, including live updates, duplicates, disconnection, and scrolling.
Add `--native-imports` to verify the complete bar and live tooltip on Wayland.
