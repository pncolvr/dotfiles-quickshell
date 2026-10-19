#!/usr/bin/env bash
# Production bar and window service with synthetic compositor clients only.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-bar-windows.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/home"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i '\|^import Quickshell.Hyprland$|d' "$fixture/src/services/hyprland/WindowService.qml"
# Expose the synthetic backend to the fixture without changing production API.
sed -i '/id: root/a\    readonly property var compositor: Hyprland' "$fixture/src/services/hyprland/WindowService.qml"
cat > "$fixture/src/services/hyprland/Hyprland.qml" <<'QML'
pragma Singleton
import QtQml
QtObject {
    property var focusedWorkspace: ({id: 4})
    property var dispatched: []
    property QtObject toplevels: QtObject {
        signal objectInsertedPost()
        signal objectRemovedPost()
    }
    function refreshToplevels() {}
    function dispatch(command) { dispatched = dispatched.concat([command]) }
}
QML
printf 'singleton Hyprland 1.0 Hyprland.qml\n' >> "$fixture/src/services/hyprland/qmldir"
sed -i \
    -e 's@readonly property var hyprlandGetWindowsCommand:.*@property var hyprlandGetWindowsCommand: ["printf", "%s", "[]"]@' \
    -e 's@readonly property var hyprlandGetActiveWindowHiddenCommand:.*@readonly property var hyprlandGetActiveWindowHiddenCommand: ["printf", "false"]@' \
    -e 's@readonly property var hyprlandGetNoWarpsCommand:.*@readonly property var hyprlandGetNoWarpsCommand: ["printf", "false"]@' \
    -e 's@readonly property var hyprlandSetNoWarpsCommand:.*@readonly property var hyprlandSetNoWarpsCommand: value => ["true"]@' \
    "$fixture/src/config/Config.qml"
cp "$repo/tests/launcher/NativeFocusDriver.qml" "$fixture/"
sed 's@"../../src@"src@g;s@"../launcher"@"."@g' "$repo/tests/hyprland/windows.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 \
    HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/runtime" \
    XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 2 15 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: grouped window tabs' "$fixture/log" \
    || rg -q 'WINDOWS FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration|WARN scene' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
