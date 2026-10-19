#!/usr/bin/env bash
# Native tooltip lifecycle and popup hover, using the compositor pointer.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-selection-hover.XXXXXXXX)
previous_window=$(hyprctl -j activewindow | jq -r '.address // empty')
previous_cursor=$(hyprctl -j cursorpos | jq -r '[.x,.y] | join(" ")')
shell_pid=""
cleanup() {
    if [[ -n $shell_pid ]]; then kill "$shell_pid" 2>/dev/null || true; wait "$shell_pid" 2>/dev/null || true; fi
    if [[ $previous_window =~ ^0x[0-9a-fA-F]+$ ]]; then
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$previous_window\" })" >/dev/null 2>&1 || true
    fi
    read -r previous_x previous_y <<< "$previous_cursor"
    hyprctl dispatch "hl.dsp.cursor.move({ x = $previous_x, y = $previous_y })" >/dev/null 2>&1 || true
    rm -rf -- "$test_dir"
}
trap cleanup EXIT
cat > "$test_dir/shell.qml" <<QML
import QtQuick
import Quickshell
Scope { Loader { source: "file://$project_root/tests/qml/selection-hover.qml" } }
QML
# IPC calls and state waits have their own deadlines. A total lifetime limit
# would also count successful hover checks and can kill a progressing fixture.
QT_QPA_PLATFORM=wayland QT_NO_XDG_DESKTOP_PORTAL=1 XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" PIPEWIRE_REMOTE=selection-hover-test qs -p "$test_dir/shell.qml" > "$test_dir/log" 2>&1 &
shell_pid=$!
ipc() { timeout 2 qs ipc -p "$test_dir/shell.qml" call selectionhover "$@"; }
snapshot() { ipc snapshot; }
last_pointer_target=''
last_pointer_command=''
move_pointer() {
    local target position
    target=$(ipc "$@") || return
    position=$(hyprctl layers -j | jq -er --argjson target "$target" '
        [.[] | .levels[][] | select(.pid == $target.pid and .namespace == $target.namespace)]
        | if length != 1 then error("expected one fixture layer") else .[0] end
        | "hl.dsp.cursor.move({ x = \((.x + $target.x) | round), y = \((.y + $target.y) | round) })"
    ') || return
    last_pointer_target=$target
    last_pointer_command=$position
    hyprctl dispatch "$position" >/dev/null
    ipc syncPointer "$target" >/dev/null
}
fail() {
    snapshot >&2 2>/dev/null || true
    printf 'Last pointer target: %s\nLast pointer command: %s\n' "$last_pointer_target" "$last_pointer_command" >&2
    hyprctl cursorpos -j >&2 2>/dev/null || true
    ipc geometry >&2 2>/dev/null || true
    printf 'FAIL: %s\n' "$*" >&2
    if ! kill -0 "$shell_pid" 2>/dev/null; then
        local shell_status=0
        wait "$shell_pid" || shell_status=$?
        printf 'Fixture exited with status %s; complete fixture log follows:\n' "$shell_status" >&2
        cat "$test_dir/log" >&2
    else
        rg 'TypeError|ReferenceError|Failed to load|WARN scene' "$test_dir/log" >&2 || true
    fi
    exit 1
}
wait_state() {
    local query=$1 state deadline=$((SECONDS + 8))
    while ((SECONDS < deadline)); do
        kill -0 "$shell_pid" 2>/dev/null || fail "fixture exited while waiting for: $query"
        if state=$(snapshot 2>/dev/null) && jq -e "$query" <<< "$state" >/dev/null; then return 0; fi
        sleep 0.025
    done
    fail "state did not match: $query"
}
wait_state '.writes==0'
for mode in volume mic profile folder type private-folder; do
    for above in true false; do
        ipc begin "$mode" "$above" >/dev/null
        wait_state '.visible and .toggleReady and .settled'
        move_pointer hoverToggle
        wait_state '.toggleHovered'
        ipc open >/dev/null
        wait_state ".expanded and .popupOpened and .opensAbove==$above and .rowsReady"
        ipc leaveTrigger >/dev/null
        for index in 0 1 2; do
            move_pointer hover "$index"
            wait_state ".hovered and .rowHover[$index]"
            sleep 0.45
            snapshot | jq -e ".visible and .expanded and .popupVisible and .hovered and .rowHover[$index] and .sameOverlay and (.pinned|not) and (.paused|not) and .writes==0 and ((.private|not) or .namespace==\"quickshell-private\")" >/dev/null \
                || fail "$mode dropdown or panel disappeared while hovering option $index (opensAbove=$above)"
        done
        move_pointer leave
        wait_state '(.visible|not) and (.expanded|not)'
    done
    printf 'PASS: %s popup rows preserve unpinned panel hover above and below, then dismiss after leaving\n' "$mode"
done
for mode in folder private-folder; do
    for lower in false true; do
        ipc begin "$mode" false >/dev/null
        wait_state '.visible and .toggleReady and .settled'
        move_pointer hoverAction "$lower" true
        ipc leaveTrigger >/dev/null
        wait_state '.cursorHovered and .cursorHintReady and .cursorHintOpened'
        sleep 1
        snapshot | jq -e '.visible and .hovered and .cursorHovered and .cursorHintOpened and .cursorLeaves==0' >/dev/null \
            || fail "$mode button loses stationary hover when its hint appears (lower=$lower)"
        for ((movement=0;movement<8;movement++)); do
            move_pointer hoverAction "$lower" false
            sleep 0.05
        done
        snapshot | jq -e '.visible and .hovered and .cursorHovered and .cursorHintOpened and .cursorLeaves==0' >/dev/null \
            || fail "$mode button loses moving hover when its hint appears (lower=$lower)"
        move_pointer leave
        wait_state '(.visible|not)'
    done
    printf 'PASS: %s upper/lower button hints preserve stationary and moving hover without cursor churn\n' "$mode"
done
if rg -q 'TypeError|ReferenceError|Binding loop|WARN scene' "$test_dir/log"; then fail 'runtime diagnostics'; fi
