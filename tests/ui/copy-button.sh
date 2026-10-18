#!/usr/bin/env bash
# Offscreen feedback only: no clipboard writes or native desktop input.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-copy-button.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
cp -a "$repo/src" "$fixture/src"
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$fixture/src/config/Config.qml"
cp "$repo/tests/launcher/NativeFocusDriver.qml" "$fixture/NativeFocusDriver.qml"
sed -e 's@"../../src@"src@g' -e 's@"../launcher"@"."@g' "$repo/tests/ui/copy-button.qml" > "$fixture/shell.qml"
output=$(env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u DISPLAY \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 \
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout 10 qs -p "$fixture" 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *'PASS: shared copy'* && $output != *'COPY BUTTON FAIL:'* \
    && $output != *'Failed to load configuration'* && $output != *'TypeError:'* \
    && $output != *'ReferenceError:'* && $output != *'Binding loop'* ]]
