#!/usr/bin/env bash
# Offscreen geometry/rendering only, with synthetic images and no desktop actions.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-floating-preview.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
mkdir -p "$fixture/data/clipboard"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/;s/readonly property bool pickerPreviewEnabled:/property bool pickerPreviewEnabled:/;s/readonly property var pickerPreviewDefaults:/property var pickerPreviewDefaults:/' "$fixture/src/config/Config.qml"
sed -i 's@readonly property var clipboardCommand:.*@readonly property var clipboardCommand: ["true"]@' "$fixture/src/config/Config.qml"
cat > "$fixture/src/services/audio/AudioService.qml" <<'QML'
pragma Singleton
import QtQml
QtObject { property bool screencastActive: false }
QML
magick -size 1600x900 pattern:checkerboard "$fixture/landscape.png"
magick -size 400x1200 pattern:checkerboard "$fixture/portrait.png"
cp "$fixture/landscape.png" "$fixture/data/clipboard/$(printf 'a%.0s' {1..64})"
sed 's@"../../src@"src@g' "$repo/tests/launcher/floating-preview.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache" \
    timeout 20 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: separate larger floating previews' "$fixture/log" \
    || rg -q 'FLOATING FAIL:|TypeError:|ReferenceError:|Binding loop|Cannot assign|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
