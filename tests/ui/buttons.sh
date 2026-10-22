#!/usr/bin/env bash
# Synthetic controls, mocked profiles and offscreen input; no desktop or clipboard access.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
node "$repo/tests/ui/button-colors.mjs"
fixture=$(mktemp -d /tmp/qs-buttons-test.XXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/r" "$fixture/home"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -Ei 's/readonly property bool darkMode: (true|false)/property bool darkMode: true/' "$fixture/src/theme/Theme.qml"
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/;s/adaptiveBarEnabled: true/adaptiveBarEnabled: false/' "$fixture/src/config/Config.qml"
cp "$repo/tests/launcher/NativeFocusDriver.qml" "$fixture/"
sed 's@"../../src@"src@g;s@"../launcher"@"."@g' "$repo/tests/ui/buttons.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u DISPLAY QS_DISABLE_CRASH_HANDLER=1 \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 \
    HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/r" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 2 12 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
rg 'PASS:' "$fixture/log"
! rg -q 'BUTTONS FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration|Unable to assign' "$fixture/log" || { cat "$fixture/log"; exit 1; }
