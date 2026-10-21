#!/usr/bin/env bash
# Synthetic capture routes and isolated alerts; no real capture or audio access.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-capture-alert.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
cp "$repo/tests/launcher/NativeFocusDriver.qml" "$fixture/"
sed -i 's/readonly property string language: .*/property string language: "en"/;s/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/' "$fixture/src/config/Config.qml"
sed 's@"../../src@"src@g;s@"../launcher"@"."@g' "$repo/tests/audio/capture-alert.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 \
    PIPEWIRE_REMOTE=capture-alert-test XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 2 10 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: screen capture alert' "$fixture/log" \
    || rg -q 'CAPTURE ALERT FAIL:|TypeError:|ReferenceError:|Binding loop|WARN scene|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
