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
printf '%s' "$name" >> "$PROVIDER_TEST_DIR/actions"
printf ' <%s>' "$@" >> "$PROVIDER_TEST_DIR/actions"
printf '\n' >> "$PROVIDER_TEST_DIR/actions"
case $name in
    hyprctl)
        case ${1:-} in
            clients) printf '%s\n' '[{"class":"mpv-youtube","address":"0xtest","title":"Test"}]' ;;
            monitors) printf '%s\n' '[{"name":"TEST-1"},{"name":"TEST-2"}]' ;;
        esac ;;
    pgrep) [[ ${PROVIDER_TEST_RECORDING:-0} == 1 ]] ;;
    pactl) if [[ ${1:-} == load-module ]]; then printf '99\n'; fi ;;
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
jq -n --arg home "$HOME" '[
    {name:"Alpha", rootPath:($home + "/Alpha"), category:"work", workspaces:[], url:"https://github.com/example/alpha"},
    {name:"Beta", rootPath:($home + "/Beta"), category:"personal", workspaces:[], url:"https://github.com/example/beta"}
]' > "$XDG_CACHE_HOME/code_projects_${USER}.json"
cat > "$providers/web/webapps.json" <<'JSON'
{"action":"output","items":[{"title":"Alpha","result":{"action":"browser","url":"https://example.test/app"}},{"title":"Beta","result":{"action":"browser","url":"https://example.test/beta"}}]}
JSON
cat > "$providers/web/n8n.json" <<'JSON'
{"action":"default","items":[{"title":"Alpha","result":"https://example.test/workflow/alpha"},{"title":"Beta","result":"https://example.test/workflow/beta"}]}
JSON
cp "$providers/web/n8n.json" "$XDG_CACHE_HOME/azure_${USER}"
jq -n --arg home "$HOME" '{action:"output",items:[
    {title:"Alpha",result:{type:"directory",path:($home + "/Alpha")}},
    {title:"Beta",result:{type:"directory",path:($home + "/Beta")}}
]}' > "$providers/directories.json"
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
printf 'VIDEOS_FOLDER=%q\nHEADPHONES=test.monitor\nMIC=test.mic\n' "$HOME/Videos" > "$providers/recording.env"
cat > "$XDG_RUNTIME_DIR/twitch_online_$(id -u)" <<'JSON'
{"action":"output","items":[{"title":"Alpha","result":"https://youtube.com/watch?v=alpha"},{"title":"Beta","result":"https://youtube.com/watch?v=beta"}]}
JSON
printf '0\n' > "$XDG_RUNTIME_DIR/screencast_status_$(id -u)"
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
run_provider code "code <$HOME/Alpha> <--profile> <Work>"
run_provider webapps 'browser <https://example.test/app>'
run_provider github 'browser <https://github.com/example/alpha>'
expect_action 'browser <https://github.com/example/beta>'
run_provider azure 'browser <https://example.test/workflow/alpha>' --pick
run_provider n8n 'browser <https://example.test/workflow/alpha>'
run_provider remotes 'virsh <-c> <qemu:///system> <start> <alpha-test>'
expect_action 'sdl-freerdp3'
run_provider bookmarks 'browser <https://example.test/alpha>'
run_provider books "zathura <$HOME/alpha.pdf>" --pick
run_provider directories "xdg-open <$HOME/Alpha>"
run_provider media 'mpv <--force-window=immediate> <--wayland-app-id=mpv-youtube> <https://youtube.com/watch?v=alpha>'
run_provider power 'loginctl <lock-session>'
run_provider screenshot 'hyprshot <--freeze> <--silent> <--clipboard-only> <--raw> <--mode> <output>'
run_provider recording 'wf-recorder <'
expect_action '<--output> <TEST-1>'
expect_action '<--framerate> <60>'
[[ $(<"$XDG_RUNTIME_DIR/screencast_status_$(id -u)") == 0 ]]
jq -se 'length == 4' "$test_dir/menus" >/dev/null

# Non-menu callers must keep working after the original scripts are removed.
: > "$test_dir/actions"; : > "$test_dir/menus"
bash "$picker" provider media 'Video title' 'https://youtube.com/watch?v=direct' > "$test_dir/output" 2> "$test_dir/error"
expect_action '<https://youtube.com/watch?v=direct>'
bash "$picker" provider power Lock
bash "$picker" provider screenshot ocr >/dev/null
bash "$picker" provider screenshot qrcode >/dev/null
PROVIDER_TEST_RECORDING=1 bash "$picker" provider recording
expect_action 'loginctl <lock-session>'
expect_action 'tesseract <stdin> <stdout> <-l> <por>'
expect_action 'zbarimg <--raw> <-q> <->'
expect_action 'pkill <-SIGINT> <wf-recorder>'
[[ ! -s $test_dir/menus ]]
printf 'PASS: direct media, idle lock, OCR, QR and recording-stop calls bypass selection\n'

# A cancelled browser/media request must not execute its selected action.
for name in bookmarks media remotes power; do
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
    [[ $(<"$XDG_RUNTIME_DIR/screencast_status_$(id -u)") == 0 ]]
done
printf 'PASS: recording cancellation at every picker skips capture and loopback setup\n'

# Shell syntax in device names and paths must remain literal arguments.
literal_folder="$HOME/Videos \"quoted\" \$(touch $test_dir/injected)"
literal_audio='monitor $(touch injected) $dollar "quoted"'
printf 'VIDEOS_FOLDER=%q\nHEADPHONES=%q\nMIC=test.mic\n' "$literal_folder" "$literal_audio" > "$providers/recording.env"
: > "$test_dir/actions"
PROVIDER_TEST_NAME=recording PROVIDER_TEST_AUDIO=desktop bash "$picker" provider recording > "$test_dir/output" 2> "$test_dir/error"
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
