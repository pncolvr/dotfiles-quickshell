#!/usr/bin/env bash
# Native pointer and clicks against synthetic compact panels only.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
command -v ydotool >/dev/null
runtime=${XDG_RUNTIME_DIR:?}
display=${WAYLAND_DISPLAY:?}
[[ $display == /* ]] || display=$runtime/$display
fixture=$(mktemp -d /tmp/qsd.XXXXXXXX)
original_window=$(hyprctl activewindow -j | jq -r '.address // empty')
original_cursor=$(hyprctl cursorpos -j | jq -r '[.x,.y]|join(" ")')
pid=''
cleanup() {
    [[ -z $pid ]] || { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }
    if [[ $original_window =~ ^0x[0-9a-fA-F]+$ ]]; then
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$original_window\" })" >/dev/null 2>&1 || true
    fi
    read -r x y <<< "$original_cursor"
    hyprctl dispatch "hl.dsp.cursor.move({ x = $x, y = $y })" >/dev/null 2>&1 || true
    printf 'Dropdown native logs: %s\n' "$fixture"
}
trap cleanup EXIT
mkdir -m700 "$fixture/r" "$fixture/home"
ln -s "$runtime/hypr" "$fixture/r/hypr"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/;s/adaptiveBarEnabled: true/adaptiveBarEnabled: false/' "$fixture/src/config/Config.qml"
cat > "$fixture/src/services/audio/AudioService.qml" <<'QML'
pragma Singleton
import QtQml
QtObject { property bool screencastActive: false }
QML
sed 's@"../../src@"src@g' "$repo/tests/ui/tooltip-dropdown-native.qml" > "$fixture/shell.qml"
export YDOTOOL_SOCKET=${YDOTOOL_SOCKET:-$runtime/.ydotool_socket}
[[ -S $YDOTOOL_SOCKET ]] || { printf 'ydotool socket is required: %s\n' "$YDOTOOL_SOCKET" >&2; exit 1; }
env QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display" QS_DISABLE_CRASH_HANDLER=1 \
    QT_NO_XDG_DESKTOP_PORTAL=1 HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/r" \
    XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    qs -p "$fixture" > "$fixture/log" 2>&1 & pid=$!
ipc() { XDG_RUNTIME_DIR="$fixture/r" WAYLAND_DISPLAY="$display" timeout 2 qs ipc -p "$fixture" call dropdowncheck "$@"; }
fail() { ipc snapshot >&2 2>/dev/null || true; cat "$fixture/log" >&2; printf 'FAIL: %s\n' "$*" >&2; exit 1; }
wait_state() {
    local deadline=$((SECONDS + 6)) state
    while ((SECONDS < deadline)); do
        kill -0 "$pid" 2>/dev/null || fail 'fixture exited'
        if state=$(ipc snapshot 2>/dev/null) && jq -e "$1" <<< "$state" >/dev/null; then return; fi
        sleep 0.025
    done
    fail "state did not match: $1"
}
move_pointer() {
    local target position
    target=$(ipc pointer "$1")
    position=$(hyprctl layers -j | jq -er --argjson target "$target" '
        [.[] | .levels[][] | select(.pid==$target.pid and .namespace==$target.namespace)]
        | if length != 1 then error("expected one fixture layer") else .[0] end
        | "hl.dsp.cursor.move({ x = \((.x+$target.x)|round), y = \((.y+$target.y)|round) })"')
    hyprctl dispatch "$position" >/dev/null
    # Send real input after the compositor warp; no QtTest mouse injection.
    ydotool mousemove 1 0
    ydotool mousemove -- -1 0
}
# The IPC endpoint exists before a panel is requested.
ready=false
for ((attempt=0; attempt<100; attempt++)); do
    if ipc snapshot >/dev/null 2>&1; then ready=true; break; fi
    kill -0 "$pid" 2>/dev/null || fail 'fixture failed to start'
    sleep 0.025
done
[[ $ready == true ]] || fail 'IPC did not become ready'
expected=0
for mode in compact searchable mic private; do
    ipc begin "$mode" >/dev/null
    wait_state '.visible and .ready and .settled and .panelHeight < 200'
    move_pointer toggle
    wait_state '.toggleHovered'
    ydotool click 0xC0
    wait_state '.opened and .rowOutside and .regions==1'
    move_pointer option
    wait_state '.rowHovered and .popupHovered'
    ipc leaveTrigger >/dev/null
    sleep 0.35
    wait_state '.visible and .opened and .rowHovered'
    ydotool click 0xC0
    expected=$((expected+1))
    wait_state ".commits==$expected and .chosen==\"second\" and (.expanded|not) and .regions==0"
    if [[ $mode == private ]]; then
        ipc snapshot | jq -e '.namespace=="quickshell-private"' >/dev/null || fail 'private ownership changed'
    fi
    ipc dismiss >/dev/null
    wait_state '(.visible|not)'
    printf 'PASS: %s dropdown receives native hover and clicks beyond its naturally sized panel\n' "$mode"
done
! rg -q 'TypeError:|ReferenceError:|Binding loop|Failed to load configuration|WARN scene' "$fixture/log" || fail 'runtime diagnostics'
