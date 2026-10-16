#!/usr/bin/env bash
# Synthetic GPU surface only; no keyboard focus, pointer movement or desktop capture.
set -euo pipefail
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
    printf 'SKIP: panel shadow pixel check requires Wayland\n'
    exit 0
fi
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-panel-shadow.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
display=$WAYLAND_DISPLAY
[[ $display == /* ]] || display=${XDG_RUNTIME_DIR:?}/$display
mkdir -m700 "$fixture/runtime"
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/readonly property bool screencastActive:.*/property bool screencastActive: false/' "$fixture/src/services/audio/AudioService.qml"
# Leave time for GPU capture on busy desktops; production timing is tested separately.
sed -i 's/panelOpenDuration: 150/panelOpenDuration: 300/; s/panelCloseDuration: 100/panelCloseDuration: 300/' "$fixture/src/theme/Theme.qml"
# Exercise animation independently of the user's current master switch.
sed -i 's/readonly property bool animationsEnabled:.*/readonly property bool animationsEnabled: true/;s/readonly property bool animateDuringScreenShare:.*/readonly property bool animateDuringScreenShare: false/' "$fixture/src/config/Config.qml"
sed 's@"../../src@"src@g' "$repo_dir/tests/ui/panel-shadow.qml" > "$fixture/shell.qml"
if [[ -n ${PANEL_SHADOW_FRAMES:-} ]]; then mkdir -p -- "$PANEL_SHADOW_FRAMES"; fi
env -u QT_QUICK_BACKEND QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display" \
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout 10 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: GPU bar shadow' "$fixture/log" \
    || rg -q 'SHADOW GPU FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration|Failed to compile shader|Failed to build graphics pipeline' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
