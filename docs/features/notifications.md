# Notifications

Quickshell handles notifications directly whenever the shell starts. No
environment variable or separate notification-center package is required.

## Manager and source settings

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
The same source settings are available in the Emitters tab. Its trash button
deletes the emitter, its history and settings, and dismisses current notifications.
If the app sends another notification, the emitter returns with default settings.
These settings are independent and persist after clearing history. DND blocks every
source by default, including critical notifications; allowing a source does not
override mute. Excluding history affects future notifications and replacements,
and retains existing records. Turning off DND or unmuting never replays a backlog.

## Popups, images, and actions

Popups follow Hypr's focused monitor, falling back to the last connected screen
or another available screen. Moving the stack keeps notification identities and
deadlines. Popups use the SwayNC reference's dark background at 95% opacity, rounded
corners and bold monospace text. App icons occupy a left-hand column beside the
content. File icons supplied through
`notify-send`, including the custom Twitch logo, use this same left icon slot.
Twitch sends low-urgency, nontransient notifications under its own emitter name,
so its notifications and icons are retained in history. Clicking a Twitch
notification or its **Open Twitch** button opens the configured Twitch URL,
including from saved history after expiry or restart.
Extra images supplied by any app, including Discord and Signal user/group
images, overlap the app icon with an offset down and right, leaving the app icon
visible above and to the left. If no app icon is available, the supplied image
occupies the left icon slot on its own. This applies to both popups and history.
Overlapping images with opaque near-black padding at all four corners receive a
small, one-time alpha mask that removes edge-connected padding and preserves
enclosed dark details. The title sits directly below the app name,
with a small gap before the body. Timestamps appear only in history and use
`yyyy-MM-dd hh:mm:ss`, always including seconds.
Timed popup outlines drain symmetrically from the bottom center up both sides to the top
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

See [setup](../setup.md) for notification ownership and screen-sharing rules,
[storage](../storage.md) for history persistence, and
[troubleshooting](../troubleshooting.md) for replacement limitations.

[Documentation](../README.md)
