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
mkdir -p "$ZDOTDIR/scripts/status" "$ZDOTDIR/scripts/default-browser"
mkdir -p "$HOME/.config/qutebrowser/scripts/url" "$HOME/.config/qutebrowser/bookmarks"
mkdir -p "$HOME/Alpha" "$HOME/Beta" "$HOME/Pictures" "$HOME/Videos"
touch "$test_dir/actions" "$test_dir/menus"
cat > "$test_dir/bin/qs" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${6:-} == projects || ${6:-} == projectUrls || ${6:-} == directories ]]; then
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
            clients) printf '%s\n' '[{"class":"mpv-youtube","address":"0xtest","title":"Test"}]' ;;
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
    logger) if (($# == 0)); then cat >/dev/null; fi ;;
esac
BASH
chmod +x "$test_dir/bin/qs" "$test_dir/bin/action"
for command in hyprctl code zathura xdg-open dbus-send pcmanfm-qt mpv virsh nc sdl-freerdp3 systemctl loginctl wf-recorder hyprshot satty pactl slurp logger playerctl sleep pgrep pkill notify-send wl-copy tesseract zbarimg; do
    ln -s action "$test_dir/bin/$command"
done
cat > "$ZDOTDIR/scripts/status/manager.sh" <<'BASH'
#!/usr/bin/env bash
if [[ $1 == --get ]]; then printf '%s\n' work
else printf 'status <%s> <%s>\n' "$1" "${2:-}" >> "$PROVIDER_TEST_DIR/actions"; fi
BASH
cat > "$ZDOTDIR/scripts/default-browser/default-browser.sh" <<'BASH'
#!/usr/bin/env bash
printf 'browser <%s>\n' "$*" >> "$PROVIDER_TEST_DIR/actions"
BASH
chmod +x "$ZDOTDIR/scripts/status/manager.sh" "$ZDOTDIR/scripts/default-browser/default-browser.sh"
printf 'clean() { printf "%%s" "$1"; }\n' > "$HOME/.config/qutebrowser/scripts/url/_common.sh"
cat > "$HOME/.config/qutebrowser/bookmarks/urls" <<'DATA'
https://example.test/alpha Alpha
https://example.test/beta Beta
DATA
cat > "$providers/web/webapps.json" <<'JSON'
{"action":"output","items":[{"title":"Alpha","result":{"action":"browser","url":"https://example.test/app"}},{"title":"Beta","result":{"action":"browser","url":"https://example.test/beta"}}]}
JSON
cat > "$providers/web/n8n.json" <<'JSON'
{"action":"default","items":[{"title":"Alpha","result":"https://example.test/workflow/alpha"},{"title":"Beta","result":"https://example.test/workflow/beta"}]}
JSON
cp "$providers/web/n8n.json" "$XDG_CACHE_HOME/azure_${USER}"
jq -n --arg home "$HOME" '{action:"output",items:[
    {title:"Alpha",result:($home + "/alpha.pdf")},
    {title:"Beta",result:($home + "/beta.pdf")}
]}' > "$XDG_CACHE_HOME/books_${USER}"
cat > "$providers/remotes/hosts.json" <<'JSON'
{"baseRDPParams":"/cert:ignore","hosts":[
    {"name":"Alpha VM","enabled":true,"type":"vm","endpoint":"127.0.0.1","port":3389,"vmName":"alpha-test","username":"test","password":"","displayName":"Test VM"},
    {"name":"Beta VM","enabled":true,"type":"vm"}
]}
JSON
printf 'SCREENSHOT_FOLDER=%q\n' "$HOME/Pictures" > "$providers/screenshot.env"
printf 'VIDEOS_FOLDER=%q\n' "$HOME/Videos" > "$providers/recording.env"
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
for provider in code github directories; do
    : > "$test_dir/actions"; : > "$test_dir/menus"
    bash "$picker" provider "$provider"
    if [[ $provider == code ]]; then expect_action 'native <projects>';
    elif [[ $provider == github ]]; then expect_action 'native <projectUrls>';
    else expect_action 'native <directories>'; fi
    [[ ! -s $test_dir/menus ]]
done
printf 'PASS: projects, GitHub and directories dispatch to native IPC without a JSON cache\n'
run_provider webapps 'browser <https://example.test/app>'
run_provider azure 'browser <https://example.test/workflow/alpha>' --pick
run_provider n8n 'browser <https://example.test/workflow/alpha>'
run_provider remotes 'virsh <-c> <qemu:///system> <start> <alpha-test>'
expect_action 'sdl-freerdp3'
run_provider bookmarks 'browser <https://example.test/alpha>'
run_provider books "zathura <$HOME/alpha.pdf>" --pick
run_provider power 'loginctl <lock-session>'
run_provider screenshot 'hyprshot <--freeze> <--silent> <--clipboard-only> <--raw> <--mode> <output>'
run_provider recording 'wf-recorder <'
expect_action '<--output> <TEST-1>'
expect_action '<--framerate> <60>'
jq -se 'length == 4' "$test_dir/menus" >/dev/null

# Non-menu callers must keep working after the original scripts are removed.
: > "$test_dir/actions"; : > "$test_dir/menus"
bash "$picker" provider media 'Video title' 'https://youtube.com/watch?v=direct' > "$test_dir/output" 2> "$test_dir/error"
expect_action '<https://youtube.com/watch?v=direct>'
[[ ! -s $test_dir/menus ]]
if bash "$picker" provider media > "$test_dir/output" 2> "$test_dir/error"; then exit 1; fi
rg -Fq 'qs ipc call bar open twitch' "$test_dir/error"
[[ ! -s $test_dir/menus ]]
bash "$picker" provider power Lock
bash "$picker" provider screenshot ocr >/dev/null
bash "$picker" provider screenshot qrcode >/dev/null
PROVIDER_TEST_RECORDING=1 bash "$picker" provider recording
expect_action 'loginctl <lock-session>'
expect_action 'tesseract <stdin> <stdout> <-l> <por>'
expect_action 'zbarimg <--raw> <-q> <->'
expect_action 'pkill <-SIGINT> <-x> <wf-recorder>'
! rg -q '^notify-send |^hyprctl <notify>' "$test_dir/actions"
[[ ! -s $test_dir/menus ]]
printf 'PASS: direct media, idle lock, OCR, QR and recording-stop calls bypass selection\n'

# A cancelled browser request must not execute its selected action.
for name in bookmarks remotes power; do
    : > "$test_dir/actions"
    PROVIDER_TEST_CANCEL=1 PROVIDER_TEST_NAME="$name" bash "$picker" provider "$name" > "$test_dir/output" 2> "$test_dir/error" || true
    ! rg -q '^(browser|mpv|virsh|sdl-freerdp3|loginctl|systemctl) ' "$test_dir/actions"
done
[[ -z $(find "$test_dir/runtime/quickshell-picker" -mindepth 1 -print -quit) ]]
printf 'PASS: cancellation skips actions and all request directories are cleaned up\n'

# Each recording picker must cancel the entire operation, including the final audio picker.
for title in output TEST-1 60 desktop; do
    : > "$test_dir/actions"
    PROVIDER_TEST_NAME=recording PROVIDER_TEST_CANCEL_TITLE="$title" bash "$picker" provider recording > "$test_dir/output" 2> "$test_dir/error"
    ! rg -q '^(wf-recorder|pactl) ' "$test_dir/actions"
done
printf 'PASS: recording cancellation at every picker skips capture and loopback setup\n'

# Audio follows the current defaults, including output-monitor names supplied by PulseAudio.
for audio_mode in desktop mic both; do
    : > "$test_dir/actions"; : > "$test_dir/menus"
    PROVIDER_TEST_NAME=recording PROVIDER_TEST_AUDIO="$audio_mode" bash "$picker" provider recording > "$test_dir/output" 2> "$test_dir/error"
    if [[ $audio_mode == mic ]]; then expect_action '<--audio=test.microphone>'
    else expect_action '<--audio=test.output.monitor>'; fi
    if [[ $audio_mode == both ]]; then
        expect_action 'pactl <load-module> <module-loopback> <source=test.microphone> <sink=test.output>'
        expect_action 'pactl <unload-module> <99>'
    else ! rg -q '^pactl <load-module>' "$test_dir/actions"; fi
    if [[ $audio_mode == both ]]; then expected_menus=6; else expected_menus=5; fi
    jq -se --argjson count "$expected_menus" '
        length == $count and all(.[] | select(.prompt == "Audio output" or .prompt == "Microphone");
            .sort == false and (.items | length) == 2 and (.items[0].title | endswith(" (default)"))
            and all(.items[]; (.result | startswith("off.")) | not))
    ' "$test_dir/menus" >/dev/null
    expect_action 'hyprctl <notify> <-1> <1000> <rgb(2E7D32)> <recording stopped>'
    jq -Rse '
        split("\n") | to_entries
        | (map(select(.value | startswith("hyprctl <notify>"))) | map(.key)) as $notifications
        | (map(select(.value == "sleep <1.1>")) | .[0].key) as $delay
        | (map(select(.value | startswith("wf-recorder <"))) | .[0].key) as $start
        | (map(select(.value == "wf-recorder-finished")) | .[0].key) as $finish
        | $notifications | length == 2 and .[0] < $delay and $delay < $start and $finish < .[1]
    ' "$test_dir/actions" >/dev/null
    ! rg -q '^notify-send ' "$test_dir/actions"
done
printf 'PASS: recording defaults, loopback cleanup and Hyprland notifications outside capture\n'

# Audio device pickers always open and return identities rather than display labels.
: > "$test_dir/actions"; : > "$test_dir/menus"
PROVIDER_TEST_NAME=recording PROVIDER_TEST_AUDIO=both PROVIDER_TEST_OTHER_DEVICES=1 \
    bash "$picker" provider recording > "$test_dir/output" 2> "$test_dir/error"
expect_action '<--audio=test.output2.monitor>'
expect_action '<source=test.microphone2> <sink=test.output2>'
expect_action 'pactl <unload-module> <99>'
jq -se 'length == 6 and any(.[]; .prompt == "Audio output" and .items[0].title == "Primary output (default)")' "$test_dir/menus" >/dev/null
for title in 'Primary output (default)' 'Primary microphone (default)'; do
    : > "$test_dir/actions"
    PROVIDER_TEST_NAME=recording PROVIDER_TEST_AUDIO=both PROVIDER_TEST_CANCEL_TITLE="$title" \
        bash "$picker" provider recording > "$test_dir/output" 2> "$test_dir/error"
    ! rg -q '^(wf-recorder|pactl <load-module>)' "$test_dir/actions"
done
[[ -z $(find "$test_dir/runtime" -name 'recording-devices.*.json' -print -quit) ]]
printf 'PASS: output/input pickers hide off profiles, keep defaults and virtual devices, and cancel cleanly\n'

# Recorder errors release audio routing and report failure instead of success.
: > "$test_dir/actions"
if PROVIDER_TEST_NAME=recording PROVIDER_TEST_AUDIO=both PROVIDER_TEST_RECORDER_EXIT=1 \
    bash "$picker" provider recording > "$test_dir/output" 2> "$test_dir/error"; then exit 1; fi
expect_action 'pactl <unload-module> <99>'
expect_action 'hyprctl <notify> <-1> <3000> <rgb(FF0000)> <recording error>'
! rg -q 'recording stopped|^notify-send |^dbus-send' "$test_dir/actions"
printf 'PASS: recorder failure releases loopback routing without claiming a saved recording\n'

# Shell syntax in device names and paths must remain literal arguments.
literal_folder="$HOME/Videos \"quoted\" \$(touch $test_dir/injected)"
literal_audio='monitor $(touch injected) $dollar "quoted"'
printf 'VIDEOS_FOLDER=%q\n' "$literal_folder" > "$providers/recording.env"
: > "$test_dir/actions"
PROVIDER_TEST_NAME=recording PROVIDER_TEST_AUDIO=desktop PROVIDER_TEST_MONITOR="$literal_audio" bash "$picker" provider recording > "$test_dir/output" 2> "$test_dir/error"
expect_action "<--audio=$literal_audio>"
expect_action "<-f> <$literal_folder/Recording "
[[ ! -e $test_dir/injected && -d $literal_folder ]]
printf 'PASS: recording paths and audio devices retain literal shell characters\n'

# RDP credentials and quoted extra flags are data, including dollar signs and wildcards.
source "$providers/remotes/components/options/host.sh"
sdl-freerdp3() { printf '%s\n' "$@" | jq -Rsc 'split("\n")[:-1]' > "$test_dir/rdp-args"; }
password='pa$$word "quote" $(touch injected) `literal` \\ end'
rdp example.test 3389 'domain name' 'test user' "$password" 'Test "connection" $title' '/cert:ignore /drive:"Docs,/some path" /literal:*'
jq -e --arg password "/p:$password" '. == ["/t:Test \"connection\" $title", "/v:example.test:3389", "/u:test user@domain name", $password, "/cert:ignore", "/drive:Docs,/some path", "/literal:*"]' "$test_dir/rdp-args" >/dev/null
rm "$test_dir/rdp-args"
if rdp example.test 3389 '' user '' '' '/drive:"unterminated' 2>/dev/null; then exit 1; fi
[[ ! -f $test_dir/rdp-args ]]
rdp example.test 3389 '' user '' '' '/drive:"Windows,C:\Users\Public" /quoted:"say \"hi\""'
jq -e '.[-2:] == ["/drive:Windows,C:\\Users\\Public", "/quoted:say \"hi\""]' "$test_dir/rdp-args" >/dev/null
printf 'PASS: RDP passes literal credentials and quoted flags and rejects invalid quoting\n'

# Verify literal credentials also survive extraction from the host JSON.
password='pa;$$word\backslash "quoted"'
jq --arg password "$password" '.hosts[0].password = $password | .hosts[0].username = "test;user"' "$providers/remotes/hosts.json" > "$test_dir/hosts.json"
mv "$test_dir/hosts.json" "$providers/remotes/hosts.json"
: > "$test_dir/actions"
PROVIDER_TEST_NAME=remotes bash "$picker" provider remotes > "$test_dir/output" 2> "$test_dir/error"
expect_action "</p:$password>"
expect_action '</u:test;user>'

WORKSPACE="$providers/remotes"
HOSTS_FILE="$providers/remotes/hosts.json"
LOCALHOST_SSH=localhost
source "$providers/remotes/components/hosts/remote.sh"
get_random_port() { printf '5555'; }
dns() { printf '%s' "$1"; }
connect_ssh() { printf '12345'; }
kill() { [[ $1 == 12345 ]]; }
handle_remote 'Alpha VM'
jq -e --arg password "/p:$password" 'index($password) != null and index("/u:test;user") != null' "$test_dir/rdp-args" >/dev/null
printf 'PASS: VM and SSH/RDP host JSON preserves delimiters, empty fields and backslashes in credentials\n'
