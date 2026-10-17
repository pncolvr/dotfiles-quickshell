#!/usr/bin/env bash
# Native focus fixtures must run sequentially; no pointer movement or real credentials.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
    printf 'SKIP: panel input check requires a native Wayland session\n'
    exit 0
fi
desktop_runtime=${XDG_RUNTIME_DIR:?}
display=$WAYLAND_DISPLAY
[[ $display == /* ]] || display=$desktop_runtime/$display
fixture=$(mktemp -d /tmp/qspi.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime" "$fixture/home"
ln -s "$desktop_runtime/hypr" "$fixture/runtime/hypr"
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
# Disable unrelated desktop integrations. Both motion modes use the real policy.
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/;s/animationsEnabled: true/animationsEnabled: Quickshell.env("PANEL_INPUT_ANIMATIONS") === "true"/' "$fixture/src/config/Config.qml"
sed 's@"../../src@"src@g;s@"../launcher"@"."@g' "$repo_dir/tests/ui/panel-input.qml" > "$fixture/shell.qml"
cp "$repo_dir/tests/launcher/NativeFocusDriver.qml" "$fixture/NativeFocusDriver.qml"
for animations in false true; do
    QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display" XDG_RUNTIME_DIR="$fixture/runtime" \
        HOME="$fixture/home" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
        PANEL_INPUT_ANIMATIONS="$animations" timeout -k 2 25 qs -p "$fixture" > "$fixture/log" 2>&1 || {
        cat "$fixture/log"; exit 1;
    }
    if ! rg -q 'PASS: native click-to-type' "$fixture/log" \
        || rg -q 'PANEL INPUT FAIL:|FAIL!|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
        cat "$fixture/log"; exit 1
    fi
    printf 'Animations %s: ' "$animations"
    rg 'PASS:' "$fixture/log"
done
