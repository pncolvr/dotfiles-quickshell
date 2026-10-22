#!/usr/bin/env bash
# Private offscreen pointer events; no live desktop, clipboard or focus changes.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-scrollbar-test.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/home"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/readonly property bool animationsEnabled:.*/property bool animationsEnabled: true/;s/readonly property bool animateDuringScreenShare:.*/property bool animateDuringScreenShare: false/;s/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/' "$fixture/src/config/Config.qml"
cat > "$fixture/src/services/audio/AudioService.qml" <<'QML'
pragma Singleton
import QtQml
QtObject { property bool screencastActive: false }
QML
cat > "$fixture/src/services/launcher/PickerService.qml" <<'QML'
pragma Singleton
import QtQml
QtObject {
    enum Mode { None, Menu, Projects, Directories, Apps, Windows, Clipboard, Secret, Webapps, Remotes, N8n }
}
QML
cp "$repo/tests/launcher/NativeFocusDriver.qml" "$fixture/"
sed 's@"../../src@"src@g;s@"../launcher"@"."@g' "$repo/tests/ui/scrollbar.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u DISPLAY \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 \
    HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 2 15 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
cat "$fixture/log"
rg -q 'PASS: shared scrollbar' "$fixture/log"
! rg -q 'SCROLLBAR FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration|Unable to assign' "$fixture/log"
