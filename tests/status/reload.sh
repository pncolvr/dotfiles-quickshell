#!/usr/bin/env bash
# Introduce the current editor to an already loaded QML engine, then reload it twice.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-status-reload-test.XXXXXXXX)
process=''
cleanup() {
    local result=$?
    if ((result != 0)); then cat "$fixture/log" >&2; fi
    if [[ -n $process ]]; then kill "$process" 2>/dev/null || true; wait "$process" 2>/dev/null || true; fi
    rm -rf -- "$fixture"
}
trap cleanup EXIT
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/home"
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/' "$fixture/src/config/Config.qml"
sed 's@"../../src@"src@g' "$project_root/tests/status/reload.qml" > "$fixture/shell.qml"
# Cache this file without an inline/local list type, as on the running old bar.
cat > "$fixture/src/modules/status/StatusRulesEditor.qml" <<'QML'
import QtQuick
Item {
    property var statusService
    function load() {}
}
QML
# The type must also be discoverable when added to a previously loaded UI module.
rm -f "$fixture/src/ui/components/LineListField.qml"
sed -i '/^LineListField 1.0 /d' "$fixture/src/ui/qmldir" "$fixture/src/ui/components/qmldir"
export HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
qs -p "$fixture" > "$fixture/log" 2>&1 &
process=$!
ipc() { timeout 2 qs ipc -p "$fixture" call statusReloadTest "$@"; }
wait_state() {
    local expression=$1
    for ((attempt=0; attempt<80; attempt++)); do
        if snapshot=$(ipc state 2>/dev/null) && jq -e "$expression" <<< "$snapshot" >/dev/null 2>&1; then return 0; fi
        kill -0 "$process" 2>/dev/null || break
        sleep 0.05
    done
    printf 'Last snapshot: %s\n' "${snapshot:-unavailable}" >&2
    cat "$fixture/log" >&2
    printf 'STATUS RELOAD FAIL: %s\n' "$expression" >&2
    return 1
}
wait_state '.loaded and (.multiple|not)'
cp "$project_root/src/ui/components/LineListField.qml" "$fixture/src/ui/components/"
cp "$project_root/src/ui/qmldir" "$fixture/src/ui/qmldir"
cp "$project_root/src/ui/components/qmldir" "$fixture/src/ui/components/qmldir"
sleep 1.1
cp "${STATUS_RELOAD_EDITOR:-$project_root/src/modules/status/StatusRulesEditor.qml}" "$fixture/src/modules/status/StatusRulesEditor.qml"
# Verify the actual current panel, rather than merely checking the process or IPC target.
wait_state '.loaded and .multiple and .text=="/synthetic/first"'
exercise=$(ipc exercise)
jq -e '.folders==["/synthetic/first","/synthetic/second"] and .text=="/synthetic/first\n/synthetic/second" and (.dirty|not)' <<< "$exercise" >/dev/null || { printf '%s\n' "$exercise"; cat "$fixture/log"; exit 1; }
generation=$(jq -r .generation <<< "$snapshot")
ipc reload >/dev/null
# Successful explicit reload creates a new root and loads the new list component.
wait_state ".loaded and .multiple and .generation!=\"$generation\""
generation=$(jq -r .generation <<< "$snapshot")
printf '\n// Exercise automatic reload of the shared field.\n' >> "$fixture/src/ui/components/LineListField.qml"
wait_state ".loaded and .multiple and .generation!=\"$generation\""
ipc exercise | jq -e '.folders==["/synthetic/first","/synthetic/second"] and (.dirty|not)' >/dev/null
! rg -q 'Failed to load configuration|TypeError:|ReferenceError:|Binding loop' "$fixture/log"
ipc quit >/dev/null
wait "$process"
process=''
printf 'PASS: existing-engine upgrade, actual folder list, explicit reload and shared-field automatic reload\n'
