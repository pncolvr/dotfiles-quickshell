#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-expose-test.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -m 700 "$test_dir/runtime"
mkdir "$test_dir/data" "$test_dir/cache"
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$test_dir" -xf -
sed -i 's/readonly property bool clipboardMonitorEnabled: true/readonly property bool clipboardMonitorEnabled: false/' "$test_dir/src/config/Config.qml"
# Keep fixture timing predictable while the user experiments with animation duration.
sed -Ei 's/readonly property int exposeAnimationDuration: [0-9]+/readonly property int exposeAnimationDuration: 300/' "$test_dir/src/theme/Theme.qml"
sed 's@"../../src@"src@g' "$project_root/tests/launcher/expose-smoke.qml" > "$test_dir/shell.qml"
output=$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$test_dir/runtime" \
    XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" timeout -k 2 10 qs -p "$test_dir" 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
while IFS= read -r line; do [[ $line != *'PASS:'* ]] || printf '%s\n' "$line"; done <<< "$output"
[[ $output == *'PASS:'* && $output != *'EXPOSE FAIL:'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* \
    && $output != *'Binding loop'* && $output != *'Failed to load configuration'* ]] || { printf '%s\n' "$output" >&2; exit 1; }
sed 's@"../../src@"src@g' "$project_root/tests/launcher/expose-interaction-smoke.qml" > "$test_dir/shell.qml"
output=$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$test_dir/runtime" \
    XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" timeout -k 2 10 qs -p "$test_dir" 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
while IFS= read -r line; do [[ $line != *'PASS:'* ]] || printf '%s\n' "$line"; done <<< "$output"
[[ $output == *'PASS:'* && $output != *'EXPOSE FAIL:'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* \
    && $output != *'Binding loop'* && $output != *'Failed to load configuration'* ]] || { printf '%s\n' "$output" >&2; exit 1; }
if [[ -n ${WAYLAND_DISPLAY:-} ]]; then
    display=$WAYLAND_DISPLAY
    [[ $display = /* ]] || display="${XDG_RUNTIME_DIR:-/run/user/$UID}/$display"
    sed 's@"../../src@"src@g' "$project_root/tests/launcher/expose-animation-smoke.qml" > "$test_dir/shell.qml"
    output=$(QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display" XDG_RUNTIME_DIR="$test_dir/runtime" \
        XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" timeout -k 2 10 qs -p "$test_dir" 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
    while IFS= read -r line; do [[ $line != *'PASS:'* ]] || printf '%s\n' "$line"; done <<< "$output"
    [[ $output == *'PASS:'* && $output != *'EXPOSE FAIL:'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* \
        && $output != *'Binding loop'* && $output != *'Failed to load configuration'* ]] || { printf '%s\n' "$output" >&2; exit 1; }
else
    printf 'SKIP: Exposé animation surface check requires Wayland\n'
fi

# Exercise the real picker synchronization without dispatching compositor commands.
cat > "$test_dir/src/services/hyprland/WindowService.qml" <<'MOCK'
pragma Singleton
import Quickshell
Singleton {
    property var allWindows: []
    function buildWindows() {}
    function focusWindow(_address) {}
    function moveWindowToWorkspace(address, workspace) {
        const client = allWindows.find(window => window.address === address)
        return !!client && client.workspace.id !== workspace
    }
}
MOCK
sed 's@"../../src@"src@g' "$project_root/tests/launcher/expose-move-smoke.qml" > "$test_dir/shell.qml"
output=$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$test_dir/runtime" \
    XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" timeout -k 2 10 qs -p "$test_dir" 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
while IFS= read -r line; do [[ $line != *'PASS:'* ]] || printf '%s\n' "$line"; done <<< "$output"
[[ $output == *'PASS:'* && $output != *'EXPOSE FAIL:'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* \
    && $output != *'Binding loop'* && $output != *'Failed to load configuration'* ]] || { printf '%s\n' "$output" >&2; exit 1; }
