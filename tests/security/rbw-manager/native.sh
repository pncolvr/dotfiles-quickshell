#!/usr/bin/env bash
# Native synthetic manager; no screenshots, live vault or clipboard access.
set -euo pipefail
desktop_runtime=${XDG_RUNTIME_DIR:?}
display=${WAYLAND_DISPLAY:?}
[[ $display == /* ]] || display=$desktop_runtime/$display
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
copy_shell
sed 's@"../../../src@"src@g' "$manager_test_root/native.qml" > "$test_dir/shell.qml"
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display"
qs -p "$test_dir" > "$test_dir/log" 2>&1 & shell_pid=$!
wait_state '.visible==false'
ipc open
wait_state '.visible and (.busy|not) and .count==2 and .details and .namespace=="quickshell-private"'
check_layer() {
    local layers
    layers=$(XDG_RUNTIME_DIR="$desktop_runtime" timeout 2 hyprctl layers -j)
    jq -e --argjson pid "$shell_pid" 'any(.[] | .levels[][]; .pid==$pid and .namespace=="quickshell-private") and (any(.[] | .levels[][]; .pid==$pid and .namespace!="quickshell-private")|not)' <<< "$layers" >/dev/null
}
check_layer
ipc select
wait_state '.details and (.busy|not)'
check_layer
ipc newLogin
wait_state '.editing'
check_layer
ipc close
wait_state '(.visible|not)'
! rg -q 'SYNTHETIC_(SECRET|DRAFT|GENERATED|COPY|SEED|HISTORY)|TypeError|ReferenceError|Error:|Binding loop|Cannot assign|Column will not function' "$test_dir/log"
printf 'PASS: compositor confirms private vault search, details and manager editor\n'
