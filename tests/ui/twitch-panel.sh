#!/usr/bin/env bash
# Briefly open an isolated Twitch panel on Wayland, then restore focus and pointer.
set -euo pipefail

project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-twitch-panel.XXXXXXXX)
entry="$test_dir/shell.qml"
shell_pid=""
original_window=""
original_x=""
original_y=""

ipc() { timeout 3 qs ipc -p "$entry" call "$@"; }
snapshot() { ipc twitchpaneltest snapshot; }

cleanup() {
    local result=$?
    trap - EXIT
    if ((result != 0)); then
        snapshot >&2 2>/dev/null || true
        ipc twitchpaneltest snapshotVolume >&2 2>/dev/null || true
        hyprctl cursorpos -j >&2 2>/dev/null || true
        if [[ -f $test_dir/quickshell.log ]]; then cat "$test_dir/quickshell.log" >&2; fi
    fi
    if [[ -n $shell_pid ]]; then
        kill -TERM -- "-$shell_pid" 2>/dev/null || true
        wait "$shell_pid" 2>/dev/null || true
    fi
    if [[ $original_window =~ ^0x[0-9a-fA-F]+$ ]]; then
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$original_window\" })" >/dev/null 2>&1 || true
    fi
    if [[ -n $original_x && -n $original_y ]]; then
        hyprctl dispatch "hl.dsp.cursor.move({ x = $original_x, y = $original_y })" >/dev/null 2>&1 || true
    fi
    rm -rf -- "$test_dir"
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

original_window=$(hyprctl activewindow -j | jq -r '.address // ""')
original_cursor=$(hyprctl cursorpos -j)
original_x=$(jq -er '.x | numbers | floor' <<< "$original_cursor")
original_y=$(jq -er '.y | numbers | floor' <<< "$original_cursor")

mkdir "$test_dir/bin"
printf '#!/bin/sh\nexit 0\n' > "$test_dir/bin/twitch"
chmod 700 "$test_dir/bin/twitch"
# Keep the TOTP fixture away from the real keyring and suppress capture sounds.
printf '#!/bin/sh\nexit 1\n' > "$test_dir/bin/secret-tool"
printf '#!/bin/sh\nexit 0\n' > "$test_dir/bin/canberra-gtk-play"
chmod 700 "$test_dir/bin/secret-tool" "$test_dir/bin/canberra-gtk-play"
fixture_url=$(printf 'file://%s/tests/ui/twitch-panel-smoke.qml' "$project_root" | jq -Rs .)
cat > "$entry" <<QML
import QtQuick
import Quickshell
Scope { Loader { source: $fixture_url } }
QML
export QT_QPA_PLATFORM=wayland QT_NO_XDG_DESKTOP_PORTAL=1
export XDG_CACHE_HOME="$test_dir/cache" XDG_DATA_HOME="$test_dir/data"
export PATH="$test_dir/bin:$PATH"
setsid timeout --kill-after=2 30 qs -p "$entry" > "$test_dir/quickshell.log" 2>&1 &
shell_pid=$!

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
state_matches() {
    local state
    state=$(snapshot 2>/dev/null) || return 1
    jq -e "$1" <<< "$state" >/dev/null
}
check_state() { state_matches "$1" || fail "$2"; }
wait_for() {
    local message=$1 deadline=$((SECONDS + 5))
    shift
    until "$@"; do
        kill -0 "$shell_pid" 2>/dev/null || fail "Quickshell exited: $message"
        ((SECONDS < deadline)) || fail "$message"
        sleep 0.03
    done
}
pointer_on_icon() {
    local state cursor
    state=$(snapshot) || return 1
    cursor=$(hyprctl cursorpos -j) || return 1
    jq -e --argjson cursor "$cursor" '
        .pointerTarget != null and (.pointerTarget | with_entries(.value |= ((. + 0.5) | floor))) == $cursor
    ' <<< "$state" >/dev/null
}

wait_for 'test IPC ready' state_matches '.visible == false'
ipc bar open twitch >/dev/null
wait_for 'IPC opens panel and focuses search' state_matches '.visible and .focused and .windowActive'
wait_for 'keyboard focus returns to on demand after activation' state_matches '.onDemand and (.requestingFocus | not)'
check_state '(.pinned | not) and .keyboard and .source and .screen' 'panel opens without pinning on the target screen with keyboard focus'
wait_for 'pointer moves to the center of the Twitch icon' pointer_on_icon
ipc twitchpaneltest type alice
check_state '.text == "alice"' 'typing goes into search'
ipc twitchpaneltest beginAdd
check_state '.adding' 'add editor opens'
ipc bar open twitch >/dev/null
wait_for 'repeated IPC cancels add and refocuses search' state_matches '.focused and (.adding | not)'
check_state '.visible and (.pinned | not) and .text == "alice"' 'reopening keeps query without pinning'
[[ $(ipc twitchpaneltest clickIcon) == true ]] || fail 'bar icon mouse click delivered'
check_state '.visible and .pinned and (.keyboard | not)' 'bar icon manually pins the keyboard-opened panel'
ipc bar open twitch >/dev/null
wait_for 'IPC refocuses a manually pinned panel' state_matches '.focused and .pinned and .keyboard and .onDemand'
if [[ $original_window =~ ^0x[0-9a-fA-F]+$ ]]; then
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$original_window\" })" >/dev/null
    wait_for 'another window can focus while Twitch stays pinned' state_matches '.visible and .pinned and (.windowActive | not)'
    ipc bar open twitch >/dev/null
    wait_for 'IPC refocuses the pinned panel after another window' state_matches '.windowActive and .focused and .onDemand'
fi
[[ $(ipc twitchpaneltest pressEscape) == true ]] || fail 'Escape key delivered'
wait_for 'Escape dismisses keyboard panel' state_matches '.visible == false'
check_state '(.pinned | not) and (.keyboard | not)' 'Escape releases pinning and keyboard focus'
ipc bar open twitch >/dev/null
wait_for 'closed panel reopens' state_matches '.focused'
check_state '.text == "" and (.pinned | not)' 'closing resets search and reopening does not pin'
[[ $(ipc twitchpaneltest clickIcon) == true ]] || fail 'bar icon mouse click delivered'
check_state '.visible and .pinned and (.keyboard | not)' 'first bar click manually pins the panel'
[[ $(ipc twitchpaneltest clickIcon) == true ]] || fail 'bar icon mouse click delivered'
check_state '.visible and (.pinned | not) and (.keyboard | not)' 'icon unpins and releases keyboard'
ipc twitchpaneltest dismiss
[[ $(ipc twitchpaneltest clickIcon) == true ]] || fail 'bar icon mouse click delivered'
check_state '.visible and .pinned and (.keyboard | not)' 'normal icon pinning stays on demand'
[[ $(ipc bar open hidden) == false ]] || fail 'hidden module should be skipped'
[[ $(ipc bar open unknown) == false ]] || fail 'unknown module should be skipped'
[[ $(ipc bar open twitch) == true ]] || fail 'registered Twitch module opens'
wait_for 'bar IPC preserves Twitch search behavior' state_matches '.focused and .keyboard'
[[ $(ipc bar open totp) == true ]] || fail 'registered TOTP module opens'
totp_matches() { ipc twitchpaneltest snapshotTotp | jq -e "$1" >/dev/null; }
wait_for 'TOTP search gets native keyboard focus' totp_matches '.visible and .focused and .windowActive and .onDemand and .source and .screen and (.pinned | not)'
pointer_on_totp() {
    local cursor
    cursor=$(hyprctl cursorpos -j) || return 1
    ipc twitchpaneltest snapshotTotp | jq -e --argjson cursor "$cursor" \
        '(.pointerTarget | with_entries(.value |= ((. + 0.5) | floor))) == $cursor' >/dev/null
}
wait_for 'pointer moves to TOTP icon' pointer_on_totp
ipc twitchpaneltest typeTotp twi
totp_matches '.text == "twi" and .source and .focused' || fail 'typing twi stays in TOTP search'
ipc twitchpaneltest beginTotpAdd
ipc bar open totp >/dev/null
wait_for 'reopening TOTP cancels add and preserves search' totp_matches '.focused and (.adding | not) and .text == "twi"'
ipc twitchpaneltest pressEscape >/dev/null
wait_for 'Escape dismisses keyboard TOTP' totp_matches '(.visible | not) and (.keyboard | not)'
volume_before=$(ipc twitchpaneltest snapshotVolume)
ipc bar open volume >/dev/null
wait_for 'ordinary module opens without keyboard focus or pinning' \
    sh -c 'timeout 3 qs ipc -p "$1" call twitchpaneltest snapshotVolume | jq -e ".visible and .source and (.keyboard | not) and (.pinned | not)" >/dev/null' sh "$entry"
volume_after=$(ipc twitchpaneltest snapshotVolume)
[[ $(jq -c '[.muted,.volume]' <<< "$volume_before") == "$(jq -c '[.muted,.volume]' <<< "$volume_after")" ]] || fail "opening volume must not click or alter audio: before=$volume_before after=$volume_after"
ipc bar open volume >/dev/null
[[ $(ipc twitchpaneltest snapshotVolume | jq -r .loads) == "$(jq -r .loads <<< "$volume_after")" ]] || fail 'reopening a hovered module must preserve its panel'
ipc twitchpaneltest showBadge
wait_for 'layout badge appears before selection' sh -c 'timeout 3 qs ipc -p "$1" call twitchpaneltest snapshotVolume | jq -e ".badge" >/dev/null' sh "$entry"
ipc twitchpaneltest openAfterBadge >/dev/null
pointer_on_volume() {
    local cursor
    cursor=$(hyprctl cursorpos -j) || return 1
    ipc twitchpaneltest snapshotVolume | jq -e --argjson cursor "$cursor" \
        '.visible and .source and .hovered and ((.pointerTarget | with_entries(.value |= ((. + 0.5) | floor))) == $cursor)' >/dev/null
}
wait_for 'pointer follows the module after the submap badge disappears' pointer_on_volume
ipc bar open tray >/dev/null
wait_for 'tray expands without additional pointer movement' sh -c 'timeout 3 qs ipc -p "$1" call twitchpaneltest snapshotTray | jq -e ".expanded and .height >= 30" >/dev/null' sh "$entry"
hyprctl dispatch 'hl.dsp.cursor.move({ x = 100, y = 100 })' >/dev/null
wait_for 'tray collapses when the shortcut pointer leaves' sh -c 'timeout 3 qs ipc -p "$1" call twitchpaneltest snapshotTray | jq -e ".expanded | not" >/dev/null' sh "$entry"
[[ $(ipc twitchpaneltest hoverTrayEdge) == true ]] || fail 'tray button hover delivered'
wait_for 'tray expands at the button edge outside its icon' sh -c 'timeout 3 qs ipc -p "$1" call twitchpaneltest snapshotTray | jq -e ".expanded" >/dev/null' sh "$entry"
ipc twitchpaneltest leaveBar >/dev/null
wait_for 'tray collapses after normal hover leaves' sh -c 'timeout 3 qs ipc -p "$1" call twitchpaneltest snapshotTray | jq -e ".expanded | not" >/dev/null' sh "$entry"
[[ $(ipc twitchpaneltest hoverVolumeEdge) == true ]] || fail 'volume button hover delivered'
wait_for 'module opens at the button edge outside its icon' sh -c 'timeout 3 qs ipc -p "$1" call twitchpaneltest snapshotVolume | jq -e ".visible and .source and .hovered" >/dev/null' sh "$entry"
ipc twitchpaneltest leaveBar >/dev/null
wait_for 'module dismisses after normal hover leaves' sh -c 'timeout 3 qs ipc -p "$1" call twitchpaneltest snapshotVolume | jq -e ".visible | not" >/dev/null' sh "$entry"
printf 'PASS: native Twitch bar IPC without auto-pinning, target screen, search focus, on-demand focus, pointer coordinates, repeated open, add cancellation, manual pin preservation, Escape, reset and mouse-click pin toggling\n'
printf 'PASS: bar module registration, hidden/unknown handling, TOTP focus, pointer, typing, reopen, Escape and volume without audio mutation\n'
printf 'PASS: hovered panel reuse, pointer after bar relayout, immediate tray expansion, button-edge hover and dismissal\n'
