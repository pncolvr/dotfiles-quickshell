#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-storage-test.XXXXXX)
mkdir -p "$test_dir/config/data"
entry="$test_dir/config/shell.qml"
qs_pid=""
cleanup() {
    if [[ -n $qs_pid ]]; then kill "$qs_pid" 2>/dev/null || true; wait "$qs_pid" 2>/dev/null || true; fi
    rm -rf -- "$test_dir"
    rm -f -- "$entry"
}
trap cleanup EXIT
mkdir -m 700 "$test_dir/runtime"
mkdir "$test_dir/bin"
export XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache"
export QT_QPA_PLATFORM=offscreen
export STORAGE_TEST_STATE="$test_dir" PATH="$test_dir/bin:$PATH"
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
#!/usr/bin/env python3
import datetime
import json
import os
import sys
import urllib.parse
query = sys.argv[-1]
path, _, params = query.partition('?')
params = urllib.parse.parse_qs(params)
if path == 'streams':
    phase = os.environ.get('STORAGE_TEST_PHASE')
    if phase == 'live-error':
        print(json.dumps({'error': 'API unavailable'}))
        sys.exit(1)
    result = {'data': [{'id': f'{login}-stream-{2 if login == "alice" and phase == "live-new-stream" else 1}',
                       'user_login': login, 'viewer_count': 123, 'title': 'Live test stream', 'game_name': 'Game'}
                       for login in params.get('user_login', [])] if phase in ('live-add', 'live-restart', 'live-new-stream') else []}
elif path == 'users':
    suffix = '-v2' if os.environ.get('STORAGE_TEST_PHASE') in ('avatar-failure', 'avatar-update') else ''
    result = {'data': [{'login': login, 'id': login, 'profile_image_url': f'https://avatars.test/{login}{suffix}.png'} for login in params['login']]}
elif path == 'schedule':
    login = params['broadcaster_id'][0]
    with open(os.path.join(os.environ['STORAGE_TEST_STATE'], 'schedule-calls'), 'a') as log:
        log.write(login + '\n')
    start = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=2)
    result = {'data': {'segments': [{'start_time': start.isoformat(), 'canceled_until': None}]}}
else:
    sys.exit(1)
print(json.dumps(result))
if os.environ.get('STORAGE_TEST_PHASE') in ('seed', 'live-add'):
    # The CLI can fail in its update check after returning a successful API response.
    print('panic: runtime error in CLI update check', file=sys.stderr)
    sys.exit(2)
MOCK
cat > "$test_dir/bin/curl" <<'MOCK'
#!/usr/bin/env python3
import os
import struct
import sys
import time
import zlib
with open(os.path.join(os.environ['STORAGE_TEST_STATE'], 'avatar-calls'), 'a') as log:
    log.write(sys.argv[-1] + '\n')
time.sleep(0.15)
if os.environ.get('STORAGE_TEST_PHASE') == 'avatar-failure':
    sys.exit(1)
def chunk(kind, payload):
    return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload))
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 6, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(b'\x00\xff\x00\x00\xff')) + chunk(b'IEND', b'')
sys.stdout.buffer.write(png)
MOCK
chmod +x "$test_dir/bin/"*
cat > "$test_dir/bin/notify-send" <<'MOCK'
#!/usr/bin/env python3
import json
import os
import sys
with open(os.path.join(os.environ['STORAGE_TEST_STATE'], 'notify-calls'), 'a') as log:
    log.write(json.dumps(sys.argv[1:]) + '\n')
MOCK
chmod +x "$test_dir/bin/notify-send"
cat > "$entry" <<QML
import QtQuick
import Quickshell
Scope { Loader { source: "file://$project_root/tests/storage/storage-smoke.qml" } }
QML
for phase in seed restart avatar-failure avatar-update empty empty-restart live-add live-restart live-new-stream live-error live-offline live-offline-restart layout; do
    output=$(STORAGE_TEST_PHASE="$phase" timeout 12 qs -p "$entry" 2>&1) || {
        printf '%s\n' "$output" >&2
        exit 1
    }
    printf '%s\n' "$output"
    [[ ! -e $XDG_RUNTIME_DIR/twitch_online_$(id -u) ]]
    [[ $output == *"PASS: storage $phase"* && $output != *'STORAGE FAIL:'* \
        && $output != *'Failed to load configuration'* && $output != *'Binding loop detected'* \
        && $output != *'TypeError:'* && $output != *'ReferenceError:'* ]]
    if [[ $phase == seed ]]; then
        # Exercise an upgrade from the previous schema with existing users and caches.
        python3 - "$test_dir/config/data/quickshell.db" <<'PY'
import sqlite3
import sys
with sqlite3.connect(sys.argv[1]) as db:
    db.executescript('DROP TABLE twitch_notified_streams; PRAGMA user_version=3;')
PY
    fi
    if [[ $phase == restart ]]; then
        [[ $(wc -l < "$test_dir/avatar-calls") -eq 2 ]]
    fi
    if [[ $phase == empty-restart ]]; then
        # Alice's fresh cache is reused; only Bob needs a schedule request across restarts.
        [[ $(cat "$test_dir/schedule-calls") == bob ]]
    fi
    if [[ $phase == live-add ]]; then
        initial_live_alerts=$(wc -l < "$test_dir/notify-calls")
    fi
    if [[ $phase == live-restart ]]; then
        [[ $(wc -l < "$test_dir/notify-calls") -eq $initial_live_alerts ]]
    fi
    if [[ $phase == live-new-stream ]]; then
        python3 - "$test_dir/notify-calls" "$initial_live_alerts" <<'PY'
import json
import pathlib
import sys
calls = [json.loads(line) for line in pathlib.Path(sys.argv[1]).read_text().splitlines()]
assert len(calls) == int(sys.argv[2]) + 1, calls
assert calls[-1][-2:] == ['Live', '`alice`'], calls
assert not any(arg.startswith('--action') for call in calls for arg in call), calls
print('PASS: live alerts persist across restarts and only a new stream triggers another alert')
PY
    fi
    if [[ $phase == live-error ]]; then
        [[ $(wc -l < "$test_dir/notify-calls") -eq $((initial_live_alerts + 1)) ]]
    fi
    if [[ $phase == live-offline || $phase == live-offline-restart ]]; then
        python3 - "$test_dir/notify-calls" "$initial_live_alerts" <<'PY'
import json
import pathlib
import sys
calls = [json.loads(line) for line in pathlib.Path(sys.argv[1]).read_text().splitlines()]
assert len(calls) == int(sys.argv[2]) + 2, calls
assert calls[-1][-2:] == ['Offline', '`alice`  \n`bob`'], calls
print('PASS: offline alert emitted once and preserved across restarts')
PY
    fi
done
python3 - "$test_dir/config/data/quickshell.db" "$test_dir/data" <<'PY'
import pathlib
import sqlite3
import sys
database = pathlib.Path(sys.argv[1])
assert database.is_file() and not database.is_symlink()
files = list(pathlib.Path(sys.argv[2]).rglob('*.sqlite'))
assert len(files) == 1, files
assert not files[0].is_symlink()
with sqlite3.connect(files[0]) as connection:
    assert connection.execute("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table'").fetchone()[0] == 0
with sqlite3.connect(database) as db:
    assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
    assert db.execute('SELECT COUNT(*) FROM twitch_users').fetchone()[0] == 0
    assert db.execute('SELECT COUNT(*) FROM twitch_schedules').fetchone()[0] == 0
    assert db.execute('SELECT COUNT(*) FROM twitch_avatars').fetchone()[0] == 0
    assert db.execute('SELECT COUNT(*) FROM twitch_notified_streams').fetchone()[0] == 0
    assert db.execute('SELECT COUNT(*) FROM battery_receivers').fetchone()[0] == 0
    assert db.execute('SELECT value_json FROM preferences WHERE key = ?', ('clock.showSeconds',)).fetchone()[0] == 'false'
print('PASS: config-local database, native connection, integrity, and persisted removals')
PY

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
    python3 - "$test_dir/export.txt" <<'PY'
import pathlib
import sys
assert pathlib.Path(sys.argv[1]).read_text().splitlines() == ['alice', 'zeta']
PY
    [[ $(qs ipc -p "$entry" call twitch removeUser alice) == true ]]
    [[ $(qs ipc -p "$entry" call twitch removeUser zeta) == true ]]
    [[ -z $(qs ipc -p "$entry" call twitch exportUsers) ]]
    qs ipc -p "$entry" call twitch reload
    printf 'PASS: Twitch IPC add, duplicate, export, remove, and reload\n'
fi
