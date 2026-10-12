# Audio

## Playing media

The volume panel has a **Media** tab with artwork, track and player information,
previous, play/pause, next and stop controls. When a player is playing, opening
the panel selects Media by default (`mediaPreferPlayingTab` in Config.qml).
Otherwise it opens Apps. Playback changes do not switch tabs while the panel is
open. The microphone panel keeps its existing tabs.

Native MPRIS discovers supported players, including paused players. Stopped
players are hidden when they cannot accept Play, and reappear when their state
or Play capability changes. Every visible player
has its own card in a scrollable list, ordered by app name. Playback changes keep
that order stable. Media can grow to the available screen height, accounting for
the bar, panel padding and shadow. The other audio tabs keep their existing height
limit. Switching tabs preserves the Media list's scroll position.
Artwork uses the shared `UI.ScaledImage` filtering and mipmaps.
Wide artwork keeps its full image centered in the aligned square slot, with
transparent space around it so the blurred card background shows through.
Missing or failed artwork falls back to the app icon or a music glyph.
Available artwork also fills the card background with a heavily blurred, darkened
image, clipped to its rounded corners. Missing or failed artwork keeps the usual
solid background. Theme.qml controls the blur radius, tint and opacity.
Artwork sits beside the title and artist. A mute button,
short horizontal volume slider and percentage sit below the metadata. Transport
buttons, elapsed time, timeline and duration share a row below that information.
Artwork spans from the Previous button's left edge to the Stop button's right
edge. Song details are centered beside it, and the volume slider extends to the
timeline's right endpoint. Both sliders reserve the same width for their readouts.
Unsupported playback controls are disabled; Stop stops playback without quitting
the application. Other audio applications remain available in Apps.

Each card shows elapsed and total time when the player provides them. Drag or
click the timeline to seek; keyboard adjustment also works. Seeking requires a
known positive duration and player support for both position and seeking. Live
streams with unknown durations, including overflowing duration sentinels, hide
the elapsed time, timeline and duration. Missing position support also hides them.
Players with a known duration but no seeking support have a disabled timeline.
The mouse wheel scrolls the list rather than seeking.
Position refreshes at `mediaPositionInterval` from Config.qml, only while the
player is playing and its card is visible in the Media viewport. A read-only
`busctl` query reads the player's MPRIS position directly, avoiding stale native
position estimates after a track change. Hidden cards stop polling; showing a
card or resuming playback requests a fresh position.
Playback-state changes request a fresh position. Stopped players immediately
display zero elapsed time; Play after Stop updates the timeline to the restarted
position supplied by the player. Track changes clear elapsed time and the timeline
until the new position arrives. Responses from before a track change or seek are
discarded, and elapsed time cannot exceed a known duration. Metadata, duration and artwork
continue to update through native MPRIS.

Volume and mute reuse AudioService when player and audio-app metadata identify
one unambiguous association. These controls affect all of that app's current
streams, which can include other browser tabs. Ambiguous associations use the
player's own volume when supported; otherwise volume and mute are unavailable.
Player mute sets volume to zero and restores its previous level on unmute,
falling back to `mediaUnmuteVolume` when no previous level is known. App-stream
mute uses PipeWire's mute control. No extra bar icon or keyboard shortcut is added.

## Devices and applications

Hover the mic or volume icon to open the panel. Switch to **Apps**, **Audio outputs**
or **Microphones** for device controls. Each list keeps its scroll position when
switching tabs. The tabs share their style with the notification panel.
Devices have a level slider,
mute control, **Use now**, and **Set default** on each device. **Use now** moves
current PulseAudio-compatible recording or playback apps without changing the
system default. **Set default** changes the system default input or output; both
bar modules always control that default. App lists update live and show an empty
message when no apps are active. The microphone panel shows a recording icon
beside its tabs; hover it to see whether mic activity is enabled or disabled.
Each app has its own mute button, compact device selector, and level slider with
a percentage. Playback sliders adjust output volume; recording sliders adjust
the microphone level received by that app. For apps with several streams, the
slider shows their highest volume and sets all of them to the chosen level.
These controls affect just that app's current streams, keeping
other apps and the system default unchanged. Apps with several streams are
grouped by their process. Selectors show their current device or **Multiple devices**
when their streams use different devices. Devices are sorted by their displayed
name.
Left-click a bar icon to mute; scroll it to adjust its default device. Right-click
pins its panel; middle-click opens `pavucontrol`.
Muted bar icons pulse only while an app has an active PipeWire link to the
corresponding default device. With no request, the muted icon stays static.
Volume mute uses a crossed-out speaker so its state is clear without animation.
Paused streams and apps routed to other devices do not trigger that pulse.
Microphone level monitoring uses the same active-device request check and also
stops while the microphone is muted.

## Levels and profiles

Sliders support dragging, keyboard adjustment, and the mouse wheel, with up to
150% volume or microphone gain. `audioMaxVolume` and `audioVolumeStep` are in
`src/config/Config.qml`; panel width and maximum height are in `src/theme/Theme.qml`.
Long lists scroll within the current monitor. Device cards include their own
profile selector when profiles are available. Profiles affect the whole device,
including playback and recording; devices with an **Off** profile can be enabled
from the same selector. Bash helpers use `pactl`, `jq`, and `timeout` for current-app
routing and profiles; level, mute, default selection, activity, and process lists
use the native PipeWire service. Profile data refreshes only while a panel is open.

See [development](../development.md#audio) for routing and native device checks.

## Screen sharing

Hover the screen-sharing indicator, or press **Meta+I**, then **H**. Its panel
shows **Screen sharing** and one description per PipeWire video capture. It uses
the source name or stream name, falling back to app metadata and then **Video
capture**. Known webcam sources are excluded. The panel has no capture controls.

[Documentation](../README.md)
