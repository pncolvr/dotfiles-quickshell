# Batteries

## Levels and warnings

Hover the battery icon immediately to the right of TOTP to see all detected
batteries. Each battery card fills from left to right and shows the device
name, percentage, charging status, and an estimate such as **Full in 1 h 20 min**
or **Empty in 3 h**. A plug icon identifies external power when reported, including
laptop batteries connected to AC while charging is paused or complete. Card fills
use green for normal levels, orange at 20% or below, and red at 10% or below. The
bar always uses a full battery glyph; any low or critical device changes its color
to orange or red. Otherwise it keeps the normal text color. Thresholds are in
`src/config/Config.qml`, and the shared colors are in `src/theme/Theme.qml`.

## Discovery and refresh

The module uses Quickshell's native UPower and Bluetooth services, updates as
devices change, and merges devices reported by multiple sources. Install and run
`upower`; Bluetooth battery reporting also needs BlueZ. When `solaar` is installed,
a Bash helper uses `jq` to read its public `solaar show` output at startup and every
minute, including while the tooltip is closed, to include Logitech receiver devices
missing from UPower, including the ERGO M575S Trackball
and supported headsets. The installed Solaar version must support the device.
`batteryReceiverInterval` and `batteryReceiverCommand` are in `src/config/Config.qml`.
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
icon names, battery card dimensions, and colors are in `src/theme/Theme.qml`.

See [development](../development.md#batteries) for discovery and native tooltip checks.

[Documentation](../README.md)
