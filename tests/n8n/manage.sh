#!/usr/bin/env bash
# Isolated SQLite, loopback API, masked form and mocked browser. No live credentials/actions.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-n8n-test.XXXXXXXX)
api_pid=''
cleanup() { if [[ -n $api_pid ]]; then kill "$api_pid" 2>/dev/null || true; wait "$api_pid" 2>/dev/null || true; fi; rm -rf -- "$fixture"; }
trap cleanup EXIT
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/bin" "$fixture/home"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
node - "$fixture/src/config/Config.qml" <<'JS'
const fs=require('node:fs'),file=process.argv[2];
fs.writeFileSync(file,fs.readFileSync(file,'utf8')
    .replace('clipboardMonitorEnabled: true','clipboardMonitorEnabled: false'));
JS
sed 's@"../../src@"src@g' "$repo/tests/n8n/manage.qml" > "$fixture/shell.qml"
cat > "$fixture/bin/qutebrowser" <<'SH'
#!/usr/bin/env bash
jq -cn --args '$ARGS.positional' -- "$@" >> "$N8N_TEST_DIR/actions"
SH
chmod +x "$fixture/bin/qutebrowser"
printf initial > "$fixture/mode"
node "$repo/tests/n8n/server.mjs" "$fixture" > "$fixture/server.log" 2>&1 &
api_pid=$!
for ((attempt=0;attempt<100;attempt++)); do [[ -f $fixture/port ]] && break; sleep .02; done
[[ -f $fixture/port ]] || { cat "$fixture/server.log"; exit 1; }
export N8N_TEST_DIR="$fixture" N8N_TEST_URL="http://127.0.0.1:$(cat "$fixture/port")"
export PATH="$fixture/bin:$PATH" HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/runtime"
export XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 QT_QPA_PLATFORMTHEME=generic XDG_CURRENT_DESKTOP=
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
for phase in setup restart; do
    N8N_TEST_PHASE="$phase" timeout 30 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
    if ! rg -q 'PASS: n8n' "$fixture/log" || rg -q 'N8N FAIL:|TypeError:|ReferenceError:|Failed to load configuration|Binding loop' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
    rg 'PASS: n8n' "$fixture/log"
    if [[ $phase == setup ]]; then request_count=$(wc -l < "$fixture/requests")
    else [[ $(wc -l < "$fixture/requests") == "$request_count" ]]; fi
done
jq -se 'all(.[]; .method=="GET" and .keyCorrect and (.path|endswith("/api/v1/workflows"))) and any(.cursor=="next +&?")' "$fixture/requests" >/dev/null
jq -se 'length==1 and (.[0][-1]|endswith("/a/workflow/same"))' "$fixture/actions" >/dev/null
[[ $(sqlite3 "$fixture/data/quickshell.db" 'PRAGMA user_version; PRAGMA integrity_check;') == $'16\nok' ]]
if rg -q 'fixture-a|fixture-b|discard-me' "$fixture/log"; then printf 'FAIL: private response/key leaked to logs\n'; exit 1; fi
printf 'PASS: bounded GET pagination, independent instance failures, no redirects, cached launches and private persistence\n'
