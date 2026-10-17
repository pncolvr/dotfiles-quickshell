#!/usr/bin/env bash
# Real native setup/picker; synthetic monitors, audio and region selection only.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qsr.XXXXXX)
original_runtime=${XDG_RUNTIME_DIR:-}
original_display=${WAYLAND_DISPLAY:-}
previous_window=''
cleanup() {
    if [[ -n $previous_window ]]; then XDG_RUNTIME_DIR="$original_runtime" /usr/bin/hyprctl dispatch "hl.dsp.focus({ window = \"address:$previous_window\" })" >/dev/null 2>&1 || true; fi
    rm -rf -- "$fixture"
}
trap cleanup EXIT
mkdir -m700 "$fixture/r" "$fixture/bin" "$fixture/home"
qs_bin=$(command -v qs)
export RECORD_SETUP_TEST=$fixture
cat > "$fixture/bin/tool" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
name=${0##*/}
jq -nc --arg tool "$name" --args '{tool:$tool,args:$ARGS.positional}' -- "$@" >> "$RECORD_SETUP_TEST/actions"
control=$(cat "$RECORD_SETUP_TEST/control" 2>/dev/null || printf '{}')
case $name in
    hyprctl)
        case " $* " in
            *" clients "*) printf '[]\n' ;;
            *" activewindow "*) printf '{"hidden":false}\n' ;;
            *) printf '[{"name":"HDMI-A-1"},{"name":"DP-1"}]\n' ;;
        esac ;;
    slurp)
        cat > "$RECORD_SETUP_TEST/selector-stdin"
        case $(jq -r '.slurp // "ok"' <<< "$control") in
            cancel) printf 'selection cancelled\n' >&2; exit 1 ;;
            invalid) printf 'invalid\n' ;; *) printf '10,20 300x200\n' ;;
        esac ;;
    pactl)
        if [[ $(jq -r '.slow // false' <<< "$control") == true ]]; then sleep 0.2; fi
        case $1 in
            get-default-sink) echo output.default ;;
            get-default-source) echo mic.default ;;
            --format=json)
                case $3 in
                    cards) echo '[{"index":1,"active_profile":"off","properties":{"object.id":"100"}},{"index":2,"active_profile":"on"}]' ;;
                    sinks|sources)
                        if [[ $(jq -r '.empty // false' <<< "$control") == true ]]; then echo '[]'; exit; fi
                        if [[ $3 == sinks ]]; then
                            echo '[{"name":"output.other","description":"Other output","monitor_source":"other.monitor"},{"name":"output.default","description":"Default output","monitor_source":"output.monitor"},{"name":"off.card","card":1},{"name":"off.id","properties":{"device.id":"100"}},{"name":"off.profile","properties":{"device.profile.name":"off"}}]'
                        else
                            echo '[{"name":"mic.other","description":"Other mic"},{"name":"mic.default","description":"Default mic"},{"name":"virtual.monitor"},{"name":"off.card","card":1},{"name":"off.profile","properties":{"device.profile.name":"off"}}]'
                        fi ;;
                esac ;;
            *) exit 90 ;;
        esac ;;
    qs|wf-recorder) exit 90 ;;
esac
MOCK
chmod +x "$fixture/bin/tool"
for command in hyprctl pactl slurp qs wf-recorder; do ln -s tool "$fixture/bin/$command"; done
export PATH="$fixture/bin:$PATH"
printf '{}' > "$fixture/control"
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/' "$fixture/src/config/Config.qml"
sed 's@"../../src@"src@g' "$repo_dir/tests/recording/setup.qml" > "$fixture/shell.qml"
platform=offscreen
if [[ ${RECORD_SETUP_NATIVE:-0} == 1 ]]; then
    previous_window=$(XDG_RUNTIME_DIR="$original_runtime" /usr/bin/hyprctl activewindow -j | jq -r '.address // empty')
    display=$original_display
    [[ $display == /* ]] || display=$original_runtime/$display
    ln -s "$original_runtime/hypr" "$fixture/r/hypr"
    node - "$fixture/shell.qml" <<'NATIVE'
const fs=require('fs'),p=process.argv[2];let s=fs.readFileSync(p,'utf8');
const start=s.indexOf('    FloatingWindow {'),end=s.indexOf('    FileView {',start);
if(start<0||end<0)throw Error('Native host marker missing');
s=s.slice(0,start)+`    PickerWindow { id: nativePicker; picker: CaptureMenuService }
    PrivatePickerWindow {}
    property var panel: nativePicker.panel
`+s.slice(end);
s=s.replace('CaptureMenuService.items.length > 0, "native "','CaptureMenuService.items.length > 0 && !!panel, "native "');
s=s.replace('const field = events.findChild(panel,"pickerSearch")', 'waitFor(() => nativePicker.visible && nativePicker.windowActive, "native picker activated"); const field = events.findChild(panel,"pickerSearch")');
fs.writeFileSync(p,s);
NATIVE
    export WAYLAND_DISPLAY=$display
    platform=wayland
fi
env QT_QPA_PLATFORM="$platform" QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 QS_NO_RELOAD_POPUP=1 \
    HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/r" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 1 25 "$qs_bin" -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: native recording' "$fixture/log" || rg -q 'SETUP FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
if jq -se 'any(.[]; .tool=="qs" or .tool=="wf-recorder" or (.tool=="pactl" and .args[0]=="load-module"))' "$fixture/actions" >/dev/null; then
    printf 'Setup unexpectedly invoked a worker, IPC client or audio module\n' >&2; exit 1
fi
rg 'PASS:' "$fixture/log"
node --input-type=module - "$repo_dir" <<'JS'
import assert from 'node:assert/strict';
const {prepared,deviceRows}=await import(process.argv[2]+'/src/services/recording/RecordingOptions.mjs');
const encoderArguments=['--codec','libx264','--codec-param','preset=veryfast'];
const directory='/tmp/quotes " $literal $(touch injected)';
const options=prepared({capture:'region',geometry:'-10,20 300x200',fps:30,audio:'both',outputDevice:'output $(literal)',monitorSource:'monitor $literal',microphone:'mic " literal'},directory,encoderArguments,new Date(2026,9,17,12,34,56));
assert.equal(options.filename,directory+'/Recording 2026-10-17 at 12h34m56s.mp4');
assert.ok(options.command.includes('--audio=monitor $literal'));assert.deepEqual(options.loopback,['module-loopback','source=mic " literal','sink=output $(literal)']);
assert.deepEqual(options.command.slice(0,4),['wf-recorder','--no-damage','--geometry','-10,20 300x200']);
for(const [key,value] of [['fps',120],['geometry','invalid'],['audio','unknown']])assert.throws(()=>prepared({capture:'region',geometry:'0,0 1x1',fps:60,audio:'none',[key]:value},directory,encoderArguments));
assert.ok(options.command.includes('libx264') && options.command.includes('preset=veryfast'));
assert.ok(!options.command.includes('hevc_nvenc'));
assert.deepEqual(options.command.slice(4,10),[...encoderArguments,'--framerate','30']);
assert.deepEqual(encoderArguments,['--codec','libx264','--codec-param','preset=veryfast']);
for(const argumentsValue of [null,'--codec', [42]])assert.throws(()=>prepared({capture:'output',output:'DP-1',fps:60,audio:'none'},directory,argumentsValue));
assert.throws(()=>deviceRows({},[],'default'));
console.log('PASS: recording command quality settings, filename format, literal paths/audio identities and option validation');
JS
# Reload only while choosing options: fresh setup must be idle, with no worker handoff.
cat > "$fixture/reload.qml" <<'QML'
import QtQuick
import Quickshell
import Quickshell.Io
import "src/services"
import "src/services/recording"
import "src/modules/launcher"
Scope {
    id: root
    property int ticks: 0
    RecordingSetup { id: setup; onPrepared: { console.error("SETUP FAIL: unexpected handoff"); Qt.quit() } }
    FloatingWindow { visible: true; implicitWidth:640; implicitHeight:400; PickerPanel { anchors.fill:parent } }
    FileView { id: phase; path: Quickshell.env("RECORD_SETUP_TEST")+"/reload-state"; preload:false; blockLoading:true; blockWrites:true; printErrors:false }
    Timer {
        interval:25; running:true; repeat:true
        onTriggered: {
            if (++root.ticks>160) { console.error("SETUP FAIL: setup reload timed out"); Qt.quit(); return }
            if (!DbService.ready) return
            phase.reload()
            switch (phase.text().trim()) {
              case "": setup.open(); phase.setText("open"); break
              case "open":
                if (!CaptureMenuService.visible || !setup.active) return
                CaptureMenuService.query = "reg"
                phase.setText("reloaded")
                stop() // The old generation must not validate the new generation while it loads.
                Qt.callLater(()=>Quickshell.reload(true))
                break
              case "reloaded":
                if (setup.active || CaptureMenuService.visible) { console.error("SETUP FAIL: unfinished choices survived reload"); Qt.quit(); return }
                console.log("PASS: config reload cancels unfinished native recording setup without handing options to a worker")
                stop(); Qt.quit()
            }
        }
    }
}
QML
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 QS_NO_RELOAD_POPUP=1 \
    HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/r" XDG_DATA_HOME="$fixture/reload-data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 1 10 "$qs_bin" -p "$fixture/reload.qml" > "$fixture/reload-log" 2>&1 || { cat "$fixture/reload-log"; exit 1; }
if ! rg -q 'PASS: config reload cancels' "$fixture/reload-log" || rg -q 'SETUP FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/reload-log"; then cat "$fixture/reload-log"; exit 1; fi
rg 'PASS:' "$fixture/reload-log"
