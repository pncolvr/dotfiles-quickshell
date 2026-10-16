#!/usr/bin/env bash
# Actual browser IPC/window reuse with about:blank only; no user profile or desktop surface.
set -euo pipefail
command -v qutebrowser >/dev/null
fixture=$(mktemp -d /tmp/quickshell-qute-native.XXXXXXXX)
pids=()
cleanup() {
    for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
    for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
    rm -rf -- "$fixture"
}
trap cleanup EXIT
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/home"
export HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME=generic QT_NO_XDG_DESKTOP_PORTAL=1 GIO_USE_VFS=local
# Test-only WebEngine setup for hosts without usable Chromium sandbox namespaces.
export QTWEBENGINE_DISABLE_SANDBOX=1 QTWEBENGINE_CHROMIUM_FLAGS='--disable-gpu'
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
wait_session() {
    local file=$fixture/$1/data/sessions/$2.yml
    for ((try=0;try<160;try++)); do
        [[ ! -s $file ]] || return 0
        sleep 0.05
    done
    printf 'Qutebrowser did not save the synthetic session.\n' >&2
    return 1
}
check_session() {
    node - "$fixture/$1/data/sessions/$2.yml" "$3" "$4" <<'JS'
const fs=require('node:fs'), [file,windows,tabs]=process.argv.slice(2);
const source=fs.readFileSync(file,'utf8');
// Qutebrowser's YAML writes window rows at column 0 and tab rows at column 2.
if ((source.match(/^- /gm)??[]).length!==Number(windows) || (source.match(/^  - /gm)??[]).length!==Number(tabs))
    throw new Error('Unexpected window/tab count in the synthetic browser session.');
JS
}
start() {
    qutebrowser -B "$fixture/$1" -C /dev/null --target tab about:blank ':session-save -q -f initial' > "$fixture/$1.log" 2>&1 &
    pids+=("$!")
    wait_session "$1" initial
    check_session "$1" initial 1 1
}
client() { timeout 10 qutebrowser -B "$fixture/$1" -C /dev/null "${@:2}" > "$fixture/client.log" 2>&1; }
start profile-a
client profile-a --target tab about:blank ':session-save -q -f grouped'
wait_session profile-a grouped
check_session profile-a grouped 1 2
printf 'PASS: repeated Qutebrowser launches reuse one profile window as tabs\n'
start profile-b
client profile-a ':session-save -q -f after-other-profile'
wait_session profile-a after-other-profile
check_session profile-a after-other-profile 1 2
check_session profile-b initial 1 1
printf 'PASS: a different Qutebrowser profile uses its own window and tabs\n'
client profile-a --target window about:blank ':session-save -q -f separate'
wait_session profile-a separate
check_session profile-a separate 2 3
printf 'PASS: explicit New window remains available\n'
