#!/usr/bin/env bash
# Native shortcut callbacks only: no windows, real bindings, input or user data.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
    printf 'SKIP: native shortcut registry requires a Wayland/Hypr session\n'
    exit 0
fi
fixture=$(mktemp -d /tmp/qsgs.XXXXXX)
probe_pid=''
cleanup() {
    result=$?
    if ((result != 0)) && [[ -f $fixture/log ]]; then cat "$fixture/log" >&2; fi
    if [[ -n $probe_pid ]]; then kill "$probe_pid" 2>/dev/null || true; wait "$probe_pid" 2>/dev/null || true; fi
    rm -rf -- "$fixture"
}
trap cleanup EXIT
mkdir -m700 "$fixture/r"
ln -s "$repo_dir/src" "$fixture/src"
ln -s "${XDG_RUNTIME_DIR:?}/hypr" "$fixture/r/hypr"
display=$WAYLAND_DISPLAY
[[ $display == /* ]] || display=$XDG_RUNTIME_DIR/$display
node - "$repo_dir" "$fixture" <<'NODE'
const fs=require('fs');const [repo,fixture]=process.argv.slice(2);
const source=fs.readFileSync(repo+'/shell.qml','utf8');
const match=/  GlobalShortcutRegistry \{\n    actions: \[[\s\S]*?\n  \}/.exec(source);
if(!match)throw new Error('Main shortcut registry not found');
let block=match[0].replace('GlobalShortcutRegistry {','GlobalShortcutRegistry {\n    appId: "qs-test-" + Quickshell.env("SHORTCUT_TEST_ID")');
for (const [service, mock] of Object.entries({PickerService: 'mockPicker', RecordingService: 'mockRecording',
 RbwService: 'mockVault', NotificationService: 'mockNotifications', WindowService: 'mockWindows',
 BarModuleService: 'mockBar', PowerService: 'mockPower', BookmarkService: 'mockBookmarks', shellRoot: 'mockShell'})) block=block.replaceAll(service+'.',mock+'.');
fs.writeFileSync(fixture+'/shell.qml',`import QtQml
import Quickshell
import Quickshell.Io
import "src/services"
Scope {
  id: root
  property var calls: []
  function record(method, args) { calls = calls.concat([{method, args, at: Date.now()}]) }
  QtObject {
    id: mockPicker
    function apps() { root.record("apps", []) }
    function projects(urls = false) { root.record("projects", [urls]) }
    function directories() { root.record("directories", []) }
    function webapps() { root.record("webapps", []) }
    function remotes() { root.record("remotes", []) }
    function n8n() { root.record("n8n", []) }
    function windows(scope) { root.record("windows", [scope]) }
    function expose(scope) { root.record("expose", [scope]) }
    function clipboard() { root.record("clipboard", []) }
  }
  QtObject { id: mockRecording; function toggle() { root.record("recording", []) } }
  QtObject { id: mockBookmarks; function open() { root.record("bookmarks", []) } }
  QtObject { id: mockPower; function open() { root.record("power", []) } }
  QtObject { id: mockVault; function open() { root.record("vault", []) } }
  QtObject { id: mockNotifications; function toggle() { root.record("dnd", []) } }
  QtObject { id: mockShell; function reloadShell() { root.record("shell-reload", []) } }
  QtObject {
    id: mockWindows
    function cycleNext() { root.record("windows-next", []) }
    function cyclePrev() { root.record("windows-prev", []) }
    function focusIndex(key) { root.record("windows-focus", [key]) }
  }
  QtObject { id: mockBar; function open(name) { root.record("bar", [name]) } }
${block}
  IpcHandler {
    target: "shortcuttest"
    function snapshot(): string { return JSON.stringify(root.calls) }
    function reload(): void { Qt.callLater(() => Quickshell.reload(true)) }
  }
}
`);
NODE
SHORTCUT_TEST_ID=${fixture##*/} QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display" XDG_RUNTIME_DIR="$fixture/r" \
    XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    qs -p "$fixture/shell.qml" > "$fixture/log" 2>&1 & probe_pid=$!
SHORTCUT_TEST_ID=${fixture##*/} XDG_RUNTIME_DIR="$fixture/r" node - "$fixture" <<'NODE'
const fs=require('fs'),cp=require('child_process');const fixture=process.argv[2];
const expected={
 'launcher-apps':['apps',[]], 'launcher-projects':['projects',[false]],
 'launcher-project-urls':['projects',[true]], 'launcher-directories':['directories',[]],
 'launcher-webapps':['webapps',[]], 'launcher-remotes':['remotes',[]], 'launcher-n8n':['n8n',[]],
 'launcher-windows-all':['windows',['all']], 'launcher-windows-current':['windows',['current']],
 'launcher-expose-current':['expose',['current']], 'launcher-clipboard':['clipboard',[]],
 'launcher-bookmarks':['bookmarks',[]], 'launcher-power':['power',[]], 'recording-toggle':['recording',[]], 'vault-toggle':['vault',[]],
 'notifications-toggle-dnd':['dnd',[]], 'shell-reload':['shell-reload',[]],
 'windows-next':['windows-next',[]], 'windows-prev':['windows-prev',[]]
};
for (const name of ['updates','clock','files','timers','mic','volume','stats','twitch',
 'status','totp','batteries','notifications','tray','sharing']) expected['bar-'+name]=['bar',[name]];
for(let key=0;key<10;key++) expected['windows-focus-'+key]=['windows-focus',[String(key)]];
function ipc(method) {
 const result=cp.spawnSync('qs',['ipc','--any-display','-p',fixture,'call','shortcuttest',method],{encoding:'utf8',timeout:1500});
 if(result.status!==0 || (method==='snapshot' && !result.stdout.trim())) return null;
 if(method!=='snapshot') return true;
 if(result.stdout.trim()==='Not ready to accept queries yet.') return null;
 return JSON.parse(result.stdout);
}
function waitFor(predicate,message) {
 for(let i=0;i<100;i++) {const value=predicate();if(value)return value;Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,20);}
 throw new Error(message);
}
waitFor(()=>ipc('snapshot'),'Registry fixture did not start');
const timings=[];
for(let generation=0;generation<2;generation++) {
 let count=0;
 for(const [name,[method,args]]of Object.entries(expected)) {
  const started=Date.now();
  const result=cp.spawnSync('hyprctl',['dispatch','hl.dsp.global('+JSON.stringify('qs-test-'+process.env.SHORTCUT_TEST_ID+':'+name)+')'],{encoding:'utf8',timeout:1500});
  if(result.status!==0)throw new Error('Native dispatch failed: '+name);
  count++;
  const calls=waitFor(()=>{const value=ipc('snapshot');return value?.length>=count?value:null;},'Callback missing: '+name);
  if(calls.length!==count||calls.at(-1).method!==method||JSON.stringify(calls.at(-1).args)!==JSON.stringify(args))
   throw new Error('Wrong or duplicated service action: '+name);
  timings.push(calls.at(-1).at-started);
 }
 console.log('PASS: all '+Object.keys(expected).length+' production shortcut actions dispatch exactly once '+(generation?'after reload':'before reload'));
 if(!generation) {
  if(!ipc('reload'))throw new Error('Fixture reload failed');
  waitFor(()=>{const calls=ipc('snapshot');return calls?.length===0;},'New registry generation did not load');
 }
}
timings.sort((a,b)=>a-b);
console.log('PASS: reload re-registers native shortcuts without changing any real binding, focus, window or user data');
console.log('Native callback median including test-client startup: '+timings[Math.floor(timings.length/2)]+' ms');
NODE
if rg -q 'TypeError:|ReferenceError:|Binding loop|Failed to load configuration|Wayland protocol error' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
