#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-storage-test.XXXXXX)
mkdir -p "$test_dir/config/data"
entry="$test_dir/config/shell.qml"
qs_pid=""
cleanup() {
    local result=$?
    if ((result != 0)) && [[ -f $test_dir/notify-calls ]]; then
        printf 'Alert log at failure (phase=%s):\n' "${phase:-startup}" >&2
        cat "$test_dir/notify-calls" >&2
    fi
    if [[ -n $qs_pid ]]; then kill "$qs_pid" 2>/dev/null || true; wait "$qs_pid" 2>/dev/null || true; fi
    rm -rf -- "$test_dir"
}
trap cleanup EXIT
mkdir -m 700 "$test_dir/runtime"
mkdir "$test_dir/bin"
export XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache"
export QT_QPA_PLATFORM=offscreen
export STORAGE_TEST_STATE="$test_dir" STORAGE_TEST_PNG="$project_root/src/assets/twitch.png" PATH="$test_dir/bin:$PATH"
mkdir -p "$XDG_DATA_HOME/qutebrowser/sessions"
cat > "$XDG_DATA_HOME/qutebrowser/sessions/_autosave.yml" <<'YAML'
windows:
  - tabs:
      - active: true
        history:
          - url: https://www.twitch.tv/historical
          - active: true
            url: https://www.twitch.tv/Alice
      - history:
          - active: true
            url: https://www.twitch.tv/bob/schedule
      - history:
          - active: true
            url: https://www.twitch.tv/directory
YAML
cat > "$test_dir/bin/ping" <<'MOCK'
#!/usr/bin/env bash
[[ ${STORAGE_TEST_PHASE:-} != layout ]]
MOCK
cat > "$test_dir/bin/solaar" <<'MOCK'
#!/usr/bin/env bash
sleep 0.25
printf 'Receiver read failed\n' >&2
exit 1
MOCK
cat > "$test_dir/bin/twitch" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
query=${!#}
path=${query%%\?*}
IFS='&' read -ra params <<< "${query#*\?}"
logins=()
for param in "${params[@]}"; do
    case $param in login=*|user_login=*|broadcaster_id=*) logins+=("${param#*=}");; esac
 done
phase=${STORAGE_TEST_PHASE:-}
case $path in
    streams)
        if [[ $phase == live-error ]]; then printf '{"error":"API unavailable"}\n'; exit 1; fi
        jq -cn --arg phase "$phase" --args '{data: (if (["live-add","live-restart","live-new-stream"] | index($phase)) then $ARGS.positional | map({id: (. + "-stream-" + (if . == "alice" and $phase == "live-new-stream" then "2" else "1" end)), user_login: ., viewer_count: 123, title: "Live test stream", game_name: "Game"}) else [] end)}' "${logins[@]}"
        ;;
    users)
        suffix=""
        if [[ $phase == avatar-failure || $phase == avatar-update ]]; then suffix=-v2; fi
        jq -cn --arg suffix "$suffix" --args '{data: ($ARGS.positional | map({login: ., id: ., profile_image_url: ("https://avatars.test/" + . + $suffix + ".png")}))}' "${logins[@]}"
        ;;
    schedule)
        printf '%s\n' "${logins[0]}" >> "$STORAGE_TEST_STATE/schedule-calls"
        jq -cn --arg start "$(date -u -d '+2 days' +%FT%TZ)" '{data: {segments: [{start_time: $start, canceled_until: null}]}}'
        ;;
    *) exit 1;;
esac
if [[ $phase == seed || $phase == live-add ]]; then
    printf 'panic: runtime error in CLI update check\n' >&2
    exit 2
fi
MOCK
cat > "$test_dir/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${!#}" >> "$STORAGE_TEST_STATE/avatar-calls"
sleep 0.15
[[ ${STORAGE_TEST_PHASE:-} != avatar-failure ]] || exit 1
cat "$STORAGE_TEST_PNG"
MOCK
cat > "$test_dir/bin/notify-send" <<'MOCK'
#!/usr/bin/env bash
jq -cn --args '$ARGS.positional' -- "$@" >> "$STORAGE_TEST_STATE/notify-calls"
MOCK
chmod +x "$test_dir/bin/"*
cat > "$entry" <<QML
import QtQuick
import Quickshell
Scope { Loader { source: "file://$project_root/tests/storage/storage-smoke.qml" } }
QML
for phase in seed restart avatar-failure avatar-update empty empty-restart live-add live-restart live-new-stream live-error live-offline live-offline-restart layout; do
    output=$(STORAGE_TEST_PHASE="$phase" timeout 12 qs -p "$entry" 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
    printf '%s\n' "$output"
    [[ ! -e $XDG_RUNTIME_DIR/twitch_online_$(id -u) ]]
    [[ $output == *"PASS: storage $phase"* && $output != *'STORAGE FAIL:'* \
        && $output != *'Failed to load configuration'* && $output != *'Binding loop detected'* \
        && $output != *'TypeError:'* && $output != *'ReferenceError:'* ]]
    if [[ $phase == seed ]]; then
        sqlite3 "$test_dir/config/data/quickshell.db" 'DROP TABLE twitch_notified_streams; PRAGMA user_version=3;'
    fi
    if [[ $phase == restart ]]; then [[ $(wc -l < "$test_dir/avatar-calls") -eq 2 ]]; fi
    if [[ $phase == empty-restart ]]; then [[ $(cat "$test_dir/schedule-calls") == bob ]]; fi
    if [[ $phase == live-add ]]; then initial_live_alerts=$(wc -l < "$test_dir/notify-calls"); fi
    if [[ $phase == live-restart ]]; then [[ $(wc -l < "$test_dir/notify-calls") -eq $initial_live_alerts ]]; fi
    if [[ $phase == live-new-stream ]]; then
        jq -se --argjson initial "$initial_live_alerts" 'length == $initial + 1 and .[-1][-2:] == ["Live","`alice`"] and all(.[][]; startswith("--action") | not)' "$test_dir/notify-calls" >/dev/null
        printf 'PASS: live alerts persist across restarts and only a new stream triggers another alert\n'
    fi
    if [[ $phase == live-error ]]; then [[ $(wc -l < "$test_dir/notify-calls") -eq $((initial_live_alerts + 1)) ]]; fi
    if [[ $phase == live-offline || $phase == live-offline-restart ]]; then
        jq -se --argjson initial "$initial_live_alerts" 'length == $initial + 2 and .[-1][-2:] == ["Offline","`alice`  \n`bob`"]' "$test_dir/notify-calls" >/dev/null
        printf 'PASS: offline alert emitted once and preserved across restarts\n'
    fi
done
database="$test_dir/config/data/quickshell.db"
[[ -f $database && ! -L $database ]]
mapfile -t connections < <(rg --files "$XDG_DATA_HOME" -g '*.sqlite')
[[ ${#connections[@]} == 1 && ! -L ${connections[0]} ]]
[[ $(sqlite3 "${connections[0]}" "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table';") == 0 ]]
[[ $(sqlite3 "$database" 'PRAGMA integrity_check;') == ok ]]
for table in twitch_users twitch_schedules twitch_avatars twitch_notified_streams battery_receivers; do
    [[ $(sqlite3 "$database" "SELECT COUNT(*) FROM $table;") == 0 ]]
done
[[ $(sqlite3 "$database" "SELECT value_json FROM preferences WHERE key = 'clock.showSeconds';") == false ]]
printf 'PASS: config-local database, native connection, integrity, and persisted removals\n'

if [[ ${1:-} == --ipc ]]; then
    cat > "$entry" <<QML
import Quickshell
import "file://$project_root/src/services"
Scope { readonly property bool loadTwitch: TwitchService.available }
QML
    qs -p "$entry" > "$test_dir/ipc.log" 2>&1 &
    qs_pid=$!
    ipc_ready=false
    for ((attempt=0; attempt<100; attempt++)); do
        if qs ipc -p "$entry" show 2>/dev/null | rg -q 'addUser'; then ipc_ready=true; break; fi
        sleep 0.05
    done
    if [[ $ipc_ready != true ]]; then cat "$test_dir/ipc.log"; exit 1; fi
    [[ $(qs ipc -p "$entry" call twitch addUser Zeta) == true ]]
    [[ $(qs ipc -p "$entry" call twitch addUser Alice) == true ]]
    [[ $(qs ipc -p "$entry" call twitch addUser ALICE) == false ]]
    qs ipc -p "$entry" call twitch exportUsers > "$test_dir/export.txt"
    [[ $(cat "$test_dir/export.txt") == $'alice\nzeta' ]]
    [[ $(qs ipc -p "$entry" call twitch removeUser alice) == true ]]
    [[ $(qs ipc -p "$entry" call twitch removeUser zeta) == true ]]
    [[ -z $(qs ipc -p "$entry" call twitch exportUsers) ]]
    qs ipc -p "$entry" call twitch reload
    printf 'PASS: Twitch IPC add, duplicate, export, remove, and reload\n'
fi
