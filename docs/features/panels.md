# Panels and focus

All bar panels use left-click to pin/unpin and accent coloring for the pinned
icon: Calendar, Updates, Recent Files, Timers, Microphone, Volume, Stats, Twitch,
Status, TOTP, Batteries, Notifications and Screen sharing. Hover panels use native keyboard mode None, so opening one neither takes
keyboard focus nor activates an outside-click grab. Clicking a control enables
keyboard interaction; the shared grab includes both panel and bar, preserving
reliable icon clicks. Pointer leave dismisses an unpinned panel after the usual grace
period, including travel between the icon, panel and owned popup areas.

Calendar keeps right-click for month/year and uses middle-click for seconds.
Audio mute buttons are at the top right of the respective panels; scroll still
adjusts volume and middle-click opens the mixer. Updates puts its update count
and last-checked time on the left of a compact header, beside notes and download
buttons for opening the Markdown list and installing updates.

Typing a search does not pin or retain a panel. Editing a form protects only its
active owner; leaving the owning window releases that protection. Native child
dialogs, requested folder additions and active drags temporarily retain the owner. Dialog acceptance,
cancellation and owner destruction release the hold and preserve manual pins.

Launchers explicitly focus their input, or their root for previews, without moving
the cursor. Escape and outside click dismiss ordinary launchers; their multi-step
flows keep existing selection and query behavior. Vault and secret prompts can
remain open when another app takes focus. Vault keeps its draft and does not
refocus Search when you return from another app. The manager yields to its unlock
prompt and restores Search focus when that prompt finishes, preserving the query.
Persistent managers and password prompts retain
keyboard focus when the pointer leaves; an outside click releases focus while
preserving the manager or prompt. Expanded media keeps its explicit keyboard controls.

Escape is handled by the innermost editor/popup first and then by the focused
panel. A passive hover panel never grabs Escape from the application underneath.
Tray expansion, workspace buttons, badges, small hints and notification toasts
keep their existing passive/transient policies. The tray shortcut opens a focused
popup using the same tray contents, preserving keyboard access without a cursor
warp. Native tray menus use the shared child-dialog focus handoff.

The shared components are `TooltipArea` (pin gesture and color),
`WindowFocusHandler` (activation and native-child lifecycle), `PanelFocusScope`
(Escape fallback), and `FolderDialog` (native selection). Module-specific adapters
declare policy; they do not implement separate pinning or dismissal mechanisms.

## Motion

Top panels drop down from the bar in 150ms and roll up in 100ms. Size changes settle in 160ms, retargeting the current frame when content changes
again. Horizontal anchors update immediately. Changing modules reveals the new
content from its own anchor rather than sliding across the bar. Content fades
during size changes so calendar and other layout changes do not stretch it.
The shared native host keeps a viewport-sized transparent buffer while mapped;
only the panel drawing and input mask change size. This avoids compositor buffer
stretching when tabs shrink, including with UI animations disabled. The shared
tooltip loader keeps content top-aligned while the visible panel resizes,
so shorter tabs do not jump through the center of the outgoing panel. Tab changes
hide replacement content synchronously before layout and use the same fade even
when both views have the same size. Only the contents fade, while the frame, bar shadow and keyboard focus stay in
place. Rapid selections show the latest tab immediately without queuing fades.
Clipboard layout transitions use the same resize timing and pass their animated
geometry through directly. Controls can receive input during opening. Closing
releases focus, grabs and input immediately while the outgoing panel finishes its
short visual transition. The bar shadow stays anchored while the panel outline
moves beneath it. Its opacity fades on opening and closing, stays steady across
module changes, and follows the same screen-sharing policy. The shadow capture
keeps the larger reserved size throughout a resize.

`UI.MotionPolicy` is the single animation policy. Its `enabled` gate requires
`Config.animationsEnabled` and either inactive screen sharing or
`Config.animateDuringScreenShare`. Disabling the master switch or starting a
restricted share settles active finite animations immediately and pauses
decorative effects. Screen-sharing, microphone and volume pulses and notification
countdown borders use independent Config switches through the same policy. These
status animations remain available during screen sharing and with the master
switch off. See the animation policy in `docs/configuration.md` for the switches.
Functional clocks, expiry and data updates keep running.

`TopPanelTooltip` shares `TopPanelSurface` and `UI.PanelMotion` across public and
private hosts. `TooltipContent` supplies the shared `contentKey` when a module changes. `requestedVisible` controls logical interaction; native `visible`
retains the surface for closing. `TooltipContent` retains outgoing hover content
until the roll-up ends, while services and secret-state cleanup follow logical
closure. Theme timings are `panelOpenDuration`, `panelCloseDuration` and
`panelResizeDuration`.
