#!/usr/bin/env bash
# Offscreen synthetic menus and settings; no clipboard, audio or capture actions.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-prompts-test.XXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/r" "$fixture/home"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/readonly property var pickerPrompts:/property var pickerPrompts:/;s/readonly property string language: .*/readonly property string language: "en"/;s/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/;s/adaptiveBarEnabled: true/adaptiveBarEnabled: false/' "$fixture/src/config/Config.qml"
cp "$repo/tests/launcher/NativeFocusDriver.qml" "$fixture/"
sed 's@"../../src@"src@g' "$repo/tests/launcher/prompts.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u DISPLAY QS_DISABLE_CRASH_HANDLER=1 \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 \
    HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/r" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 2 12 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: configurable picker placeholders' "$fixture/log" || rg -q 'PROMPTS FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration|Unable to assign' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
rg 'PASS:' "$fixture/log"
