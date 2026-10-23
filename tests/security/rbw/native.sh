#!/usr/bin/env bash
# Optional synthetic Wayland prompt; no screenshots, vault or clipboard access.
set -euo pipefail
desktop_runtime=${XDG_RUNTIME_DIR:?}
display=${WAYLAND_DISPLAY:?A Wayland session is required}
[[ $display == /* ]] || display=$desktop_runtime/$display
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
# Keep the full Hyprland Unix-socket path below its 108-byte limit.
native_runtime=$(mktemp -d /tmp/qsr.XXXXXXXX)
export XDG_RUNTIME_DIR=$native_runtime
original_window=$(XDG_RUNTIME_DIR="$desktop_runtime" hyprctl activewindow -j | jq -r '.address // ""')
original_cursor=$(XDG_RUNTIME_DIR="$desktop_runtime" hyprctl cursorpos -j | jq -r '[.x,.y] | @tsv')
native_cleanup() {
    local result=$?
    if ((result != 0)); then
        printf 'FAIL: native rbw fixture exited with status %s\n' "$result" >&2
        [[ ! -f $test_dir/log ]] || cat "$test_dir/log" >&2
    fi
    cleanup
    rm -rf -- "$native_runtime"
    if [[ $original_window =~ ^0x[0-9a-fA-F]+$ ]]; then
        XDG_RUNTIME_DIR="$desktop_runtime" hyprctl dispatch "hl.dsp.focus({ window = \"address:$original_window\" })" >/dev/null 2>&1 || true
    fi
    read -r original_x original_y <<< "$original_cursor"
    XDG_RUNTIME_DIR="$desktop_runtime" hyprctl dispatch "hl.dsp.cursor.move({ x = $original_x, y = $original_y })" >/dev/null 2>&1 || true
    return "$result"
}
trap native_cleanup EXIT
copy_shell
ln -s -- "$desktop_runtime/hypr" "$XDG_RUNTIME_DIR/hypr"
sed 's@"../../../src@"src@g' "$rbw_test_root/native.qml" > "$test_dir/shell.qml"
printf '%s\n' '{"private":true,"showPrompt":true,"prompt":"Synthetic login picker — no vault access","allowTyped":false,"items":[{"title":"Synthetic login","result":"private-entry"}]}' > "$test_dir/private-options.json"
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display"
export QS_PICKER_CONFIG="$test_dir" QS_PICKER_TIMEOUT=12
qs -p "$test_dir" > "$test_dir/log" 2>&1 & shell_pid=$!
ordinary=false private=false private_entry=false helper_prepared=false
for ((attempt=0;attempt<300;attempt++)); do
    kill -0 "$shell_pid" 2>/dev/null || break
    layers=$(XDG_RUNTIME_DIR="$desktop_runtime" timeout 2 hyprctl layers -j)
    if jq -e --argjson pid "$shell_pid" 'any(.[] | .levels[][]; .pid == $pid and .namespace == "quickshell-picker")' <<< "$layers" >/dev/null; then ordinary=true; fi
    if jq -e --argjson pid "$shell_pid" 'any(.[] | .levels[][]; .pid == $pid and .namespace == "quickshell-private")' <<< "$layers" >/dev/null; then
        private=true
        if rg -q 'Native private login picker mapped' "$test_dir/log"; then private_entry=true; fi
    fi
    if [[ $helper_prepared == false ]]; then
        state=$(qs ipc -p "$test_dir" call rbwnativetest snapshot 2>/dev/null || true)
        if jq -e '.step == 6 and .helperPresented' <<< "$state" >/dev/null 2>&1; then
            # Wayland does not expose a top-level window's desktop position to Qt.
            # Wait for the compositor's mapped window and use its actual geometry.
            helper=$(XDG_RUNTIME_DIR="$desktop_runtime" hyprctl clients -j | jq -c --argjson pid "$shell_pid" \
                '.[] | select(.pid == $pid and .mapped and .title == "Quickshell synthetic focus check")')
            if [[ -n $helper ]]; then
                helper_address=$(jq -er '.address | select(test("^0x[0-9a-fA-F]+$"))' <<< "$helper")
                read -r helper_x helper_y < <(jq -r '[(.at[0]+.size[0]/2|floor),(.at[1]+.size[1]/2|floor)] | @tsv' <<< "$helper")
                [[ $(qs ipc -p "$test_dir" call rbwnativetest helperReady) == true ]]
                XDG_RUNTIME_DIR="$desktop_runtime" hyprctl dispatch "hl.dsp.cursor.move({ x = $helper_x, y = $helper_y })" >/dev/null
                XDG_RUNTIME_DIR="$desktop_runtime" hyprctl dispatch "hl.dsp.focus({ window = \"address:$helper_address\" })" >/dev/null
                helper_prepared=true
            fi
        fi
    fi
    sleep 0.05
done
kill -0 "$shell_pid" 2>/dev/null && { printf 'FAIL: native prompt timeout\n' >&2; exit 1; }
wait "$shell_pid"; shell_pid=''
[[ $ordinary == true && $private == true && $private_entry == true ]]
rg -q 'PASS: native centered masked rbw prompt' "$test_dir/log"
rg -q 'PASS: secret prompt survives desktop focus' "$test_dir/log"
! rg -q 'FAIL:|NATIVE_RBW_SYNTHETIC' "$test_dir/log"
printf 'PASS: native private unlock and entry picker, desktop interaction, focus return, ordinary-menu reset, eye toggle, masking and clearing\n'
