#!/usr/bin/env bash
# Native wallpaper flow and retained offline executor, with synthetic images/tools only.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
qs_bin=$(command -v qs)
native_hyprctl=$(command -v hyprctl)
desktop_runtime=${XDG_RUNTIME_DIR:-}
native_display=${WAYLAND_DISPLAY:-}
original_window=""
real_find=$(command -v find)
test_dir=$(mktemp -d /tmp/qsw.XXXXXXXX)
cleanup() {
    result=$?
    if ((result != 0)); then [[ ! -f $test_dir/commands ]] || cat "$test_dir/commands" >&2; fi
    rm -rf -- "$test_dir"
    if [[ $original_window =~ ^0x[0-9a-fA-F]+$ ]]; then
        XDG_RUNTIME_DIR="$desktop_runtime" "$native_hyprctl" dispatch "hl.dsp.focus({ window = \"address:$original_window\" })" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT
mkdir -m700 "$test_dir/r" "$test_dir/home" "$test_dir/bin"
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$test_dir" -xf -
export HOME="$test_dir/home" XDG_RUNTIME_DIR="$test_dir/r" WALL_TEST_DIR="$test_dir" WALL_TEST_FIND="$real_find"
export XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache"
export QS_PICKER_CONFIG="$test_dir" QS_PICKER_EXECUTABLE="$test_dir/bin/qs"
export PATH="$test_dir/bin:$PATH"
folder="$HOME/Pictures/wallpapers"
state="$HOME/Pictures/.runtime"
mkdir -p "$folder/nested" "$folder/empty"
image="$folder/quote ' \" \$(touch injected) #%.PNG"
second_image="$folder/nested/second"$'\n'"line.jpg"
magick -size 64x32 xc:red "$image"
magick -size 32x64 xc:blue "$second_image"
magick -size 32x32 xc:green "$folder/animation.gif"
# Enough matching rows to place the selected image below the initial viewport.
for index in {01..30}; do cp -- "$image" "$folder/filler-$index.png"; done
touch "$folder/ignored.mp4" "$folder/ignored.txt"
ln -s "$folder" "$HOME/Pictures/linked-images"
printf '%s\n' '[{"name":"DP-1","description":"Main","focused":false},{"name":"HDMI-A-1","description":"Second","focused":true},{"name":"eDP-1","description":"Laptop"}]' > "$test_dir/monitors"
printf '{}\n' > "$test_dir/control"
printf 'touch %q\n' "$test_dir/old-env-executed" > "$test_dir/src/services/launcher/providers/wallpaper.env"
cat > "$test_dir/bin/qs" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${WALL_TEST_NATIVE:-0} == 1 ]]; then
    printf 'unexpected native IPC\n' >> "$WALL_TEST_DIR/ipc"
    exit 2
fi
if [[ ${6:-} == providerConfig ]]; then
    touch "$WALL_TEST_DIR/config-read"
    [[ ${WALL_TEST_CONFIG_FAIL:-0} == 0 ]] || exit 2
    jq -nc --arg state "${WALL_TEST_STATE-$HOME/Pictures/.runtime}" --arg home "$HOME" \
        '{SCREENSHOT_FOLDER:($home+"/Pictures"),VIDEOS_FOLDER:($home+"/Videos"),
          WALLPAPER_DIRECTORY:($home+"/Pictures/wallpapers"),WALLPAPER_STATE_DIRECTORY:$state,
          WORKING_STATE_NAME:"work",WORK_MODE_ENABLED:env.WALL_TEST_WORK_MODE // "true"}'
elif [[ ${5:-} == alerts ]]; then
    jq -nc --arg message "$8" --arg kind "${10}" '{message:$message,kind:$kind}' >> "$WALL_TEST_DIR/alerts"
elif [[ ${1:-} == -p ]]; then
    exit 2
else
    printf 'unexpected executor IPC\n' >> "$WALL_TEST_DIR/ipc"
    exit 2
fi
MOCK
cat > "$test_dir/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == monitors ]] || { printf '[]\n'; exit 0; }
[[ ${WALL_TEST_MONITORS_FAIL:-0} == 0 ]] || exit 1
jq -e '.monitorFail != true' "$WALL_TEST_DIR/control" >/dev/null || exit 1
if jq -e '.monitorSlow == true' "$WALL_TEST_DIR/control" >/dev/null; then sleep 0.2; fi
if jq -e '.monitorInvalid == true' "$WALL_TEST_DIR/control" >/dev/null; then printf 'invalid\n'; else cat "$WALL_TEST_DIR/monitors"; fi
MOCK
cat > "$test_dir/bin/find" <<'MOCK'
#!/usr/bin/env bash
if jq -e '.scanSlow == true' "$WALL_TEST_DIR/control" >/dev/null; then exec sleep 10; fi
exec "$WALL_TEST_FIND" "$@"
MOCK
cat > "$test_dir/bin/awww" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ $1 == img ]] && jq -e '.applySlow == true' "$WALL_TEST_DIR/control" >/dev/null; then sleep 0.2; fi
jq -nc --args '$ARGS.positional' -- "$@" >> "$WALL_TEST_DIR/commands"
if [[ $1 == query ]]; then
    count=0
    [[ ! -f $WALL_TEST_DIR/query-count ]] || count=$(<"$WALL_TEST_DIR/query-count")
    printf '%s' "$((count+1))" > "$WALL_TEST_DIR/query-count"
    [[ $count -ge ${WALL_TEST_QUERY_FAILURES:-0} ]]
else
    [[ ${WALL_TEST_APPLY_FAIL:-0} == 0 ]]
    jq -e '.applyFail != true' "$WALL_TEST_DIR/control" >/dev/null
fi
MOCK
chmod +x "$test_dir/bin/"*
node - "$test_dir" "$folder" "$state" <<'CONFIG'
const fs=require('fs'),[fixture,folder,state]=process.argv.slice(2),file=fixture+'/src/config/Config.qml';
let text=fs.readFileSync(file,'utf8').replace('clipboardMonitorEnabled: true','clipboardMonitorEnabled: false');
for(const [name,value]of Object.entries({wallpaperDirectory:folder,wallpaperStateDirectory:state}))
 text=text.replace(new RegExp('(readonly property string '+name+':)[^\\n]*'),(_,prefix)=>prefix+' '+JSON.stringify(value));
text=text.replace('workModeEnabled: true','workModeEnabled: Quickshell.env("WALL_TEST_WORK_MODE") !== "false"');
text=text.replace('pickerRememberSelection: true','pickerRememberSelection: Quickshell.env("WALL_TEST_REMEMBER") === "1"');
fs.writeFileSync(file,text);
CONFIG
# Preview policy needs only passive capture state, not a live audio server.
cat > "$test_dir/src/services/audio/AudioService.qml" <<'QML'
pragma Singleton
import QtQml
QtObject { readonly property bool screencastActive: false }
QML
if [[ ${WALLPAPER_TEST_NATIVE:-0} == 1 ]]; then
    [[ -n $native_display ]] || { printf 'Native wallpaper check requires Wayland\n'; exit 1; }
    [[ $native_display == /* ]] || native_display="$desktop_runtime/$native_display"
    ln -s "$desktop_runtime/hypr" "$test_dir/r/hypr"
    original_window=$(XDG_RUNTIME_DIR="$desktop_runtime" "$native_hyprctl" activewindow -j | jq -r '.address // ""')
    sed 's@"../../src@"src@g' "$project_root/tests/launcher/wallpaper-focus.qml" > "$test_dir/shell.qml"
    cp "$project_root/tests/launcher/NativeFocusDriver.qml" "$test_dir/NativeFocusDriver.qml"
    WALL_TEST_WORK_MODE=true WALL_TEST_REMEMBER=0 WALL_TEST_NATIVE=1 QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$native_display" \
        timeout -k 1 12 "$qs_bin" -p "$test_dir" > "$test_dir/log" 2>&1 || { cat "$test_dir/log"; exit 1; }
    if ! rg -q 'PASS: native Wallpaper' "$test_dir/log" || rg -q 'WALLPAPER NATIVE FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$test_dir/log"; then
        cat "$test_dir/log"; exit 1
    fi
    rg 'PASS:' "$test_dir/log"
    if [[ ${FOCUS_TEST_TRACE:-0} == 1 ]]; then cat "$test_dir/log"; fi
    exit
fi
sed 's@"../../src@"src@g' "$project_root/tests/launcher/wallpaper.qml" > "$test_dir/shell.qml"
for setting in 'true 1' 'false 0'; do
    read -r WALL_TEST_WORK_MODE WALL_TEST_REMEMBER <<< "$setting"
    export WALL_TEST_WORK_MODE WALL_TEST_REMEMBER
    rm -f "$test_dir/commands"
    env -u WAYLAND_DISPLAY WALL_TEST_NATIVE=1 QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
        timeout -k 1 20 "$qs_bin" -p "$test_dir" > "$test_dir/log" 2>&1 || { cat "$test_dir/log"; exit 1; }
    if ! rg -q 'PASS: native Wallpaper' "$test_dir/log" || rg -q 'WALLPAPER FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$test_dir/log"; then
        cat "$test_dir/log"; exit 1
    fi
    rg 'PASS:' "$test_dir/log"
    [[ ! -e $test_dir/ipc && ! -e $test_dir/config-read ]]
done
unset WALL_TEST_WORK_MODE WALL_TEST_REMEMBER
picker="$test_dir/src/services/launcher/launcher.sh"
reset_actions() { rm -f "$test_dir/commands" "$test_dir/alerts" "$test_dir/query-count" "$test_dir/config-read"; printf '{}\n' > "$test_dir/control"; }
check_cleanup() { [[ -z $("$real_find" "$test_dir/r" -maxdepth 1 -name 'wallpaper.*' -print -quit) ]]; }
expect_error() { jq -se 'length == 1 and .[0].kind == "error"' "$test_dir/alerts" >/dev/null; check_cleanup; }

# Retain CLI/offline setter contracts, independently of native UI orchestration.
for mode in personal work; do
    reset_actions
    bash "$picker" provider wallpaper set DP-1 "$mode" "$image"
    [[ $(readlink "$state/wallpaper_${mode}_1") == "$image" && -f $test_dir/config-read ]]
    jq -se --arg image "$image" '. == [["img",$image,"--outputs","DP-1","--transition-type","any","--transition-duration","2"]]' "$test_dir/commands" >/dev/null
    jq -se 'length == 1 and .[0].kind == "success"' "$test_dir/alerts" >/dev/null
    check_cleanup
done
bash "$picker" provider wallpaper set 2 personal "$second_image"
[[ $(readlink "$state/wallpaper_personal_2"; printf '.') == "$second_image"$'\n.' ]]
bash "$picker" provider wallpaper set eDP-1 work "$image"
[[ $(readlink "$state/wallpaper_work_eDP-1") == "$image" ]]
trailing="$test_dir/trailing.png"$'\n'
touch "$trailing"
bash "$picker" provider wallpaper set 2 work "$trailing"
[[ $(readlink "$state/wallpaper_work_2"; printf '.') == "$trailing"$'\n.' ]]
printf 'PASS: retained setter preserves literal/trailing-newline paths, legacy numeric slots and additional outputs\n'

reset_actions
before=$(readlink "$state/wallpaper_personal_1")
if WALL_TEST_APPLY_FAIL=1 bash "$picker" provider wallpaper set DP-1 personal "$second_image" 2> "$test_dir/error"; then exit 1; fi
[[ $(readlink "$state/wallpaper_personal_1") == "$before" ]]
expect_error
for arguments in 'DP-1 invalid' 'missing personal'; do
    reset_actions
    read -r output mode <<< "$arguments"
    if bash "$picker" provider wallpaper set "$output" "$mode" "$image" 2> "$test_dir/error"; then exit 1; fi
    [[ ! -f $test_dir/commands ]]
    expect_error
done
reset_actions
if WALL_TEST_MONITORS_FAIL=1 bash "$picker" provider wallpaper set DP-1 personal "$image" 2> "$test_dir/error"; then exit 1; fi
[[ ! -f $test_dir/commands ]]
expect_error
printf 'PASS: failed application, invalid mode, disconnected monitor and monitor failure preserve saved links\n'

reset_actions
WALL_TEST_QUERY_FAILURES=2 bash "$picker" provider wallpaper restore personal
jq -se --arg state "$state" 'map(select(.[0]=="img")) == [
    ["img",$state+"/wallpaper_personal_2","--outputs","HDMI-A-1","--transition-type","any","--transition-duration","0.5"],
    ["img",$state+"/wallpaper_personal_1","--outputs","DP-1","--transition-type","any","--transition-duration","0.5"]]' "$test_dir/commands" >/dev/null
[[ $(<"$test_dir/query-count") == 3 && -f $test_dir/config-read && ! -f $test_dir/alerts ]]
check_cleanup
reset_actions
bash "$picker" provider wallpaper restore work
jq -se 'map(select(.[0]=="img")) | length==3 and .[2][3]=="eDP-1"' "$test_dir/commands" >/dev/null
reset_actions
if WALL_TEST_QUERY_FAILURES=1000 bash "$picker" provider wallpaper restore personal 2> "$test_dir/error"; then exit 1; fi
jq -se 'all(.[]; .[0]=="query")' "$test_dir/commands" >/dev/null
expect_error
printf 'PASS: offline restore waits for daemon, restores per-mode/output slots, skips unset slots and reports failure\n'

reset_actions
WALL_TEST_STATE="$test_dir/custom-state" bash "$picker" provider wallpaper set DP-1 personal "$image"
[[ $(readlink "$test_dir/custom-state/wallpaper_personal_1") == "$image" ]]
reset_actions
WALL_TEST_WORK_MODE=false bash "$picker" provider wallpaper set DP-1 work "$second_image"
[[ $(readlink "$state/wallpaper_personal_1"; printf '.') == "$second_image"$'\n.' ]]
jq -se 'length == 1 and .[0].message == "wallpaper.status.savedOutput"' "$test_dir/alerts" >/dev/null
reset_actions
if WALL_TEST_CONFIG_FAIL=1 bash "$picker" provider wallpaper restore personal 2> "$test_dir/error"; then exit 1; fi
[[ ! -f $test_dir/commands ]]
expect_error
[[ ! -e $test_dir/ipc && ! -e $test_dir/old-env-executed ]]
printf 'PASS: custom Config storage, optional work mode, configuration errors and obsolete-env isolation remain supported\n'
