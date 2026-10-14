#!/usr/bin/env bash
set -euo pipefail
root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-clipboard-ui.XXXXXXXX)
original_focus=''
cleanup() {
    rm -rf -- "$fixture"
    if [[ $original_focus =~ ^0x[0-9a-fA-F]+$ ]]; then
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$original_focus\" })" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT
if [[ ${CLIPBOARD_NATIVE:-0} == 1 ]]; then original_focus=$(hyprctl activewindow -j | jq -r '.address // ""'); fi
mkdir -m700 "$fixture/runtime"
mkdir -p "$fixture/data/clipboard"
tar -C "$root_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$fixture/src/config/Config.qml"
sed -i 's@readonly property var clipboardCommand:.*@readonly property var clipboardCommand: ["true"]@' "$fixture/src/config/Config.qml"
sed -i 's@readonly property var hyprlandHideApplicationsCommand:.*@readonly property var hyprlandHideApplicationsCommand: (active) => ["true"]@' "$fixture/src/config/Config.qml"
sed -i 's@readonly property var screencastSoundCommand:.*@readonly property var screencastSoundCommand: sound => ["true"]@' "$fixture/src/config/Config.qml"
# Simulate policy changes without starting a real capture or changing PipeWire.
sed -i 's/readonly property bool screencastActive:.*/property bool screencastActive: false/' "$fixture/src/services/audio/AudioService.qml"
if [[ ${CLIPBOARD_ZERO_MOTION:-0} == 1 ]]; then
    sed -i 's/readonly property int clipboardLayoutDuration:.*/readonly property int clipboardLayoutDuration: 0/' "$fixture/src/theme/Theme.qml"
fi
sed 's@"../../../src@"src@g' "$root_dir/tests/clipboard/fts/ui.qml" > "$fixture/shell.qml"
sed 's@"../../../src@"src@g' "$root_dir/tests/clipboard/fts/native-host.qml" > "$fixture/native-host.qml"
magick -size 1920x1080 pattern:checkerboard "$fixture/image.png"
for number in 1 2 3 4; do printf -v id '%064x' "$number"; cp -- "$fixture/image.png" "$fixture/data/clipboard/$id"; done
platform=offscreen
display=${WAYLAND_DISPLAY:-}
[[ -z $display || $display == /* ]] || display=${XDG_RUNTIME_DIR:?}/$display
[[ ${CLIPBOARD_NATIVE:-0} != 1 ]] || platform=wayland
XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache" \
    QT_QPA_PLATFORM="$platform" WAYLAND_DISPLAY="$display" timeout 30 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
cat "$fixture/log"
rg -q 'PASS: indexed/fuzzy search' "$fixture/log"
! rg -q 'CLIPBOARD FAIL:|TypeError:|ReferenceError:|Binding loop|Cannot assign|Failed to load configuration' "$fixture/log"
