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
if [[ ${6:-} == screenshot || ${6:-} == wallpaper || ${6:-} == encodeQr || ${6:-} == bookmarks || ${6:-} == power || ${6:-} == projects || ${6:-} == projectUrls || ${6:-} == directories || ${6:-} == webapps || ${6:-} == remotes || ${6:-} == n8n ]]; then
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
for command in hyprctl code xdg-open dbus-send pcmanfm-qt virsh nc sdl-freerdp3 systemctl loginctl wf-recorder hyprshot satty pactl slurp sleep pgrep pkill notify-send wl-copy tesseract zbarimg; do
    ln -s action "$test_dir/bin/$command"
done
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
for provider in code github directories webapps remotes n8n power bookmarks encode-qrcode wallpaper screenshot; do
    : > "$test_dir/actions"; : > "$test_dir/menus"
    bash "$picker" provider "$provider"
    case $provider in
        code) expect_action 'native <projects>' ;;
        github) expect_action 'native <projectUrls>' ;;
        encode-qrcode) expect_action 'native <encodeQr>' ;;
        *) expect_action "native <$provider>" ;;
    esac
    [[ ! -s $test_dir/menus ]]
done
printf 'PASS: projects, GitHub, directories, Webapps, Remotes, n8n, Power, Bookmarks, QR encoding and Wallpaper dispatch to native IPC without a JSON cache\n'
# Capture tools and offline prepared execution are covered by screenshot.sh.
# Native recording choices are covered by tests/recording/setup.sh.
# Non-menu callers must keep working after the original scripts are removed.
: > "$test_dir/actions"; : > "$test_dir/menus"
bash "$picker" provider power Lock
bash "$picker" provider screenshot ocr >/dev/null
bash "$picker" provider screenshot qrcode >/dev/null
PROVIDER_TEST_RECORDING=1 bash "$picker" provider recording
expect_action 'loginctl <lock-session>'
expect_action 'native <screenshot>'
expect_action 'recording <toggle>'
! rg -q '^notify-send |^hyprctl <notify>' "$test_dir/actions"
[[ ! -s $test_dir/menus ]]
printf 'PASS: idle lock, OCR, QR and recording-stop calls bypass selection\n'

[[ ! -d $test_dir/runtime/quickshell-picker || -z $(find "$test_dir/runtime/quickshell-picker" -mindepth 1 -print -quit) ]]
printf 'PASS: provider request directories are cleaned up\n'

# Literal recording paths/audio identities and device filtering now use the native setup suite.
literal_folder="$HOME/Videos quoted literal"
: > "$test_dir/actions"
PROVIDER_TEST_SCREENSHOT_FOLDER="$literal_folder" bash "$picker" provider screenshot output
expect_action 'native <screenshot>'
printf 'PASS: screenshot CLI routes directly to the native capture service\n'

[[ ! -e $test_dir/env-executed ]]
printf 'PASS: obsolete provider .env files are never executed\n'
