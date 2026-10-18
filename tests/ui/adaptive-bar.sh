#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-adaptive.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/r"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
node --input-type=module - "$repo" <<'JS'
import assert from 'node:assert/strict';
const colors = await import(process.argv[2] + '/src/services/ui/AdaptiveColors.mjs');
assert.ok(Math.abs(colors.contrast('#ffffff','#000000') - 21) < 0.001);
assert.ok(colors.readable('#08121c','#000000','#d8dadc',['#6B8FB3','#B80F0A','#3E8E5A'],.15));
assert.ok(!colors.readable('#ffffff','#000000','#d8dadc',['#6B8FB3']));
assert.ok(!colors.readable('invalid','#000000','#d8dadc',[]));
assert.ok(colors.readable('#242424','#000000','#d8dadc',['#b8b9bb','#6B8FB3'],.15));
assert.ok(!colors.readable('#242424','#000000','#d8dadc',['#b8b9bb','#6B8FB3','#B80F0A'],.15));
const windows = [{monitor:1,workspace:{id:3},floating:false},{monitor:2,workspace:{id:8},floating:true}];
assert.ok(colors.hasTiledWindow(windows,1,3));
assert.ok(!colors.hasTiledWindow(windows,2,8));
assert.ok(!colors.hasTiledWindow(windows,1,4));
assert.ok(colors.hasTiledWindow([{monitor:2,workspace:{id:-1},floating:false}],2,8,-1));
assert.ok(!colors.hasTiledWindow([{monitor:2,workspace:{id:8},floating:false,hidden:true}],2,8));
console.log('PASS: adaptive contrast, monitor/workspace isolation and special/hidden window classification');
JS
mkdir "$fixture/bin"
cat > "$fixture/bin/grim" <<'MOCK'
#!/usr/bin/env bash
for argument in "$@"; do [[ $argument != -o ]] || { printf 'Output and region options are mutually exclusive\n' >&2; exit 1; }; done
printf '%s\n' "$*" > "$ADAPTIVE_TEST_DIR/capture-arguments"
printf 'P6\n3 1\n255\n\x24\x24\x24\xff\xff\xff\x24\x24\x24'
MOCK
chmod +x "$fixture/bin/grim"
sample=$(ADAPTIVE_TEST_DIR="$fixture" PATH="$fixture/bin:$PATH" bash "$repo/src/services/ui/adaptive-color.sh" fixture -1000 71 1000 12)
[[ ${sample,,} == '#242424' ]]
[[ $(cat "$fixture/capture-arguments") == '-g -1000,71 1000x12 -s 1 -t ppm -' ]]
printf 'PASS: strip capture geometry and most frequent color use only in-memory synthetic pixels\n'
cat > "$fixture/sample" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ADAPTIVE_TEST_DIR/requests"
color=$(cat "$ADAPTIVE_TEST_DIR/$1.color")
[[ ! -f $ADAPTIVE_TEST_DIR/delay ]] || sleep 0.2
printf '%s\n' "$color"
MOCK
chmod +x "$fixture/sample"
printf '#000000\n' > "$fixture/fixture.color"
node - "$fixture" <<'JS'
const fs=require('node:fs'), dir=process.argv[2], file=dir+'/src/config/Config.qml';
fs.writeFileSync(file,fs.readFileSync(file,'utf8')
    .replace(/readonly property bool adaptiveBarEnabled: (?:true|false)/,'property bool adaptiveBarEnabled: false')
    .replace(/readonly property var adaptiveBarSampleCommand:.*/,()=> 'readonly property var adaptiveBarSampleCommand: '+JSON.stringify([dir+'/sample']))
    .replace('clipboardMonitorEnabled: true','clipboardMonitorEnabled: false'));
JS
# No notification server or real notifications in the sampling obstruction test.
printf 'pragma Singleton\nimport Quickshell\nSingleton { property var popups: [] }\n' > "$fixture/src/services/notifications/NotificationService.qml"
sed 's@"../../src@"src@g' "$repo/tests/ui/adaptive-bar.qml" > "$fixture/shell.qml"
if [[ -n ${ADAPTIVE_PREVIEWS:-} ]]; then mkdir -p -- "$ADAPTIVE_PREVIEWS"; fi
platform=(env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software)
if [[ ${ADAPTIVE_NATIVE:-0} == 1 ]]; then
    display=${WAYLAND_DISPLAY:?A native Wayland session is required}
    [[ $display == /* ]] || display=${XDG_RUNTIME_DIR:?}/$display
    # This fixture only paints synthetic surfaces and never requests keyboard focus.
    sed -i '1a import Quickshell.Wayland' "$fixture/shell.qml"
    sed -i 's/FloatingWindow {/PanelWindow { WlrLayershell.keyboardFocus: WlrKeyboardFocus.None; exclusiveZone: 0; anchors.top: true; anchors.left: true; margins.top: 100;/' "$fixture/shell.qml"
    platform=(env -u QT_QUICK_BACKEND QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display")
fi
"${platform[@]}" \
    ADAPTIVE_TEST_DIR="$fixture" XDG_RUNTIME_DIR="$fixture/r" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout 12 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: adaptive bar' "$fixture/log" || rg -q 'ADAPTIVE FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
