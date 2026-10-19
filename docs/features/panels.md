# Panels and focus

The optional [adaptive bar](../configuration.md#adaptive-bar-and-panel-backgrounds)
shares a readable sampled background with panels on the same monitor. In island
mode, panels extend matching backing behind the bar across their width. This
changes presentation only; pinning, keyboard focus and dismissal retain the
policies below.

All bar panels use left-click to pin/unpin and accent coloring for the pinned
icon: Calendar, Updates, Recent Files, Timers, Microphone, Volume, Stats, Twitch,
Status, TOTP, Batteries, Notifications, Screen sharing and Screen recording. Hover panels use native keyboard mode None, so opening one neither takes
keyboard focus nor activates an outside-click grab. Clicking a control enables
keyboard interaction; the shared grab includes both panel and bar, preserving
reliable icon clicks. Pointer leave dismisses an unpinned panel after the usual grace
period, including travel between the icon, panel and owned popup areas.

Calendar keeps right-click for month/year and uses middle-click for seconds.
Audio mute buttons are at the top right of the respective panels; scroll still
adjusts volume and middle-click opens the mixer. Updates puts its update count
and last-checked time on the left of a compact header, beside notes and download
buttons for opening the Markdown list and installing updates. A full-width search
below the header filters priority and other updates together by package name,
repository or version. Each section divider shows only its matching count at the
right edge, in the same color as that section's package names; the header keeps
the total available count.

A focused search keeps its panel open if filtering shrinks it away from the
pointer. This is a temporary keyboard-focus hold, with no automatic pinning;
hovering another module can still replace the search panel. Losing keyboard focus
releases the hold and resumes normal hover dismissal. Explicit keyboard sessions
also survive pointer leave, keeping Escape usable. Editing a form protects only
its active owner; leaving the owning window releases that protection. Native child
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

## Keyboard navigation and actions

Keyboard focus has an accent outline distinct from a tab's active underline.
Tab and Shift+Tab traverse enabled, visible controls; focused controls in scroll
areas scroll into view. Tab-strip arrows select and activate the next tab through
the same action as a click. Window buttons in the bar instead move focus with
arrows and activate with Enter/Space.

Panel actions use the grouped `Config.keybinds` settings described in
[configuration](../configuration.md#panel-keybinds). Buttons and their shortcuts
share enabled states and handlers, and shortcut hints follow configuration.
Native text editing takes priority. Hidden panels, inactive windows, native child
dialogs and selection popups cannot dispatch their parent's actions. Focus
feedback works with motion disabled and during screen sharing.

Clipboard borrows focus through shared `PanelFocusService` and
`WindowFocusHandler` behavior. Existing panel sessions suspend their keyboard
grabs and outside-dismissal while Clipboard is active, retaining their content.
Only the saved destination requests focus on return. Panel paste uses the
original Qt text control after clipboard restoration succeeds, preserving normal
selection replacement without injecting keys into the underlying application.
Native child-dialog handoff and capture visibility policy remain separate.

Wallpaper, Clipboard images and the window switcher share a separate larger
preview window below the standard picker. `PreviewPickerPanel` owns defaults and
toggle state; `PickerPreviewSurface` owns bounded geometry, motion and content
lifetime. A thin `PickerPreviewWindow` supplies the native layer surface with
keyboard focus disabled and a fixed public/private namespace matching its host.
The list's focus grab includes its preview companion. Both use the existing
capture-visibility policy, and motion follows the shared screen-sharing rules.

## Keyboard entry points

The companion Hypr modules submap uses native `quickshell:bar-NAME` global actions.
All 14 registrations share the root shortcut registry and call
`BarModuleService.open(NAME)`, preserving the existing focused-monitor, module
availability and keyboard-session behavior. Hover remains passive. Vault uses
`quickshell:vault-toggle`; notification DND uses
`quickshell:notifications-toggle-dnd`. External callers can still use the existing
IPC interfaces with arguments and results. Both entry points reuse feature services.

## Motion

View tabs form a compact group centered on their existing header line, including
during resizing. Headers keep their right-side actions in place; overflowing tabs
scroll horizontally. Window action tabs retain their original alignment. On
workspaces configured for window tabs, only groups with multiple members appear
as tabs. The focused standalone window uses the plain title style after the tabs;
inactive standalone titles are omitted. Numbered group shortcuts follow tab order.

Top panels drop down from the bar in 150ms and roll up in 100ms. Size changes settle in 160ms, retargeting the current frame when content changes
again. Module anchors update immediately; centered pickers resize both edges together.
Changing modules reveals the new
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

Panels default to `hideForCapture: false`. Screenshots and recording share this
property; capture controls opt in. Shared top-panel hosts forward the panel
property and route `captureHideRequested` to its owning close action. Only opted-in
panels close and participate in capture readiness; other panels keep their state.
Private compositor capture exclusions remain independent of this close policy.

Capture waits for the panel's visual closing motion and native unmap, then for
the compositor's configured layer/fade-out animation and a display refresh.
CaptureCloseTiming resolves inherited active Hypr animation settings; disabled
animations add no animation wait. No synthetic transparent frame is rendered.

Shared UI components and panel motion helpers live in `src/ui/`, with shader
assets in `src/ui/shaders/`. Theme holds styling settings and palettes. Picker,
Manage, Vault and selection rows share `UI.SelectableRow` for interaction and
selection styling while retaining their specialized contents and sizing.
