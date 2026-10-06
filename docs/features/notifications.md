# Notifications

Quickshell handles notifications directly whenever the shell starts. No
environment variable or separate notification-center package is required.

## Manager and source settings

Hover the bell to open the manager and left-click to pin/unpin
it. The manager provides **History** and **Emitters** tabs. Emitter groups start
collapsed with their latest notification visible and the bottom edges of up to
two older cards stacked underneath. Click the header or a stacked edge to expand
the group. Both groups and their entries
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
Twitch sends normal-urgency, nontransient notifications under its own emitter name,
so its notifications and icons are retained in history. New Twitch notifications
list streamer login names under Live and Offline headings, without a view button.
Extra images supplied by any app, including Discord and Signal user/group
images, overlap the app icon with an offset down and right, leaving the app icon
visible above and to the left. If no app icon is available, the supplied image
occupies the left icon slot on its own. This applies to both popups and history.
Extra images are center-cropped and masked into circles. Overlapping images with
opaque near-black padding at all four corners receive a
small, one-time alpha mask that removes edge-connected padding and preserves
enclosed dark details. The title sits directly below the app name,
with a small gap before the body. Timestamps appear only in history and use
`yyyy-MM-dd hh:mm:ss`, always including seconds. Markdown bodies render code
blocks, emphasis, links, and lists; plain-text bodies keep their line breaks.
Long formatted bodies are clipped in popups and shown in full in history.
Timed popup outlines drain symmetrically from the bottom center up both sides to the top
center, synchronized with rendered frames as in TOTP. Hovering a popup pauses its
expiry and outline; leaving resumes the remaining time. The close
button is circular and turns red on hover. History cards use a complete outline
in their urgency color. Application timeouts take
priority over the configured low/normal/critical defaults. Left-click runs a usable
default action, then falls back to focusing a matched existing app only when no
default action is usable. Explicit action buttons appear only on popups and invoke
their own actions. History hides action buttons, including for notifications that
are still live. Right-click dismisses a popup without deleting its history;
right-click in history deletes that entry. Action identifiers and labels are
saved with history. Generic app callbacks cannot be restored, as the notification
protocol invalidates their IDs on closure. See the
[notification protocol](https://specifications.freedesktop.org/notification/latest/protocol.html).
The locally implemented legacy Twitch default action still works on card clicks.
Focus lookup includes other workspaces and desktop `StartupWMClass`. If no window
matches, the feedback message clears three seconds after the click.

See [setup](../setup.md) for notification ownership and screen-sharing rules,
[storage](../storage.md) for history persistence, and
[troubleshooting](../troubleshooting.md) for replacement limitations.

[Documentation](../README.md)
