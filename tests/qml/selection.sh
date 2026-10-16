#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-selection.XXXXXXXX)
previous_window=""
previous_cursor=""
cleanup() {
    if [[ -n $previous_window ]]; then hyprctl dispatch focuswindow "address:$previous_window" >/dev/null 2>&1 || true; fi
    if [[ -n $previous_cursor ]]; then hyprctl dispatch movecursor "$previous_cursor" >/dev/null 2>&1 || true; fi
    rm -rf -- "$test_dir"
}
trap cleanup EXIT
mkdir -m700 "$test_dir/runtime"
mkdir -p "$test_dir/data" "$test_dir/cache"
test_platform=offscreen
export SELECTION_TEST_NATIVE=0
if [[ ${1:-} == --native ]]; then
    test_platform=wayland
    export SELECTION_TEST_NATIVE=1
    previous_window=$(hyprctl -j activewindow | jq -r '.address // empty')
    previous_cursor=$(hyprctl -j cursorpos | jq -r '[.x,.y] | join(" ")')
    if [[ ${WAYLAND_DISPLAY:-} != /* ]]; then export WAYLAND_DISPLAY="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"; fi
fi
if [[ $test_platform == wayland ]]; then
cat > "$test_dir/shell.qml" <<QML
import QtQuick
import Quickshell
import Quickshell.Wayland
import "file://$project_root/src/bar"
Scope { PrivateTopPanelTooltip {
    id: host
    requestedVisible: true
    screen: Quickshell.screens[0]
    contentWidth: 520
    contentHeight: 560
    contentX: (width - contentWidth) / 2
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    Loader { width: host.contentWidth; height: host.contentHeight; source: "file://$project_root/tests/qml/selection-smoke.qml" }
} }
QML
else
cat > "$test_dir/shell.qml" <<QML
import QtQuick
import Quickshell
Scope { FloatingWindow {
    visible: true
    implicitWidth: 520
    implicitHeight: 560
    Loader { anchors.fill: parent; source: "file://$project_root/tests/qml/selection-smoke.qml" }
} }
QML
fi
output=$(QT_QPA_PLATFORM="$test_platform" QT_NO_XDG_DESKTOP_PORTAL=1 XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" PIPEWIRE_REMOTE=quickshell-selection-test timeout 15 qs -p "$test_dir/shell.qml" 2>&1) || { printf '%s\n' "$output"; exit 1; }
if [[ $output != *'PASS: selection overlays'* || $output == *'SELECTION FAIL:'* || $output == *'TypeError:'* || $output == *'ReferenceError:'* || $output == *'Binding loop'* || $output == *'Failed to load configuration'* ]]; then
    printf '%s\n' "$output" >&2; exit 1
fi
printf 'PASS: selection overlays preserve layout, private ownership, bounds, focus, disabled options, keyboard and outside-click behavior (%s)\n' "$test_platform"
