#!/usr/bin/env bash
# Synthetic rows, inputs and pointer events in an isolated offscreen window.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-rows.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/' "$fixture/src/config/Config.qml"
sed -i 's/readonly property int textRenderType:/property int textRenderType:/;s/readonly property int fontHintingPreference:/property int fontHintingPreference:/' "$fixture/src/theme/Theme.qml"
cat > "$fixture/src/services/audio/AudioService.qml" <<'QML'
pragma Singleton
import QtQml
QtObject { property bool screencastActive: false }
QML
sed 's@"../../src@"src@g' "$repo/tests/ui/rows.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout 12 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: shared row cursors' "$fixture/log" \
    || rg -q 'ROW FAIL:|TypeError:|ReferenceError:|Binding loop|Cannot assign|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
