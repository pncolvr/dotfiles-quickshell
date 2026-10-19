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
Artwork uses the shared `UI.CroppedImage` filtering and mipmaps. Confidently
detected thin, saturated circular frames are trimmed inside their edge, using
the same cached analysis as avatars and notifications. Ordinary or ambiguous
artwork keeps its existing shape. The display retains the original raster
resolution; SVG artwork rasterizes at device resolution, including in fullscreen.
Wide artwork keeps its full image centered in the aligned square slot, with
transparent space around it so the blurred card background shows through.
Missing or failed artwork falls back to the app icon or a music glyph.
Available artwork also fills the card background with a heavily blurred, darkened
image, clipped to its rounded corners. Missing or failed artwork keeps the usual
solid background. Theme.qml controls the blur radius, tint and opacity.
Artwork sits beside the title, artist and app name. A mute button,
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
streams, which can include other browser tabs. Unmatched or ambiguous players
hide the mute button, volume slider, percentage, and Flip button. Controls
reappear when a matching stream becomes available. Mute uses PipeWire's mute
control. No extra bar icon or keyboard shortcut is added.

The **Flip** icon at the top right turns a compact card from right to left to
reveal its visualizer. The same button turns it back from left to right.
A permanent scrolling list offers **17 styles**, with opaque hover backgrounds.
The reverse face omits track details; its list spans the card height with equal
top and bottom padding, beside the Flip and Fullscreen buttons.
Selection uses the shared dropdown row's accent text and selected background.
`Config.mediaVisualizerEnabled` independently controls visualization in the card
and fullscreen view, including during screen sharing. Card flips and fullscreen
transitions retain the general animation policy.

The last selected effect is saved separately for each app and restored after
reopening the panel or restarting the shell. Cards from the same app share its
choice, using its desktop identity rather than a temporary player or process ID.
The previous global choice remains the initial default for apps that have not
picked an effect yet.

Both compact faces keep the same size and blurred artwork background. The
visualizer fills the card above that background and beneath its content, clipped
to the rounded corners. The playback face uses a softer overlay;
`Theme.mediaVisualizerFrontOpacity` and `Theme.mediaVisualizerBackOpacity`
control its strength. Flip aligns with the artwork's top edge. Details are
centered across the full space beside the artwork, and the mute button's bottom
aligns with the artwork's bottom.
When the media length is unavailable, mute, volume and percentage move into the
bottom row beside playback controls, replacing the hidden position controls.
Flips also respect `Config.animateDuringScreenShare`: when disabled, they switch
faces immediately during sharing, including finishing any flip already in progress.

The **Fullscreen** icon opens an opaque, borderless view with one player at a
time. Entry zooms from the compact card's bounds; exit shrinks toward them using
Exposé's cubic easing. Fullscreen has one face: a scrolling effect list on the
left, larger text centered on the screen, and artwork at the bottom right above
the app volume controls, matching their width. Transport, seeking and app volume
run along the bottom. The bottom row spans the screen with **2% margins**
on the left, right and bottom. The saved visualizer runs behind this content.

**Left** and **Right** cycle between available players, wrapping at either end.
Previous/next player buttons and a position indicator appear when there is more
than one player. Next slides the current view left and brings the next in from
the right; Previous reverses that direction, including at the wraparound.
The outgoing view is one frozen image captured at native screen resolution.
Rendering and position polling pause during the slide, with one live view.
Repeated navigation during a slide is ignored. Set
`Theme.mediaFullscreenSwitchDuration` to adjust the slide or zero to disable it.
Only the selected player is processed. The icon at the top
right, **Escape**, or **Alt+F4** exits independently of child focus or the zoom.
Closing immediately releases keyboard focus and pointer capture. A 750 ms
deadline hides and cleans up the view even if the closing animation stalls.
Removing the selected player also closes fullscreen.

Fullscreen draws the live visualizer directly at screen resolution, keeping
native geometry and shader details sharp without an upscaled intermediate texture.
Only the cached blurred artwork uses a smaller **960×540** texture, avoiding
full-screen blur and mask passes on each audio frame. Pausing, muting and zoom
transitions stop rendering and position polling; compact cards also stop while
fullscreen is open. Exiting unloads the view and its textures. The animation is
skipped during screen sharing by default, including player slides and the opening
snapshot capture. `Config.animateDuringScreenShare` enables them during sharing
and also controls Exposé. `Theme.mediaFullscreenAnimationDuration`
controls entry duration; closing is capped at 300 ms. A zero duration disables
the zoom. `Theme.mediaFullscreenCacheWidth` and
`Theme.mediaFullscreenCacheHeight` control the blurred background's cache budget.

The effects use actual frequency bands from cavacore, CAVA's analysis engine.
The 64 stationary bands run from bass to treble on a logarithmic scale, and each
moves independently with that part of the audio. Cavacore provides FFT analysis,
automatic sensitivity, smoothing and falloff. The available styles are:

- Native views: Wave, Bars, Mirror, Ribbon, Bars from top, Bars from left,
  Bars from right, and Waveform.
- All nine shaders shipped with CAVA 1.0.0: CAVA Spectrum, Winamp Line,
  Northern Lights, Eye of Phi, Orion Circle, Orion Rotate, Orion Saturn Core,
  Orion Saturn Subring, and Spectrogram.

Wave and Ribbon connect the frequency bands. Waveform displays actual signed
PCM samples. Spectrogram shows frequency intensity over time; the other CAVA
presets use the original upstream shader algorithms, adapted to Qt Quick and
transparent backgrounds. Eye of Phi and Orion Rotate animate only during active
playback with audio. Shader presets require a hardware graphics backend with
modern GLSL support; native views also work with Qt's software renderer.

A small native helper captures the matched PipeWire stream directly and links
against vendored cavacore 1.0.0 and the system FFTW library. It preserves stereo
channels during analysis, then averages their magnitudes. Apps with multiple
streams combine the highest value in each corresponding band. Association follows
the same uniqueness checks as app volume. No system-output or microphone fallback
is used. If the match disappears while viewing the visualizer, the card flips
back to playback and hides its stream controls.

Both faces share one analysis stream and renderer. Capture and rendering run only
for a visible, matched, unmuted app while playback is active and the card is inside
the viewport. The visible face must also have nonzero visualizer opacity.
Pausing, muting, hiding the card or panel, or playing the flip animation stops
capture and texture updates, detaches the shared texture source, and unloads the
face mask and shader renderers. Individually muted streams stop their analyzers
even when other streams from the same app remain audible. Rendering resumes on
the visible face when needed. Analysis runs at 30 frames per
second on the CPU; Qt Quick Shapes and scene graph rectangles draw on the GPU
with the normal accelerated backend. The software backend remains supported.
No Canvas bitmap is repainted or uploaded for each audio update. CAVA shaders
read a tiny GPU-rendered band texture, uploaded once per audio frame. The GPU
interpolates previous and current levels between frames, smoothing the non-rotating
presets without reducing fullscreen resolution or increasing audio analysis frequency.
Spectrogram uses current levels directly and a bounded 512-column
GPU history texture, updated only on new audio frames. Shader styles do not
calculate unused native waveform geometry. Identical spectrum frames skip texture
updates except for Spectrogram, which must advance its time axis. PCM samples
are decoded only for Waveform.

The helper builds automatically into `$XDG_RUNTIME_DIR/quickshell-spectrum` on
first use and rebuilds when its source changes. It requires `cc`, `pkg-config`,
and the PipeWire and FFTW development files; the full CAVA executable is not
required. A failed backend shows **Audio visualizer unavailable**.

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
when their streams use different devices. Output and microphone lists put devices
with an **Off** profile last, sorting each group alphabetically by displayed name.
Left-click either bar icon to pin or unpin its panel; the pinned icon uses the
accent color. Scroll adjusts its default device and middle-click opens
`pavucontrol`. The top-right mute button inside each panel controls its default
microphone or output. Device and app mute controls retain their individual scope.
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

Compositor capture synchronization waits for PipeWire's initial sync and tracked
node readiness. Starting or restarting the bar, or losing the PipeWire connection,
does not publish an incomplete graph as "not sharing". The combined state stays
active until the final capture ends.

Quickshell applies `Config.hyprlandAnimationsEnabled` and the current capture state
directly: compositor animations run only when the setting is enabled and no share
is active. Config edits are honored on bar reload/restart. The final share restores
the current configured value; application-hiding refreshes and Hypr reloads apply
the same rule. This is separate from UI animation controls in Config and MotionPolicy.

The Hypr **Meta+X** binding is removed. There is no stored preference override,
animation IPC control or separate state file. During Hypr configuration loading,
animations stay disabled and private capture rules stay enabled until Quickshell
reconciles them after capture discovery is ready.

[Documentation](../README.md)

Device and profile selectors open floating, framed dropdowns without resizing
the audio panel. Options scroll within the available panel space and open above
the control when necessary. Arrow keys navigate available options, Enter applies,
and Escape dismisses the dropdown. Media-effect lists share the same row styling
and selection behavior while remaining permanently visible.
