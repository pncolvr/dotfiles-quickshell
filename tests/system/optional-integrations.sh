#!/usr/bin/env bash
# Synthetic helpers, private database and offscreen UI only; no real session files or devices.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-optional-integrations.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
: > "$fixture/runs"
mkdir "$fixture/bin"
cat > "$fixture/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
if [[ ${1:-} == eval ]]; then
    printf 'capture:%s\n' "$2" >> "$QS_OPTIONAL_RUNS"
else
    printf '[]\n'
fi
MOCK
chmod +x "$fixture/bin/hyprctl"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/readonly property bool hyprlandHideApplicationsEnabled:/property bool hyprlandHideApplicationsEnabled:/' "$fixture/src/config/Config.qml"
sed -i 's/readonly property bool batteriesEnabled: .*/property bool batteriesEnabled: false/;s/readonly property bool twitchQutebrowserEnabled: .*/property bool twitchQutebrowserEnabled: false/;s/readonly property bool twitchEnabled: .*/property bool twitchEnabled: true/;s/readonly property string defaultBrowserId:/property string defaultBrowserId:/;s/readonly property var browsers:/property var browsers:/;s/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/;s@readonly property string twitchCli:.*@readonly property string twitchCli: "qs-missing-fixture-twitch"@;s@readonly property int batteryReceiverInterval:.*@readonly property int batteryReceiverInterval: 100@' "$fixture/src/config/Config.qml"
cat > "$fixture/src/services/twitch/qutebrowser-channels.sh" <<'MOCK'
printf 'browser\n' >> "$QS_OPTIONAL_RUNS"
sleep 0.3
printf '["fixturechannel"]\n'
MOCK
cat > "$fixture/src/services/system/logitech-batteries.sh" <<'MOCK'
printf 'battery\n' >> "$QS_OPTIONAL_RUNS"
sleep 0.15
printf '{"devices":[{"id":"receiver:fixture","name":"Fixture","brand":"Test","percentage":63,"state":"discharging","pluggedIn":false,"internal":false}],"error":""}\n'
MOCK
cat > "$fixture/src/services/audio/AudioService.qml" <<'QML'
pragma Singleton
import QtQml
QtObject {
    property bool screencastActive: false
    readonly property bool screencastReady: true
}
QML
sed 's@"../../src@"src@g' "$repo/tests/system/optional-integrations.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    QS_OPTIONAL_RUNS="$fixture/runs" PATH="$fixture/bin:$PATH" XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache" \
    timeout 20 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: optional Twitch session suggestions' "$fixture/log" \
    || rg -q 'OPTIONAL FAIL:|TypeError:|ReferenceError:|Binding loop|Cannot assign|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
