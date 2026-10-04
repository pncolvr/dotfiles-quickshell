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
cat > "$test_dir/bin/ping" <<'MOCK'
#!/usr/bin/env bash
exit 0
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
    result = {'data': []}
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
cat > "$entry" <<QML
import QtQuick
import Quickshell
Scope { Loader { source: "file://$project_root/tests/storage/storage-smoke.qml" } }
QML
for phase in seed restart avatar-failure avatar-update empty empty-restart; do
    output=$(STORAGE_TEST_PHASE="$phase" timeout 12 qs -p "$entry" 2>&1) || {
        printf '%s\n' "$output" >&2
        exit 1
    }
    printf '%s\n' "$output"
    [[ $output == *"PASS: storage $phase"* && $output != *'STORAGE FAIL:'* \
        && $output != *'Failed to load configuration'* && $output != *'Binding loop detected'* \
        && $output != *'TypeError:'* && $output != *'ReferenceError:'* ]]
    if [[ $phase == restart ]]; then
        [[ $(wc -l < "$test_dir/avatar-calls") -eq 2 ]]
    fi
done
# Alice has a fresh repository cache; only Bob should require an API request across restarts.
[[ $(cat "$test_dir/schedule-calls") == bob ]]
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
    assert db.execute('SELECT COUNT(*) FROM battery_receivers').fetchone()[0] == 0
    assert db.execute('SELECT value_json FROM preferences WHERE key = ?', ('clock.showSeconds',)).fetchone()[0] == 'false'
print('PASS: config-local database, native connection, integrity, and persisted removals')
PY

if [[ ${1:-} == --ipc ]]; then
    cat > "$entry" <<QML
import Quickshell
import "file://$project_root/services"
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
