#!/usr/bin/env bash
# Shared isolation for synthetic checks; never inspect a real vault/clipboard.
set -euo pipefail
rbw_test_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_root=$(cd -- "$rbw_test_root/../../.." && pwd)
scripts_root=${QUTE_RBW_SCRIPTS_ROOT:-/home/pncolvr/.local/share/qutebrowser/userscripts}
browser_root=${QUTE_RBW_BROWSER_ROOT:-/home/pncolvr/.config/qutebrowser}
umask 077
test_dir=$(mktemp -d /tmp/rbw-test.XXXXXXXX)
shell_pid='' client_pid='' server_pid=''
cleanup() {
    for pid in "$client_pid" "$shell_pid" "$server_pid" "${driver_pid:-}"; do
        if [[ -n $pid ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
    done
    if [[ ${RBW_TEST_KEEP:-0} == 1 ]]; then
        printf 'Test artifacts: %s\n' "$test_dir" >&2
    else
        rm -rf -- "$test_dir"
    fi
}
trap cleanup EXIT
mkdir -m 700 "$test_dir/runtime"
mkdir -p "$test_dir/data" "$test_dir/cache" "$test_dir/config" "$test_dir/bin"
export XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data"
export XDG_CACHE_HOME="$test_dir/cache" XDG_CONFIG_HOME="$test_dir/config"
export PYTHONDONTWRITEBYTECODE=1 RBW_PROFILE=''
copy_shell() {
    tar -C "$project_root" --exclude='src/services/launcher/providers/*.json' --exclude='*.env' --exclude='__pycache__' -cf - src | tar -C "$test_dir" -xf -
    sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$test_dir/src/config/Config.qml"
    sed -i 's@readonly property var hyprlandHideApplicationsCommand:.*@readonly property var hyprlandHideApplicationsCommand: (active) => ["true"]@' "$test_dir/src/config/Config.qml"
}
ipc() { timeout 4 qs ipc -p "$test_dir" call rbwtest "$1"; }
snapshot() { ipc snapshot; }
wait_state() {
    local condition=$1
    for ((attempt=0;attempt<160;attempt++)); do
        if snapshot 2>/dev/null | jq -e "$condition" >/dev/null 2>&1; then return; fi
        kill -0 "$shell_pid" 2>/dev/null || { printf 'FAIL: isolated shell stopped\n' >&2; return 1; }
        sleep 0.05
    done
    printf 'FAIL: isolated picker timeout\n' >&2; return 1
}
wait_client() {
    local expected=$1 code=0
    wait "$client_pid" || code=$?
    client_pid=''
    [[ $code == "$expected" ]] || { printf 'FAIL: unexpected client status %s\n' "$code" >&2; return 1; }
}
assert_empty() { [[ ! -s $1 ]]; }
