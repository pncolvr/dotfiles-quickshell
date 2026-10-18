#!/usr/bin/env bash
# Manual native diagnostic. Requires approval and an idle keyboard/mouse.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
[[ -n ${WAYLAND_DISPLAY:-} && -n ${XDG_RUNTIME_DIR:-} ]] || { printf 'A native Wayland session is required.\n' >&2; exit 2; }
display=$WAYLAND_DISPLAY
[[ $display == /* ]] || display=$XDG_RUNTIME_DIR/$display
fixture=$(mktemp -d /tmp/quickshell-textinput-focus.XXXXXXXX)
original_window=$(hyprctl activewindow -j | jq -r '.address // ""')
cleanup() {
    if [[ $original_window =~ ^0x[0-9a-fA-F]+$ ]]; then
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$original_window\" })" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT
mkdir -m700 "$fixture/runtime" "$fixture/home"
cp -a "$repo/src" "$fixture/src"
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$fixture/src/config/Config.qml"
cp "$repo/tests/launcher/NativeFocusDriver.qml" "$fixture/NativeFocusDriver.qml"
sed -e 's@"../../src@"src@g' -e 's@"../launcher"@"."@g' "$repo/tests/ui/textinput-focus.qml" > "$fixture/shell.qml"
printf 'Diagnostic logs: %s/log\n' "$fixture"
result=0
env -u HYPRLAND_INSTANCE_SIGNATURE dbus-run-session -- env \
    QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display" XDG_RUNTIME_DIR="$fixture/runtime" \
    HOME="$fixture/home" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    QT_LOGGING_RULES='qt.qpa.input.methods.debug=true;qt.qpa.wayland.textinput.debug=true' \
    timeout -k 2 15 qs -p "$fixture/shell.qml" > "$fixture/log" 2>&1 || result=$?
rg 'TEXTINPUT|Trying to (disable|enable)|PASS:|Failed to load configuration|TypeError:|ReferenceError:' "$fixture/log" || true
((result == 0)) && rg -q 'PASS: textinput diagnostic completed' "$fixture/log"
