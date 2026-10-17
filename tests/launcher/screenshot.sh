#!/usr/bin/env bash
# All capture, clipboard, editor and desktop actions are synthetic.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qsc.XXXXXX)
previous_window=''
cleanup() {
    if [[ -n $previous_window ]]; then /usr/bin/hyprctl dispatch "hl.dsp.focus({ window = \"address:$previous_window\" })" >/dev/null 2>&1 || true; fi
    rm -rf -- "$fixture"
}
trap cleanup EXIT
mkdir -m700 "$fixture/bin" "$fixture/r"
original_runtime=${XDG_RUNTIME_DIR:-}
original_display=${WAYLAND_DISPLAY:-}
export CAPTURE_TEST_DIR=$fixture XDG_RUNTIME_DIR=$fixture/r
export PATH="$fixture/bin:$PATH"
cat > "$fixture/bin/tool" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
name=${0##*/}
printf '%s %s\n' "$name" "$*" >> "$CAPTURE_TEST_DIR/actions"
case $name in
    hyprpicker)
        printf '%s' "$$" > "$CAPTURE_TEST_DIR/freezer-pid"
        exec /usr/bin/sleep 30 ;;
    slurp)
        printf '%s' "$" > "$CAPTURE_TEST_DIR/selector-pid"
        # Like real slurp, finish reading optional rectangles before showing anything.
        if [[ $1 == -r ]]; then cat > "$CAPTURE_TEST_DIR/boxes"; else cat > "$CAPTURE_TEST_DIR/selector-stdin"; fi
        case ${CAPTURE_TEST_MODE:-} in
            cancel) echo "selection cancelled" >&2; exit 1 ;; failOne) echo "failed to create display" >&2; exit 1 ;; fail) exit 2 ;; timeout) exit 124 ;;
            slow) exec /usr/bin/sleep 30 ;; invalid) echo 'bad geometry'; exit ;;
        esac
        if [[ $1 == -r ]]; then echo '-100,10 1400x900'
        else echo '10,20 300x200'; fi ;;
    grim)
        [[ ${CAPTURE_TEST_MODE:-} != grimFail ]] || exit 1
        printf 'synthetic PNG\n' ;;
    tesseract|zbarimg)
        cat > "$CAPTURE_TEST_DIR/decoded-input"
        case ${CAPTURE_TEST_MODE:-} in
            decodeFail) exit 2 ;; empty) [[ $name == zbarimg ]] && exit 4; exit 0 ;;
        esac
        printf '%s' "${CAPTURE_TEST_TEXT:-Olá 日本語 \"quoted\"}" ;;
    wl-copy)
        [[ ${CAPTURE_TEST_MODE:-} != copyFail ]] || exit 1
        cat > "$CAPTURE_TEST_DIR/clipboard" ;;
    satty)
        input=''; output=''
        while (($#)); do case $1 in --filename) input=$2; shift ;; --output-filename) output=$2; shift ;; esac; shift; done
        [[ -s $input ]] || exit 2
        case ${CAPTURE_TEST_MODE:-} in editorCancel) exit 0 ;; editorFail) exit 2 ;; editorSlow) /usr/bin/sleep 1 ;; esac
        cat "$input" > "$output" ;;
    hyprctl)
        case ${2:-} in
            monitors) echo '[{"x":0,"y":0,"width":1920,"height":1080,"scale":1.5,"transform":0,"activeWorkspace":{"id":1},"specialWorkspace":{"id":-99}}]' ;;
            clients) echo '[{"at":[-100,10],"size":[1400,900],"workspace":{"id":1},"mapped":true},{"at":[0,0],"size":[30,30],"workspace":{"id":2},"mapped":true}]' ;;
        esac ;;
    qs)
        if [[ ${6:-} == providerConfig ]]; then
            jq -nc --arg folder "$CAPTURE_TEST_DIR/offline" '{SCREENSHOT_FOLDER:$folder,VIDEOS_FOLDER:"/unused",WALLPAPER_DIRECTORY:"/unused",WALLPAPER_STATE_DIRECTORY:"/unused",WORKING_STATE_NAME:"personal",WORK_MODE_ENABLED:"false"}'
        fi ;;
    dbus-send) printf "revealed\n" > "$CAPTURE_TEST_DIR/revealed" ;;
    notify-send|hyprshot|pkill|pgrep) exit 99 ;;
esac
MOCK
chmod +x "$fixture/bin/tool"
for tool in hyprpicker slurp grim tesseract zbarimg wl-copy satty hyprctl qs dbus-send notify-send hyprshot pkill pgrep; do ln -s tool "$fixture/bin/$tool"; done
node - "$repo_dir" "$fixture" <<'NODE'
const fs=require('fs'), cp=require('child_process'), assert=require('assert/strict');
const [repo,fixture]=process.argv.slice(2), worker=repo+'/src/services/launcher/providers/screenshot.sh';
const destination=fixture+'/Shots "quoted" $literal', config=fixture;
function wait(predicate,message) { const deadline=Date.now()+3000;while(!predicate()&&Date.now()<deadline)Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,15);assert.ok(predicate(),message); }
function actions(){return fs.readFileSync(fixture+'/actions','utf8');}
function run(method,mode='',text='Olá 日本語 "quoted"\nsecond line\n') {
 fs.writeFileSync(fixture+'/actions','');fs.rmSync(fixture+'/revealed',{force:true});
 const result=cp.spawnSync('bash',[worker,'--prepared',method,destination,config],{encoding:'utf8',timeout:5000,env:{...process.env,CAPTURE_TEST_MODE:mode,CAPTURE_TEST_TEXT:text}});
 assert.equal(result.error,undefined);assert.equal(result.stderr,'');
 return {result,reply:JSON.parse(result.stdout)};
}
for(const method of ['ocr','qrcode']) {
 const text='literal $(touch injected) `quoted` $HOME\nOlá 日本語\n\n';
 const {result,reply}=run(method,'',text);assert.equal(result.status,0);assert.equal(reply.status,'ready');assert.equal(reply.text,text);
 assert.equal(fs.readFileSync(fixture+'/clipboard','utf8'),text);assert.equal(fs.readFileSync(fixture+'/decoded-input','utf8'),'synthetic PNG\n');
 assert.ok(actions().includes(method==='ocr'?'tesseract stdin stdout -l por':'zbarimg --raw -q -'));
 assert.equal(run(method,'empty').reply.status,'empty');
 for(const mode of ['cancel','failOne','fail','timeout','invalid','grimFail','decodeFail','copyFail']) {
  fs.writeFileSync(fixture+'/clipboard','keep');
  const {reply}=run(method,mode);assert.equal(reply.status,mode==='cancel'?'cancelled':'error',mode);
  assert.equal(fs.readFileSync(fixture+'/clipboard','utf8'),'keep');
  if(['cancel','failOne','fail','timeout','invalid','grimFail'].includes(mode))assert.ok(!/tesseract |zbarimg |satty |wl-copy /.test(actions()),'no downstream tools after '+mode);
 }
}
for(const method of ['region','output','window']) {
 const {result,reply}=run(method);assert.equal(result.status,0);assert.equal(reply.status,'editing');
 wait(()=>fs.existsSync(fixture+'/revealed'),'saved capture reveals folder');
 assert.ok(actions().includes('alerts postMessage screenshot screenshot.status.saved'));
 if(method==='window') {
  assert.equal(fs.readFileSync(fixture+'/boxes','utf8'),'-100,10 1400x900\n');
  assert.ok(actions().includes('grim -g 0,10 1280x710 -'),'logical window clipping');
 }
}
// Closing without saving leaves neither an empty reserved file nor a false success alert.
for(const mode of ['editorCancel','editorFail']) {
 const before=fs.readdirSync(destination).length;run('region',mode);
 wait(()=>fs.readdirSync(fixture+'/r').filter(p=>p.startsWith('quickshell-capture.')).length===0,'annotation cleanup');
 assert.equal(fs.readdirSync(destination).length,before);assert.ok(!fs.existsSync(fixture+'/revealed'));
 assert.equal(actions().includes('screenshot.errors.editor'),mode==='editorFail');
}
const invalid=fixture+'/unrelated-directory';fs.mkdirSync(invalid);fs.writeFileSync(invalid+'/capture.png','keep');
const rejected=cp.spawnSync('bash',[worker,'--annotate',invalid,destination,config],{encoding:'utf8',env:process.env});
assert.equal(rejected.status,2);assert.equal(fs.readFileSync(invalid+'/capture.png','utf8'),'keep');
const offline=cp.spawnSync('bash',[worker,'ocr'],{encoding:'utf8',env:process.env,timeout:5000});assert.equal(offline.status,0);assert.equal(JSON.parse(offline.stdout).status,'ready');
console.log('PASS: owned capture methods, Portuguese OCR, QR results, literal clipboard, cancellation/errors, unique saves, editor cleanup and offline Config');
NODE
node - "$repo_dir" "$fixture" <<'NODE'
const fs=require('fs'),cp=require('child_process'),assert=require('assert/strict');
const [repo,fixture]=process.argv.slice(2), worker=repo+'/src/services/launcher/providers/screenshot.sh';
const delay=ms=>new Promise(r=>setTimeout(r,ms));
const alive=pid=>{try {process.kill(pid,0);const stat=fs.readFileSync('/proc/'+pid+'/stat','utf8');return !/\) Z /.test(stat);}catch{return false;}};
(async()=>{
 const unrelated=cp.spawn('hyprpicker',['-r','-z'],{stdio:'ignore'});
 try {
  await delay(40);fs.rmSync(fixture+'/selector-pid',{force:true});
  const child=cp.spawn('bash',[worker,'--prepared','ocr',fixture+'/save',fixture],{env:{...process.env,CAPTURE_TEST_MODE:'slow'},stdio:'ignore'});
  const done=new Promise(r=>child.once('exit',r));
  for(let i=0;i<120&&!fs.existsSync(fixture+'/selector-pid');i++)await delay(10);
  assert.ok(fs.existsSync(fixture+'/selector-pid'));
  const selector=Number(fs.readFileSync(fixture+'/selector-pid')),freezer=Number(fs.readFileSync(fixture+'/freezer-pid'));
  child.kill('SIGTERM');await done;await delay(40);
  assert.ok(!alive(selector)&&!alive(freezer),'owned selector/freezer terminated');assert.ok(alive(unrelated.pid),'unrelated freezer survives');
  console.log('PASS: cancellation stops owned process groups and preserves unrelated capture tools');
 } finally {unrelated.kill('SIGTERM');}
})().catch(error=>{console.error(error);process.exitCode=1});
NODE
# Run the production service, menu and presentation tracker offscreen with synthetic tools.
qs_bin=$(command -v /usr/bin/qs)
real_hyprctl=/usr/bin/hyprctl
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/;s/readonly property bool animationsEnabled:.*/readonly property bool animationsEnabled: true/' "$fixture/src/config/Config.qml"
sed -i 's/readonly property bool screencastActive:.*/property bool screencastActive: false/' "$fixture/src/services/audio/AudioService.qml"
sed 's@"../../src@"src@g' "$repo_dir/tests/launcher/screenshot.qml" > "$fixture/shell.qml"
platform=offscreen
if [[ ${SCREENSHOT_TEST_NATIVE:-0} == 1 ]]; then
    ln -s "$original_runtime/hypr" "$fixture/r/hypr"
    previous_window=$("$real_hyprctl" activewindow -j | jq -r '.address // empty')
    node - "$fixture/shell.qml" <<'NODE_NATIVE'
const fs=require('fs'),p=process.argv[2];let s=fs.readFileSync(p,'utf8');
s=s.replace('import Quickshell\n','import Quickshell\nimport Quickshell.Wayland\nimport "src/modules/launcher"\n');
const start=s.indexOf('    component Surface:'),end=s.indexOf('    function check(',start);
s=s.slice(0,start)+`    PickerWindow { id: picker }
    PrivatePickerWindow {}
    SubmapWindow { id: submap; requestedVisible: root.submapRequested }
    AlertWindow { id: notice }
    TopPanelTooltip {
        id: other
        requestedVisible: root.otherPanelRequested
        contentWidth: 100; contentHeight: 100
        mask: Region { width: 0; height: 0 }
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    }
`+s.slice(end);fs.writeFileSync(p,s);
NODE_NATIVE
    # An absolute display path keeps the fixture's private runtime/storage intact.
    display=$original_display
    [[ $display == /* ]] || display=$original_runtime/$display
    export WAYLAND_DISPLAY=$display
    platform=wayland
fi
env QT_QPA_PLATFORM="$platform" QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 QS_NO_RELOAD_POPUP=1 \
    HOME="$fixture/home" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 1 15 "$qs_bin" -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: native screenshot' "$fixture/log" || rg -q 'CAPTURE FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
# The annotation worker must finish independently after a real Quickshell reload.
# The real picker was exercised above. This windowless test needs only closure:
# avoid constructing unrelated ClipboardSearchSession WorkerScripts during reload.
cat > "$fixture/src/services/launcher/PickerService.qml" <<'PICKER_MOCK'
pragma Singleton
import QtQml
QtObject {
    signal opened()
    function close() {}
}
PICKER_MOCK
rm -f -- "$fixture/revealed"
cat > "$fixture/reload.qml" <<'QML'
import QtQml
import Quickshell
import Quickshell.Io
import "src/services"
Scope {
    property int ticks: 0
    FileView { id: phase; path: Quickshell.env("CAPTURE_TEST_DIR") + "/reload-phase"; preload: false; blockLoading: true; blockWrites: true; printErrors: false }
    FileView { id: revealed; path: Quickshell.env("CAPTURE_TEST_DIR") + "/revealed"; preload: false; blockLoading: true; printErrors: false }
    Timer {
        interval: 25; running: true; repeat: true
        onTriggered: {
            if (++ticks > 160) { console.error("CAPTURE FAIL: annotation did not survive reload"); Qt.quit(); return }
            if (!DbService.ready) return
            phase.reload()
            switch (phase.text().trim()) {
              case "":
                phase.setText("capturing")
                ScreenshotService.open("region")
                break
              case "capturing":
                if (ScreenshotService.busy) return
                phase.setText("reloaded")
                Qt.callLater(() => Quickshell.reload(true))
                break
              case "reloaded":
                revealed.reload()
                if (!revealed.text().trim()) return
                console.log("PASS: detached screenshot annotation survives actual bar reload and reveals its saved file")
                stop()
                Qt.quit()
            }
        }
    }
}
QML
# A sufficiently long editor delay makes the reload precede its eventual save.
CAPTURE_TEST_MODE=editorSlow env QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 QS_NO_RELOAD_POPUP=1 \
    HOME="$fixture/home" XDG_DATA_HOME="$fixture/reload-data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 1 8 "$qs_bin" -p "$fixture/reload.qml" > "$fixture/reload-log" 2>&1 || { cat "$fixture/reload-log"; exit 1; }
if ! rg -q 'PASS: detached screenshot' "$fixture/reload-log" || rg -q 'CAPTURE FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/reload-log"; then
    cat "$fixture/reload-log"; exit 1
fi
rg 'PASS:' "$fixture/reload-log"
