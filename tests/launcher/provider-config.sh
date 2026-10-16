#!/usr/bin/env bash
# Real QML configuration exports with no running bar, UI, clipboard or desktop actions.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-provider-config.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
cp "$project_root/provider-config.qml" "$fixture/"
mkdir -m 700 "$fixture/runtime"
mkdir "$fixture/home"
export HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/runtime"
export XDG_DATA_HOME="$fixture/xdg-data" XDG_CACHE_HOME="$fixture/cache"
export QT_QPA_PLATFORM=offscreen QT_NO_XDG_DESKTOP_PORTAL=1
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE QS_PICKER_EXECUTABLE
export QS_PICKER_CONFIG="$fixture"
picker="$fixture/src/services/launcher/launcher.sh"
node - "$fixture" <<'JS'
const fs = require('fs'), root = process.argv[2], file = root + '/src/config/Config.qml';
const expected = {
    SCREENSHOT_FOLDER: root + '/screenshots "quoted" $(touch ' + root + '/injected)\nnext line',
    VIDEOS_FOLDER: root + '/recordings with spaces',
    WALLPAPER_DIRECTORY: root + '/images', WALLPAPER_STATE_DIRECTORY: root + '/saved images',
    WORKING_STATE_NAME: 'fixture-work'
};
const mapping = {screenshotDirectory:'SCREENSHOT_FOLDER',recordingDirectory:'VIDEOS_FOLDER',
    wallpaperDirectory:'WALLPAPER_DIRECTORY',wallpaperStateDirectory:'WALLPAPER_STATE_DIRECTORY',pickerWorkStatus:'WORKING_STATE_NAME'};
let source = fs.readFileSync(file, 'utf8');
for (const [property, key] of Object.entries(mapping))
    source = source.replace(new RegExp('(readonly property string '+property+':)[^\\n]*'),
        (_, declaration) => declaration + ' ' + JSON.stringify(expected[key]));
fs.writeFileSync(file, source);
fs.writeFileSync(root + '/expected.json', JSON.stringify(expected));
JS
bash "$picker" --provider-config > "$fixture/offline.json"
jq -es '.[0] == .[1]' "$fixture/expected.json" "$fixture/offline.json" >/dev/null
[[ ! -e $fixture/data && ! -e $fixture/injected ]]
[[ -z $(find "$fixture/runtime/quickshell-picker" -mindepth 1 -print -quit) ]]
printf 'PASS: offline QML export reads Config directly, preserves literal paths and creates no application database\n'

# The same shared helper passes values as data and overwrites obsolete environment inputs.
SCREENSHOT_FOLDER=obsolete bash -c '
    source "$1/src/services/launcher/providers/_common/utils.sh"
    load_provider_config
    printf "%s\0" "$SCREENSHOT_FOLDER" "$VIDEOS_FOLDER" "$WALLPAPER_DIRECTORY" "$WALLPAPER_STATE_DIRECTORY" "$WORKING_STATE_NAME"
' bash "$fixture" > "$fixture/environment"
node - "$fixture" <<'JS'
const fs = require('fs'), root = process.argv[2], expected = JSON.parse(fs.readFileSync(root + '/expected.json'));
const actual = fs.readFileSync(root + '/environment','utf8').split('\0').slice(0,-1);
if (JSON.stringify(actual) !== JSON.stringify(Object.values(expected))) throw Error('Environment changed literal values');
JS
[[ ! -e $fixture/injected ]]
printf 'PASS: shared environment handoff preserves quotes, newlines and shell expressions without evaluation\n'

node - "$fixture" <<'JS'
const fs=require('fs'), root=process.argv[2], file=root+'/src/config/Config.qml';
const expected=JSON.parse(fs.readFileSync(root+'/expected.json'));
expected.VIDEOS_FOLDER=root+'/changed recording destination';
const source=fs.readFileSync(file,'utf8').replace(/(readonly property string recordingDirectory:)[^\n]*/,
    (_, declaration)=>declaration+' '+JSON.stringify(expected.VIDEOS_FOLDER));
fs.writeFileSync(file,source);fs.writeFileSync(root+'/expected.json',JSON.stringify(expected));
JS
bash "$picker" --provider-config > "$fixture/changed.json"
jq -es '.[0] == .[1]' "$fixture/expected.json" "$fixture/changed.json" >/dev/null
printf 'PASS: the next offline invocation reads Config edits without a saved settings cache\n'

# Startup restoration must work through the actual provider while the bar is absent.
mkdir "$fixture/bin"
cat > "$fixture/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
[[ $1 != monitors ]] || printf '[{"name":"DP-1"}]\n'
SH
cat > "$fixture/bin/awww" <<'SH'
#!/usr/bin/env bash
if [[ $1 == img ]]; then printf '%s\n' "$2" >> "$QS_PROVIDER_FIXTURE/wallpaper-applied"; fi
SH
chmod +x "$fixture/bin/"*
export QS_PROVIDER_FIXTURE="$fixture"
state_directory=$(jq -r .WALLPAPER_STATE_DIRECTORY "$fixture/expected.json")
mkdir -p "$state_directory"
touch "$fixture/synthetic image.png"
ln -s "$fixture/synthetic image.png" "$state_directory/wallpaper_personal_1"
PATH="$fixture/bin:$PATH" bash "$picker" provider wallpaper restore personal
[[ $(cat "$fixture/wallpaper-applied") == "$state_directory/wallpaper_personal_1" ]]
printf 'PASS: wallpaper startup restore uses Config through the offline bridge without a running bar\n'

cat > "$fixture/qs-mock" <<'SH'
#!/usr/bin/env bash
[[ $1 == ipc ]] || { touch "$QS_PROVIDER_FIXTURE/unexpected-export"; exit 2; }
cat "$QS_PROVIDER_FIXTURE/online.json"
SH
chmod +x "$fixture/qs-mock"
export QS_PROVIDER_FIXTURE="$fixture" QS_PICKER_EXECUTABLE="$fixture/qs-mock"
cp "$fixture/expected.json" "$fixture/online.json"
bash "$picker" --provider-config > "$fixture/online-result.json"
jq -es '.[0] == .[1]' "$fixture/expected.json" "$fixture/online-result.json" >/dev/null
[[ ! -e $fixture/unexpected-export ]]
for invalid in '{"PATH":"/untrusted"}' 'null' '[]'; do
    printf '%s\n' "$invalid" > "$fixture/online.json"
    result=0
    bash "$picker" --provider-config > "$fixture/rejected" 2> "$fixture/error" || result=$?
    [[ $result == 2 && ! -s $fixture/rejected && ! -e $fixture/unexpected-export ]]
done
printf 'PASS: online settings use IPC directly; malformed or unexpected environment keys fail without fallback\n'

unset QS_PICKER_EXECUTABLE
printf '\nthis is deliberately invalid QML\n' >> "$fixture/src/config/Config.qml"
result=0
bash "$picker" --provider-config > "$fixture/rejected" 2> "$fixture/error" || result=$?
[[ $result == 2 && ! -s $fixture/rejected ]]
[[ -z $(find "$fixture/runtime/quickshell-picker" -mindepth 1 -print -quit) ]]
printf 'PASS: offline export failure returns a clear error and releases its private FIFO\n'
