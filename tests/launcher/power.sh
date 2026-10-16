#!/usr/bin/env bash
# All power/session commands are mocked; no native desktop input is used.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
qs_bin=$(command -v qs)
fixture=$(mktemp -d /tmp/qs-power.XXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/r" "$fixture/home" "$fixture/bin"
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/' "$fixture/src/config/Config.qml"
cat > "$fixture/src/services/status/StatusService.qml" <<'QML'
pragma Singleton
import Quickshell
import "../"
Singleton {
    property bool enabled: false
    property string status: "personal"
    property int pauseCalls: 0
    property bool pausedWithMenuClosed: false
    function pause() { pauseCalls++; pausedWithMenuClosed = !PickerService.visible }
    function reload() {}
}
QML
cat > "$fixture/bin/action" <<'MOCK'
#!/usr/bin/env bash
name=${0##*/}
if [[ $name == qs ]]; then printf 'unexpected IPC\n' >> "$POWER_TEST_DIR/ipc"; exit 1; fi
if [[ $name == hyprctl && ${1:-} != dispatch ]]; then printf '[]\n'; exit 0; fi
printf '%s %s\n' "$name" "$*" >> "$POWER_TEST_DIR/actions"
MOCK
chmod +x "$fixture/bin/action"
for tool in systemctl loginctl hyprctl qs; do ln -s action "$fixture/bin/$tool"; done
sed 's@"../../src@"src@g' "$repo_dir/tests/launcher/power.qml" > "$fixture/shell.qml"
export POWER_TEST_DIR="$fixture" PATH="$fixture/bin:$PATH" HOME="$fixture/home"
export XDG_RUNTIME_DIR="$fixture/r" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    timeout -k 1 10 "$qs_bin" -p "$fixture/shell.qml" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: native Power grid' "$fixture/log" || rg -q 'POWER FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
[[ ! -e $fixture/ipc ]]
node - "$fixture/actions" <<'NODE'
const fs=require('fs');const lines=fs.readFileSync(process.argv[2],'utf8').trim().split('\n');
const expected=['systemctl reboot','loginctl lock-session','hyprctl dispatch exit','systemctl poweroff','systemctl reboot --firmware-setup'];
if(JSON.stringify(lines)!==JSON.stringify(expected))throw Error('Wrong or duplicate power commands: '+JSON.stringify(lines));
console.log('PASS: native selection executes each original command once with no shell-to-picker/status IPC');
NODE
# Idle locking remains independent of bar availability; its status notification is best effort.
QS_PICKER_EXECUTABLE="$fixture/bin/qs" bash "$fixture/src/services/launcher/providers/power.sh" Lock
[[ $(tail -n 1 "$fixture/actions") == 'loginctl lock-session' && -s $fixture/ipc ]]
count=$(wc -l < "$fixture/actions")
if bash "$fixture/src/services/launcher/providers/power.sh" --execute 'Lock; shutdown'; then exit 1; fi
[[ $(wc -l < "$fixture/actions") == "$count" ]]
rg 'PASS:' "$fixture/log"
printf 'PASS: offline idle Lock survives IPC failure; invalid executor actions do nothing\n'
