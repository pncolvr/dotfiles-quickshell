#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-media-fullscreen.XXXXXXXX)
previous_window=$(hyprctl -j activewindow | jq -r '.address // empty')
previous_pointer=$(hyprctl -j cursorpos | jq -r '[.x,.y] | join(" ")')
cleanup() {
    if [[ -n $previous_window ]]; then hyprctl dispatch focuswindow "address:$previous_window" >/dev/null 2>&1 || true; fi
    if [[ -n $previous_pointer ]]; then hyprctl dispatch movecursor "$previous_pointer" >/dev/null 2>&1 || true; fi
    rm -rf -- "$test_dir"
}
trap cleanup EXIT
mkdir -m700 "$test_dir/runtime"
mkdir -p "$test_dir/data" "$test_dir/cache"
export XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache"
cat > "$test_dir/art.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="520" height="520"><defs><linearGradient id="g" x2="1" y2="1"><stop stop-color="#287ea8"/><stop offset="1" stop-color="#cb7340"/></linearGradient></defs><rect width="520" height="520" fill="url(#g)"/><circle cx="260" cy="260" r="150" fill="#152730"/><circle cx="260" cy="260" r="46" fill="#73a3c1"/></svg>
SVG
if [[ ${MEDIA_FULLSCREEN_RING_FIXTURE:-0} == 1 ]]; then
cat > "$test_dir/art.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="2048" height="2048"><rect width="2048" height="2048" fill="#8020c0"/><circle cx="1024" cy="1024" r="924" fill="#dd5060" stroke="#00ff00" stroke-width="56"/><rect x="900" y="840" width="248" height="160" fill="black"/></svg>
SVG
fi
export MEDIA_FULLSCREEN_ART="$test_dir/art.svg"
if [[ ${WAYLAND_DISPLAY:-} != /* ]]; then export WAYLAND_DISPLAY="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"; fi
cat > "$test_dir/shell.qml" <<QML
import QtQuick
import Quickshell
Scope { Loader { source: "file://$project_root/tests/audio/media-fullscreen-smoke.qml" } }
QML
output=$(QT_QPA_PLATFORM=wayland QT_NO_XDG_DESKTOP_PORTAL=1 XDG_RUNTIME_DIR="$test_dir/runtime" timeout 25 qs -p "$test_dir/shell.qml" 2>&1) || {
    printf '%s\n' "$output"; exit 1;
}
printf '%s\n' "$output"
[[ $output == *'PASS: fullscreen'* && $output != *'FULLSCREEN FAIL:'* && $output != *'TypeError:'*
    && $output != *'ReferenceError:'* && $output != *'Binding loop'* && $output != *'Error: Too many arguments'*
    && $output != *'Error: Insufficient arguments'* && $output != *'Failed to create graphics pipeline'* ]]
