#!/usr/bin/env bash
# Optional synthetic Wayland prompt; no screenshots, vault or clipboard access.
set -euo pipefail
desktop_runtime=${XDG_RUNTIME_DIR:?}
display=${WAYLAND_DISPLAY:?A Wayland session is required}
[[ $display == /* ]] || display=$desktop_runtime/$display
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
copy_shell
sed 's@"../../../src@"src@g' "$rbw_test_root/native.qml" > "$test_dir/shell.qml"
printf '%s\n' '{"private":true,"showPrompt":true,"prompt":"Synthetic login picker — no vault access","allowTyped":false,"items":[{"title":"Synthetic login","result":"private-entry"}]}' > "$test_dir/private-options.json"
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display"
export QS_PICKER_CONFIG="$test_dir" QS_PICKER_TIMEOUT=6
qs -p "$test_dir" > "$test_dir/log" 2>&1 & shell_pid=$!
ordinary=false private=false private_entry=false
for ((attempt=0;attempt<200;attempt++)); do
    kill -0 "$shell_pid" 2>/dev/null || break
    layers=$(XDG_RUNTIME_DIR="$desktop_runtime" timeout 2 hyprctl layers -j)
    if jq -e --argjson pid "$shell_pid" 'any(.[] | .levels[][]; .pid == $pid and .namespace == "quickshell-picker")' <<< "$layers" >/dev/null; then ordinary=true; fi
    if jq -e --argjson pid "$shell_pid" 'any(.[] | .levels[][]; .pid == $pid and .namespace == "quickshell-private")' <<< "$layers" >/dev/null; then
        private=true
        if rg -q 'Native private login picker mapped' "$test_dir/log"; then private_entry=true; fi
    fi
    sleep 0.05
done
kill -0 "$shell_pid" 2>/dev/null && { printf 'FAIL: native prompt timeout\n' >&2; exit 1; }
wait "$shell_pid"; shell_pid=''
[[ $ordinary == true && $private == true && $private_entry == true ]]
rg -q 'PASS: native centered masked rbw prompt' "$test_dir/log"
! rg -q 'FAIL:|NATIVE_RBW_SYNTHETIC' "$test_dir/log"
printf 'PASS: native private unlock and entry picker, ordinary-menu reset, eye toggle, masking and clearing\n'
