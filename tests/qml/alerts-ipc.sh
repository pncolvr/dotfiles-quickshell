#!/usr/bin/env bash
# Real IPC and production translations, with no native windows or capture devices.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-alerts-ipc.XXXXXXXX)
shell_pid=''
cleanup() {
    local result=$?
    if ((result != 0)); then cat "$fixture/log" >&2; fi
    if [[ -n $shell_pid ]]; then kill "$shell_pid" 2>/dev/null || true; wait "$shell_pid" 2>/dev/null || true; fi
    rm -rf -- "$fixture"
}
trap cleanup EXIT
mkdir -m700 "$fixture/runtime"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/readonly property string language: .*/readonly property string language: "en"/' "$fixture/src/config/Config.qml"
cat > "$fixture/shell.qml" <<'QML'
import QtQuick
import Quickshell
import Quickshell.Io
import "src/services"
import "src/i18n"
WorkerScope {
    IpcHandler {
        target: "alertcheck"
        function ready(): bool { return AlertService.messages.length === 0 && !!Translations.messages["recording.worker.starting"] }
        function messages(): string { return JSON.stringify(AlertService.messages) }
    }
}
QML
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1
export XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache"
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
qs -p "$fixture" > "$fixture/log" 2>&1 & shell_pid=$!
ipc() { timeout 2 qs ipc -p "$fixture" call "$@"; }
for ((attempt=0;attempt<100;attempt++)); do
    if [[ $(ipc alertcheck ready 2>/dev/null || true) == true ]]; then break; fi
    kill -0 "$shell_pid" 2>/dev/null || exit 1
    sleep 0.02
done
[[ $(ipc alertcheck ready) == true ]]

[[ $(ipc alerts postMessage recording recording.worker.starting ' []' success 1000 true) == true ]]
ipc alertcheck messages | jq -e 'length==1 and .[0].text=="Recording starting" and .[0].captureBlocking and .[0].expiresAt>0' >/dev/null
[[ $(ipc alerts postMessage recording recording.worker.finishing ' []' info 0 false) == true ]]
ipc alertcheck messages | jq -e 'length==1 and .[0].text=="Recording finishing" and (.[0].captureBlocking|not) and .[0].expiresAt==0' >/dev/null
[[ $(ipc alerts postMessage recording recording.worker.stopped ' []' success 1000 false) == true ]]
ipc alertcheck messages | jq -e 'length==1 and .[0].text=="Recording stopped"' >/dev/null
printf 'PASS: real IPC delivers translated recording start, finishing and stop alerts\n'

# Empty, single and multiple arguments must remain one literal JSON string.
args=$(jq -nc --arg mode 'work, "quoted" [literal]' --arg output 'DP-1 日本語' '[$mode,$output]')
[[ $(ipc alerts postMessage wallpaper wallpaper.status.saved " $args" success 3000 false) == true ]]
ipc alertcheck messages | jq -e '.[1].text=="Wallpaper saved for work, \"quoted\" [literal] on DP-1 日本語"' >/dev/null
[[ $(ipc alerts postMessage wallpaper wallpaper.status.savedOutput ' ["DP-1"]' success 3000 false) == true ]]
ipc alertcheck messages | jq -e 'length==2 and .[1].text=="Wallpaper saved on DP-1"' >/dev/null
[[ $(ipc alerts postMessage invalid recording.worker.starting ' {}' success 1000 false) == false ]]
printf 'PASS: translated IPC keeps literal JSON arrays intact and rejects non-array arguments\n'
if rg -q 'TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then exit 1; fi
