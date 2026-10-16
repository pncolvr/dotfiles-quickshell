#!/usr/bin/env bash
# Exercise relocated providers without reading private config or running desktop actions.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-providers-test.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/bin" "$test_dir/home" "$test_dir/cache" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$test_dir" -xf -
export HOME="$test_dir/home" ZDOTDIR="$test_dir/zsh"
export XDG_CACHE_HOME="$test_dir/cache" XDG_RUNTIME_DIR="$test_dir/runtime"
export QS_PICKER_CONFIG="$test_dir" QS_PICKER_TIMEOUT=4
export QS_PICKER_EXECUTABLE="$test_dir/bin/qs"
export PROVIDER_TEST_DIR="$test_dir"
export PATH="$test_dir/bin:$PATH"
picker="$test_dir/src/services/launcher/launcher.sh"
providers="$test_dir/src/services/launcher/providers"
mkdir -p "$ZDOTDIR/scripts/default-browser"
mkdir -p "$HOME/.config/qutebrowser/bookmarks"
mkdir -p "$HOME/Alpha" "$HOME/Beta" "$HOME/Pictures" "$HOME/Videos"
touch "$test_dir/actions" "$test_dir/menus"
cat > "$test_dir/bin/qs" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${6:-} == providerConfig ]]; then
    jq -nc --arg screenshots "${PROVIDER_TEST_SCREENSHOT_FOLDER:-$HOME/Pictures}" --arg videos "${PROVIDER_TEST_RECORDING_FOLDER:-$HOME/Videos}" \
        --arg wallpapers "$HOME/Pictures/wallpapers" --arg state "$HOME/Pictures/.runtime" --arg work "${PROVIDER_TEST_WORK_STATUS:-work}" \
        '{SCREENSHOT_FOLDER:$screenshots,VIDEOS_FOLDER:$videos,WALLPAPER_DIRECTORY:$wallpapers,
          WALLPAPER_STATE_DIRECTORY:$state,WORKING_STATE_NAME:$work,WORK_MODE_ENABLED:"true"}'
    exit 0
fi
if [[ ${5:-} == recording ]]; then
    printf 'recording <%s>\n' "$6" >> "$PROVIDER_TEST_DIR/actions"
    exit 0
fi
if [[ ${5:-} == alerts ]]; then
    printf 'alerts' >> "$PROVIDER_TEST_DIR/actions"
    printf ' <%s>' "${@:6}" >> "$PROVIDER_TEST_DIR/actions"
    printf '\n' >> "$PROVIDER_TEST_DIR/actions"
    exit 0
fi
if [[ ${6:-} == projects || ${6:-} == projectUrls || ${6:-} == directories || ${6:-} == webapps || ${6:-} == remotes || ${6:-} == n8n ]]; then
    printf 'native <%s>\n' "$6" >> "$PROVIDER_TEST_DIR/actions"
    exit 0
fi
[[ ${6:-} == open ]] || exit 0
request=$7/request.json
cat "$request" >> "$PROVIDER_TEST_DIR/menus"
index=0
case ${PROVIDER_TEST_NAME:-} in
    power|screenshot) index=1 ;;
esac
if [[ -n ${PROVIDER_TEST_AUDIO:-} ]] && jq -e 'any(.items[]; .title == "desktop")' "$request" >/dev/null; then
    index=$(jq --arg title "$PROVIDER_TEST_AUDIO" '.items | map(.title) | index($title)' "$request")
fi
if [[ ${PROVIDER_TEST_OTHER_DEVICES:-0} == 1 ]] && jq -e '.prompt == "Audio output" or .prompt == "Microphone"' "$request" >/dev/null; then
    index=1
fi
if [[ ${PROVIDER_TEST_CANCEL:-0} == 1 ]] || {
    [[ -n ${PROVIDER_TEST_CANCEL_TITLE:-} ]] && jq -e --arg title "$PROVIDER_TEST_CANCEL_TITLE" 'any(.items[]; .title == $title)' "$request" >/dev/null
}; then
    printf '%s\n' '{"status":"cancelled"}' > "$7/reply"
else
    jq -c --argjson index "$index" --arg multiple "${PROVIDER_TEST_NAME:-}" '
        {status:"accepted", exitCode:0, items:
            (if $multiple == "github" then .items else [.items[$index]] end)}
    ' "$request" > "$7/reply"
fi
BASH
cat > "$test_dir/bin/action" <<'BASH'
#!/usr/bin/env bash
name=${0##*/}
printf -v action_args ' <%s>' "$@"
printf '%s%s\n' "$name" "$action_args" >> "$PROVIDER_TEST_DIR/actions"
case $name in
    hyprctl)
        case ${1:-} in
            monitors) printf '%s\n' '[{"name":"TEST-1"},{"name":"TEST-2"}]' ;;
        esac ;;
    pgrep) [[ ${PROVIDER_TEST_RECORDING:-0} == 1 ]] ;;
    pactl)
        case ${1:-} in
            get-default-sink) printf '%s\n' "${PROVIDER_TEST_OUTPUT:-test.output}" ;;
            get-default-source) printf '%s\n' "${PROVIDER_TEST_INPUT:-test.microphone}" ;;
            --format=json)
                if [[ $3 == cards ]]; then
                    jq -n '[
                        {index:1,active_profile:"off"},
                        {index:2,active_profile:"off",properties:{"object.id":"102"}},
                        {index:3,active_profile:"on",properties:{"object.id":"103"}}
                    ]'
                elif [[ $3 == sinks ]]; then
                    jq -n --arg name "${PROVIDER_TEST_OUTPUT:-test.output}" \
                        --arg monitor "${PROVIDER_TEST_MONITOR:-test.output.monitor}" '[
                        {name:"test.output2", description:"Other output", monitor_source:"test.output2.monitor"},
                        {name:$name, description:"Primary output", monitor_source:$monitor, properties:{"device.id":"103"}},
                        {name:"off.output", description:"Disabled output", card:1},
                        {name:"off.pipewire.output", description:"Disabled PipeWire output", properties:{"device.id":"102"}},
                        {name:"off.profile.output", description:"Disabled profile output", properties:{"device.profile.name":"off"}}
                    ]'
                else
                    jq -n --arg name "${PROVIDER_TEST_INPUT:-test.microphone}" '[
                        {name:"test.microphone2", description:"Other microphone"},
                        {name:$name, description:"Primary microphone", properties:{"device.id":"103"}},
                        {name:"off.microphone", description:"Disabled microphone", card:1},
                        {name:"off.pipewire.microphone", description:"Disabled PipeWire microphone", properties:{"device.id":"102"}},
                        {name:"off.profile.microphone", description:"Disabled profile microphone", properties:{"device.profile.name":"off"}}
                    ]'
                fi ;;
            load-module) printf '99\n' ;;
        esac ;;
    wf-recorder)
        [[ ${PROVIDER_TEST_RECORDER_EXIT:-0} == 0 ]] || exit "$PROVIDER_TEST_RECORDER_EXIT"
        while (($#)); do
            if [[ $1 == -f ]]; then printf 'synthetic video\n' > "$2"; break; fi
            shift
        done
        printf 'wf-recorder-finished\n' >> "$PROVIDER_TEST_DIR/actions" ;;
    satty)
        cat >/dev/null
        while (($#)); do
            if [[ $1 == --output-filename ]]; then touch "$2"; break; fi
            shift
        done ;;
    wl-copy) cat >/dev/null ;;
    tesseract) printf '%s\n' 'Test OCR' ;;
    zbarimg) printf '%s\n' 'https://example.test/qr' ;;
esac
BASH
chmod +x "$test_dir/bin/qs" "$test_dir/bin/action"
for command in hyprctl code zathura xdg-open dbus-send pcmanfm-qt virsh nc sdl-freerdp3 systemctl loginctl wf-recorder hyprshot satty pactl slurp sleep pgrep pkill notify-send wl-copy tesseract zbarimg; do
    ln -s action "$test_dir/bin/$command"
done
cat > "$ZDOTDIR/scripts/default-browser/default-browser.sh" <<'BASH'
#!/usr/bin/env bash
printf 'browser <%s>\n' "$*" >> "$PROVIDER_TEST_DIR/actions"
BASH
chmod +x "$ZDOTDIR/scripts/default-browser/default-browser.sh"
cat > "$HOME/.config/qutebrowser/bookmarks/urls" <<'DATA'
https://example.test/alpha Alpha
https://example.test/beta Beta
DATA
jq -n --arg home "$HOME" '{action:"output",items:[
    {title:"Alpha",result:($home + "/alpha.pdf")},
    {title:"Beta",result:($home + "/beta.pdf")}
]}' > "$XDG_CACHE_HOME/books_${USER}"
for old_config in "$providers/screenshot.env" "$providers/recording.env" "$providers/_common/utils.env"; do
    printf 'touch %q\n' "$test_dir/env-executed" > "$old_config"
done
expect_action() {
    local expected=$1
    for ((attempt=0;attempt<50;attempt++)); do
        if rg -Fq -- "$expected" "$test_dir/actions"; then return; fi
        /usr/bin/sleep 0.02
    done
    printf 'Missing action: %s\n' "$expected" >&2
    cat "$test_dir/error" >&2
    exit 1
}
run_provider() {
    local name=$1 expected=$2; shift 2
    : > "$test_dir/actions"; : > "$test_dir/menus"
    PROVIDER_TEST_NAME="$name" bash "$picker" provider "$name" "$@" > "$test_dir/output" 2> "$test_dir/error"
    expect_action "$expected"
    jq -se 'length > 0 and all(.[]; (.items | length) > 1)' "$test_dir/menus" >/dev/null
    [[ ! -s $test_dir/error ]] || { cat "$test_dir/error" >&2; exit 1; }
    printf 'PASS: %s provider dispatch, shared helpers and selected action\n' "$name"
}
for provider in code github directories webapps remotes n8n; do
    : > "$test_dir/actions"; : > "$test_dir/menus"
    bash "$picker" provider "$provider"
    case $provider in
        code) expect_action 'native <projects>' ;;
        github) expect_action 'native <projectUrls>' ;;
        *) expect_action "native <$provider>" ;;
    esac
    [[ ! -s $test_dir/menus ]]
done
printf 'PASS: projects, GitHub, directories, Webapps, Remotes and n8n dispatch to native IPC without a JSON cache\n'
run_provider bookmarks 'browser <https://example.test/alpha>'
run_provider books "zathura <$HOME/alpha.pdf>" --pick
run_provider power 'loginctl <lock-session>'
run_provider screenshot 'hyprshot <--freeze> <--silent> <--clipboard-only> <--raw> <--mode> <output>'
prepare_recording() {
    PROVIDER_TEST_NAME=recording bash "$providers/recording.sh" --prepare > "$test_dir/output" 2> "$test_dir/error"
}
expect_recording_argument() {
    jq -e --arg argument "$1" '.command | index($argument) != null' "$test_dir/output" >/dev/null
}
: > "$test_dir/menus"
prepare_recording
expect_recording_argument --no-damage
expect_recording_argument TEST-1
expect_recording_argument 60
jq -se 'length == 4' "$test_dir/menus" >/dev/null

# Non-menu callers must keep working after the original scripts are removed.
: > "$test_dir/actions"; : > "$test_dir/menus"
bash "$picker" provider power Lock
bash "$picker" provider screenshot ocr >/dev/null
bash "$picker" provider screenshot qrcode >/dev/null
PROVIDER_TEST_RECORDING=1 bash "$picker" provider recording
expect_action 'loginctl <lock-session>'
expect_action 'tesseract <stdin> <stdout> <-l> <por>'
expect_action 'zbarimg <--raw> <-q> <->'
expect_action 'recording <toggle>'
! rg -q '^notify-send |^hyprctl <notify>' "$test_dir/actions"
[[ ! -s $test_dir/menus ]]
printf 'PASS: idle lock, OCR, QR and recording-stop calls bypass selection\n'

# A cancelled browser request must not execute its selected action.
for name in bookmarks power; do
    : > "$test_dir/actions"
    PROVIDER_TEST_CANCEL=1 PROVIDER_TEST_NAME="$name" bash "$picker" provider "$name" > "$test_dir/output" 2> "$test_dir/error" || true
    ! rg -q '^(browser|virsh|sdl-freerdp3|loginctl|systemctl) ' "$test_dir/actions"
done
[[ -z $(find "$test_dir/runtime/quickshell-picker" -mindepth 1 -print -quit) ]]
printf 'PASS: cancellation skips actions and all request directories are cleaned up\n'

# Each recording picker must cancel the entire operation, including the final audio picker.
for title in output TEST-1 60 desktop; do
    : > "$test_dir/actions"
    PROVIDER_TEST_NAME=recording PROVIDER_TEST_CANCEL_TITLE="$title" bash "$providers/recording.sh" --prepare > "$test_dir/output" 2> "$test_dir/error"
    ! rg -q '^(wf-recorder|pactl) ' "$test_dir/actions"
done
printf 'PASS: recording cancellation at every picker skips capture and loopback setup\n'

# Audio follows the current defaults, including output-monitor names supplied by PulseAudio.
for audio_mode in desktop mic both; do
    : > "$test_dir/actions"; : > "$test_dir/menus"
    PROVIDER_TEST_NAME=recording PROVIDER_TEST_AUDIO="$audio_mode" bash "$providers/recording.sh" --prepare > "$test_dir/output" 2> "$test_dir/error"
    if [[ $audio_mode == mic ]]; then expect_recording_argument '--audio=test.microphone'
    else expect_recording_argument '--audio=test.output.monitor'; fi
    if [[ $audio_mode == both ]]; then
        jq -e '.loopback == ["module-loopback","source=test.microphone","sink=test.output"]' "$test_dir/output" >/dev/null
    else ! rg -q '^pactl <load-module>' "$test_dir/actions"; fi
    if [[ $audio_mode == both ]]; then expected_menus=6; else expected_menus=5; fi
    jq -se --argjson count "$expected_menus" '
        length == $count and all(.[] | select(.prompt == "Audio output" or .prompt == "Microphone");
            .sort == false and (.items | length) == 2 and (.items[0].title | endswith(" (default)"))
            and all(.items[]; (.result | startswith("off.")) | not))
    ' "$test_dir/menus" >/dev/null
    ! rg -q '^(wf-recorder|pactl <load-module>|notify-send|alerts)' "$test_dir/actions"

done
printf 'PASS: recording setup returns default devices and deferred loopback arguments without starting capture\n'

# Audio device pickers always open and return identities rather than display labels.
: > "$test_dir/actions"; : > "$test_dir/menus"
PROVIDER_TEST_NAME=recording PROVIDER_TEST_AUDIO=both PROVIDER_TEST_OTHER_DEVICES=1 \
    bash "$providers/recording.sh" --prepare > "$test_dir/output" 2> "$test_dir/error"
expect_recording_argument '--audio=test.output2.monitor'
jq -e '.loopback == ["module-loopback","source=test.microphone2","sink=test.output2"]' "$test_dir/output" >/dev/null
jq -se 'length == 6 and any(.[]; .prompt == "Audio output" and .items[0].title == "Primary output (default)")' "$test_dir/menus" >/dev/null
for title in 'Primary output (default)' 'Primary microphone (default)'; do
    : > "$test_dir/actions"
    PROVIDER_TEST_NAME=recording PROVIDER_TEST_AUDIO=both PROVIDER_TEST_CANCEL_TITLE="$title" \
        bash "$providers/recording.sh" --prepare > "$test_dir/output" 2> "$test_dir/error"
    ! rg -q '^(wf-recorder|pactl <load-module>)' "$test_dir/actions"
done
[[ -z $(find "$test_dir/runtime" -name 'recording-devices.*.json' -print -quit) ]]
printf 'PASS: output/input pickers hide off profiles, keep defaults and virtual devices, and cancel cleanly\n'

# Shell syntax in device names and paths must remain literal arguments.
literal_folder="$HOME/Videos \"quoted\" \$(touch $test_dir/injected)"
literal_audio='monitor $(touch injected) $dollar "quoted"'
: > "$test_dir/actions"
PROVIDER_TEST_NAME=recording PROVIDER_TEST_AUDIO=desktop PROVIDER_TEST_MONITOR="$literal_audio" PROVIDER_TEST_RECORDING_FOLDER="$literal_folder" bash "$providers/recording.sh" --prepare > "$test_dir/output" 2> "$test_dir/error"
expect_recording_argument "--audio=$literal_audio"
jq -e --arg folder "$literal_folder/Recording " '(.filename | startswith($folder)) and (.command[-1] == .filename)' "$test_dir/output" >/dev/null
[[ ! -e $test_dir/injected && -d $literal_folder ]]
printf 'PASS: recording paths and audio devices retain literal shell characters\n'

: > "$test_dir/actions"
PROVIDER_TEST_SCREENSHOT_FOLDER="$literal_folder" bash "$picker" provider screenshot output
expect_action "<--output-filename> <$literal_folder/Screenshot "
printf 'PASS: screenshot destinations come from Config, including literal paths\n'

[[ ! -e $test_dir/env-executed ]]
printf 'PASS: obsolete provider .env files are never executed\n'
