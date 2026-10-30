#!/usr/bin/env bash
# Real AudioService with a mocked mute command and no native audio connection.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-audio-mute-service.XXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
node - "$fixture" <<'NODE'
const fs=require('fs'); const root=process.argv[2];
const file=root+'/src/config/Config.qml';
let config=fs.readFileSync(file,'utf8');
config=config.replace(/readonly property var audioMuteCommand: input => \[[\s\S]*?\n    \]/,
 'readonly property var audioMuteCommand: input => ["bash", '+JSON.stringify(root+'/mute-command.sh')+', input ? "mic" : "speakers"]');
fs.writeFileSync(file,config);
NODE
cat >"$fixture/mute-command.sh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$1" >>"$AUDIO_TEST_STATE/calls"
count=$(wc -l <"$AUDIO_TEST_STATE/calls")
if (( count == 2 )); then
    printf '{"key":"audio.errors.discordSync"}\n' >&2
elif (( count == 3 )); then
    printf '{"key":"audio.errors.changeMute"}\n' >&2
    exit 1
fi
MOCK
sed 's@"../../src@"src@g' "$repo/tests/audio/audio-mute-service.qml" >"$fixture/shell.qml"
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 \
    PIPEWIRE_REMOTE=audio-mute-service-test XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    AUDIO_TEST_STATE="$fixture" timeout -k 2 10 qs -p "$fixture" >"$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: AudioService mute' "$fixture/log" \
    || rg -q 'MUTE SERVICE FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
[[ $(cat "$fixture/calls") == $'mic\nspeakers\nmic\nmic' ]]
rg 'PASS:' "$fixture/log"
