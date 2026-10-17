#!/usr/bin/env bash
# Private offscreen UI; mock every remote command and never read real host data.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-remotes-manage.XXXXXXXX)
cleanup() {
    if [[ -f $fixture/data/remotes-runtime.db ]]; then
        while IFS= read -r id; do
            bash "$fixture/src/services/remotes/remote-worker.sh" --disconnect "$fixture/data/remotes-runtime.db" "$id" >/dev/null 2>&1 || true
        done < <(sqlite3 "$fixture/data/remotes-runtime.db" 'SELECT id FROM remote_sessions;')
        for ((attempt=0;attempt<40;attempt++)); do
            [[ $(sqlite3 "$fixture/data/remotes-runtime.db" 'SELECT COUNT(*) FROM remote_sessions;') != 0 ]] || break
            sleep 0.1
        done
    fi
    rm -rf -- "$fixture"
}
trap cleanup EXIT
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/home" "$fixture/bin"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$fixture/src/config/Config.qml"
node - "$fixture" <<'JS'
const fs=require('node:fs'),dir=process.argv[2],file=dir+'/src/config/Config.qml';let s=fs.readFileSync(file,'utf8');for(const [key,exe]of [['remoteRdpCommand','rdp'],['remoteSshCommand','ssh'],['remoteVmCommand','virsh'],['remoteProbeCommand','probe']])s=s.replace(new RegExp('readonly property var '+key+': \\[[^\\n]*\\]'),()=> 'readonly property var '+key+': '+JSON.stringify([dir+'/bin/'+exe]));fs.writeFileSync(file,s)
JS
cp "$repo/tests/remotes/mock-command.mjs" "$fixture/bin/mock"
chmod +x "$fixture/bin/mock"
for command in ssh rdp virsh probe alerts getent terminal; do ln -s mock "$fixture/bin/$command"; done
node - "$fixture" <<'JS'
const fs=require('fs'),dir=process.argv[2],path=dir+'/src/config/Config.qml';
fs.writeFileSync(path,fs.readFileSync(path,'utf8').replace(/readonly property var remoteTerminalCommand: \[[^\n]*\]/,
 'readonly property var remoteTerminalCommand: '+JSON.stringify([dir+'/bin/terminal','-e'])));
JS
sed 's@"../../src@"src@g' "$repo/tests/remotes/manage.qml" > "$fixture/shell.qml"
export REMOTE_TEST_DIR="$fixture" QS_PICKER_EXECUTABLE="$fixture/bin/alerts"
export PATH="$fixture/bin:$PATH"
export HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1
export QT_QPA_PLATFORMTHEME=generic XDG_CURRENT_DESKTOP=
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
for phase in setup restart connecting ssh sshrestart; do
    if [[ $phase == connecting ]]; then touch "$fixture/not-ready"; fi
    REMOTE_TEST_PHASE="$phase" timeout 25 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
    if ! rg -q 'PASS: remotes' "$fixture/log" || rg -q 'REMOTE FAIL:|TypeError:|ReferenceError:|Failed to load configuration|Binding loop' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
    rg 'PASS: remotes' "$fixture/log"
done
jq -se '([.[]|select(.program=="virsh" and .args==["shutdown","--","fixture-vm"])]|length)==1 and ([.[]|select(.program=="rdp")]|length)==2' "$fixture/actions" >/dev/null
[[ $(sqlite3 "$fixture/data/quickshell.db" 'PRAGMA user_version;') == 15 ]]
printf 'PASS: only selected VM is shut down; detached clients across restart and sequential Enter disconnects; connecting cancellation launches no RDP\n'
