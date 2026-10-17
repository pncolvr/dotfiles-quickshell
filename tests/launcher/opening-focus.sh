#!/usr/bin/env bash
# Native fixture: requires an idle keyboard, never moves the pointer.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
    printf 'SKIP: launcher opening check requires native Wayland\n'
    exit 0
fi
desktop_runtime=${XDG_RUNTIME_DIR:?}
display=$WAYLAND_DISPLAY
[[ $display == /* ]] || display=$desktop_runtime/$display
fixture=$(mktemp -d /tmp/qso.XXXXXX)
original_window=$(hyprctl activewindow -j | jq -r '.address // ""')
cleanup() {
    rm -rf -- "$fixture"
    if [[ $original_window =~ ^0x[0-9a-fA-F]+$ ]]; then
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$original_window\" })" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT
mkdir -m700 "$fixture/r" "$fixture/home"
ln -s "$desktop_runtime/hypr" "$fixture/r/hypr"
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/;s/animationsEnabled: true/animationsEnabled: Quickshell.env("OPENING_ANIMATIONS") === "true"/' "$fixture/src/config/Config.qml"
# Keep time to inspect the opening phase independent of the user's chosen duration.
sed -Ei 's/(readonly property int panelOpenDuration:) [0-9]+/\1 500/;s/(readonly property int exposeAnimationDuration:) [0-9]+/\1 500/' "$fixture/src/theme/Theme.qml"
cat > "$fixture/src/services/hyprland/WindowService.qml" <<'QML'
pragma Singleton
import Quickshell
Singleton {
    property var allWindows: []
    function buildWindows() {}
    function focusWindow(_address) {}
    function getDisplayTitle(_workspace, title, _className) { return title }
    function moveWindowToWorkspace(_address, _workspace) { return false }
}
QML
sed 's@"../../src@"src@g' "$repo_dir/tests/launcher/opening-focus.qml" > "$fixture/shell.qml"
cp "$repo_dir/tests/launcher/NativeFocusDriver.qml" "$fixture/NativeFocusDriver.qml"
for animations in false true; do
    # Each mode starts with a fresh synthetic database.
    rm -rf -- "$fixture/data"
    HOME="$fixture/home" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
        QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display" XDG_RUNTIME_DIR="$fixture/r" OPENING_ANIMATIONS="$animations" \
        timeout -k 2 15 qs -p "$fixture/shell.qml" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
    if ! rg -q 'PASS: native launcher first-map focus' "$fixture/log" \
        || rg -q 'OPENING NATIVE FAIL:|FAIL!|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
        cat "$fixture/log"; exit 1
    fi
    printf 'Animations %s: ' "$animations"
    rg 'PASS:|OPENING NATIVE.*focus-ms' "$fixture/log"
done
