#!/usr/bin/env bash
# Synthetic clients, private data and offscreen input; no desktop focus or capture.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-window-switcher.XXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/home" "$fixture/bin"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/' "$fixture/src/config/Config.qml"
printf 'exit 0\n' > "$fixture/src/services/launcher/providers/wallpaper.sh"
cat > "$fixture/src/services/audio/AudioService.qml" <<'QML'
pragma Singleton
import QtQml
QtObject { property bool screencastActive: false }
QML
printf '#!/usr/bin/env bash\nexit 1\n' > "$fixture/bin/tool"
chmod +x "$fixture/bin/tool"
for tool in hyprctl busctl gdbus; do ln -s tool "$fixture/bin/$tool"; done
cat > "$fixture/src/services/hyprland/WindowService.qml" <<'QML'
pragma Singleton
import Quickshell
Singleton {
    property var allWindows: []
    property var focused: []
    function buildWindows() {}
    function focusWindow(address) { focused = focused.concat([address]) }
    function getDisplayTitle(_workspace, title, _className) { return title }
}
QML
sed 's@"../../src@"src@g' "$repo/tests/launcher/window-switcher.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    HOME="$fixture/home" PATH="$fixture/bin:$PATH" XDG_RUNTIME_DIR="$fixture/runtime" \
    XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 2 15 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: window switcher' "$fixture/log" || rg -q 'SWITCHER FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
rg 'PASS:' "$fixture/log"
