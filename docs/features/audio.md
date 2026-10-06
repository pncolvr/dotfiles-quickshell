# Audio

## Devices and applications

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

[Documentation](../README.md)
