#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-twitch-fallback.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/config/data" "$test_dir/bin"
mkdir -m 700 "$test_dir/runtime"
export XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache"
export QT_QPA_PLATFORM=offscreen QT_NO_XDG_DESKTOP_PORTAL=1
export TWITCH_FALLBACK_STATE="$test_dir" TWITCH_FALLBACK_PNG="$project_root/src/assets/twitch.png" PATH="$test_dir/bin:$PATH"
printf '#!/bin/sh\nexit 0\n' > "$test_dir/bin/ping"
printf '#!/bin/sh\nexit 1\n' > "$test_dir/bin/solaar"
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
jq -cn --arg path "$path" --args '{path: $path, logins: $ARGS.positional}' "${logins[@]}" >> "$TWITCH_FALLBACK_STATE/queries"
case $path in
    streams)
        [[ $query == *first=100* && ${#logins[@]} -le 100 ]]
        if [[ -f $TWITCH_FALLBACK_STATE/fail-batch ]]; then
            if ((${#logins[@]} < 100)); then printf '{"error":"Failed batch"}\n'; exit 1; fi
            printf '{"data":[]}\n'
            exit 0
        fi
        jq -cn --arg phase "$TWITCH_FALLBACK_PHASE" --args '{data: ($ARGS.positional | map(select($phase == "batch" or . == "tomato" or ($phase != "neither" and . == (if ["fallback","fallback-restart"] | index($phase) then "potato" else "banana" end)) or ((["link","both","edit"] | index($phase)) and . == "potato"))) | map({id: (. + "-1"), user_login: ., viewer_count: 123, title: (. + " title"), game_name: (. + " game")}))}' "${logins[@]}"
        ;;
    users)
        ((${#logins[@]} <= 100))
        jq -cn --args '{data: ($ARGS.positional | map({login: ., id: ., profile_image_url: ("https://avatars.test/" + . + ".png")}))}' "${logins[@]}"
        ;;
    schedule)
        jq -cn --arg start "$(date -u -d '+2 days' +%FT%TZ)" '{data: {segments: [{start_time: $start, canceled_until: null}]}}'
        ;;
    *) exit 1;;
esac
MOCK
cat > "$test_dir/bin/curl" <<'MOCK'
#!/usr/bin/env bash
cat "$TWITCH_FALLBACK_PNG"
MOCK
cat > "$test_dir/bin/notify-send" <<'MOCK'
#!/usr/bin/env bash
jq -cn --args '$ARGS.positional' -- "$@" >> "$TWITCH_FALLBACK_STATE/alerts"
MOCK
chmod 700 "$test_dir/bin/"*
sqlite3 "$test_dir/config/data/quickshell.db" "CREATE TABLE twitch_users (login TEXT PRIMARY KEY COLLATE NOCASE, added_at INTEGER NOT NULL); INSERT INTO twitch_users VALUES ('banana',1),('tomato',2); PRAGMA user_version=6;"
cat > "$test_dir/config/shell.qml" <<QML
import QtQuick
import Quickshell
Scope { Loader { source: "file://$project_root/tests/storage/twitch-fallback-smoke.qml" } }
QML
for phase in link both main fallback fallback-restart neither edit; do
    output=$(TWITCH_FALLBACK_PHASE="$phase" timeout 12 qs -p "$test_dir/config/shell.qml" 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
    printf '%s\n' "$output"
    [[ $output == *"PASS: fallback $phase"* && $output != *'FALLBACK FAIL:'* \
        && $output != *'TypeError:'* && $output != *'ReferenceError:'* && $output != *'Binding loop detected'* ]]
    if [[ $phase != edit ]]; then
        jq -se 'length > 0 and all(.[]; .[-1] | contains("`potato`") | not)' "$test_dir/alerts" >/dev/null
    fi
    if [[ $phase == fallback ]]; then
        fallback_alerts=$(wc -l < "$test_dir/alerts")
        # Offscreen Qt reports URL requests instead of opening a real browser.
        [[ $(rg -Fc "QPlatformServices::openUrl() for 'https://www.twitch.tv/banana'" <<< "$output") == 1 ]]
        [[ $(rg -Fc "QPlatformServices::openUrl() for 'https://www.twitch.tv/potato'" <<< "$output") == 2 ]]
    fi
    if [[ $phase == fallback-restart || $phase == neither ]]; then [[ $(wc -l < "$test_dir/alerts") == "$fallback_alerts" ]]; fi
done
sqlite3 "$test_dir/config/data/quickshell.db" "DELETE FROM twitch_users; DELETE FROM twitch_schedules; DELETE FROM twitch_avatars; DELETE FROM twitch_notified_streams; WITH RECURSIVE numbers(n) AS (VALUES(1) UNION ALL SELECT n+1 FROM numbers WHERE n<51) INSERT INTO twitch_users (login, fallback_login, added_at) SELECT 'banana_'||n, 'potato_'||n, n FROM numbers;"
output=$(TWITCH_FALLBACK_PHASE=batch timeout 12 qs -p "$test_dir/config/shell.qml" 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
printf '%s\n' "$output"
[[ $output == *'PASS: fallback batch'* && $output != *'FALLBACK FAIL:'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* ]]
jq -se 'any(.[]; .path == "streams" and (.logins | index("potato"))) and any(.[]; .path == "users" and (.logins | index("potato")))' "$test_dir/queries" >/dev/null
[[ $(sqlite3 "$test_dir/config/data/quickshell.db" 'PRAGMA integrity_check;') == ok ]]
printf 'PASS: fallback migration, selection, metadata, silent transitions, persistence, editor, linking, removal, Undo, unlinking, conflicts and API batches\n'
