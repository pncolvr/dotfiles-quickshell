#!/usr/bin/env bash
# Native tooltip lifecycle and popup hover, using deterministic Qt mouse events.
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
QT_QPA_PLATFORM=wayland QT_NO_XDG_DESKTOP_PORTAL=1 XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" PIPEWIRE_REMOTE=selection-hover-test timeout 50 qs -p "$test_dir/shell.qml" > "$test_dir/log" 2>&1 &
shell_pid=$!
ipc() { timeout 2 qs ipc -p "$test_dir/shell.qml" call selectionhover "$@"; }
snapshot() { ipc snapshot; }
fail() {
    snapshot >&2 2>/dev/null || true
    printf 'FAIL: %s\n' "$*" >&2
    rg 'TypeError|ReferenceError|Failed to load|WARN scene' "$test_dir/log" >&2 || true
    exit 1
}
wait_state() {
    local query=$1 state
    for ((attempt=0;attempt<80;attempt++)); do
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
        ipc hoverToggle >/dev/null
        ipc open >/dev/null
        wait_state ".expanded and .popupOpened and .opensAbove==$above and .rowsReady"
        ipc leaveTrigger >/dev/null
        for index in 0 1 2; do
            ipc hover "$index" >/dev/null
            sleep 0.45
            snapshot | jq -e ".visible and .expanded and .popupVisible and .hovered and .rowHover[$index] and .sameOverlay and (.pinned|not) and (.paused|not) and .writes==0 and ((.private|not) or .namespace==\"quickshell-private\")" >/dev/null \
                || fail "$mode dropdown or panel disappeared while hovering option $index (opensAbove=$above)"
        done
        ipc leave >/dev/null
        wait_state '(.visible|not) and (.expanded|not)'
    done
    printf 'PASS: %s popup rows preserve unpinned panel hover above and below, then dismiss after leaving\n' "$mode"
done
for mode in folder private-folder; do
    for lower in false true; do
        ipc begin "$mode" false >/dev/null
        wait_state '.visible and .toggleReady and .settled'
        ipc hoverAction "$lower" true >/dev/null
        ipc leaveTrigger >/dev/null
        wait_state '.cursorHovered and .cursorHintReady and .cursorHintOpened'
        sleep 1
        snapshot | jq -e '.visible and .hovered and .cursorHovered and .cursorHintOpened and .cursorLeaves==0' >/dev/null \
            || fail "$mode button loses stationary hover when its hint appears (lower=$lower)"
        for ((movement=0;movement<8;movement++)); do
            ipc hoverAction "$lower" false >/dev/null
            sleep 0.05
        done
        snapshot | jq -e '.visible and .hovered and .cursorHovered and .cursorHintOpened and .cursorLeaves==0' >/dev/null \
            || fail "$mode button loses moving hover when its hint appears (lower=$lower)"
        ipc leave >/dev/null
        wait_state '(.visible|not)'
    done
    printf 'PASS: %s upper/lower button hints preserve stationary and moving hover without cursor churn\n' "$mode"
done
if rg -q 'TypeError|ReferenceError|Binding loop|WARN scene' "$test_dir/log"; then fail 'runtime diagnostics'; fi
