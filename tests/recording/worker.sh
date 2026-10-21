#!/usr/bin/env bash
# Real detached workers, SQLite and signals; synthetic recorder, audio and desktop actions only.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-recording-test.XXXXXXXX)
worker_pid='' other_pid='' shell_pid=''
qs_bin=$(command -v qs)
cleanup() {
    result=$?
    if ((result != 0)); then
        [[ ! -f $test_dir/worker.log ]] || cat "$test_dir/worker.log" >&2
        [[ ! -f $test_dir/shell.log ]] || cat "$test_dir/shell.log" >&2
    fi
    for pid in "$worker_pid" "$other_pid" "$shell_pid"; do
        [[ -z $pid ]] || { kill -TERM "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }
    done
    if [[ -f $test_dir/recorder.pid ]]; then
        kill -TERM "$(cat "$test_dir/recorder.pid")" 2>/dev/null || true
    fi
    rm -rf -- "$test_dir"
}
trap cleanup EXIT
mkdir -p "$test_dir/src/services/recording" "$test_dir/src/services/launcher/providers/_common" "$test_dir/bin" "$test_dir/data"
mkdir -p "$test_dir/src/services/processes"
cp "$project_root/src/services/processes/process-identity.sh" "$test_dir/src/services/processes/"
worker="$test_dir/src/services/recording/recording-worker.sh"
cp "$project_root/src/services/recording/recording-worker.sh" "$worker"
export RECORDING_TEST="$test_dir" QS_PICKER_EXECUTABLE="$test_dir/bin/alerts"
export PATH="$test_dir/bin:$PATH"
database="$test_dir/data/recording-runtime.db"
prepared_options() {
    jq -nc --arg root "$RECORDING_TEST" --arg audio "${RECORDING_TEST_AUDIO:-none}" \
        '{filename:($root+"/result.mp4"),command:[($root+"/bin/recorder"),"--no-damage","-f",($root+"/result.mp4")],
        loopback:(if $audio=="both" then ["module-loopback","source=test.mic","sink=test.output"] else [] end)}'
}
cat > "$test_dir/bin/recorder" <<'JS'
#!/usr/bin/env node
const fs = require('fs'), root = process.env.RECORDING_TEST;
fs.writeFileSync(root + '/recorder.pid', String(process.pid));
fs.appendFileSync(root + '/actions', 'capture\n');
const timer = setInterval(() => {}, 100);
process.on('SIGINT', () => {
    fs.appendFileSync(root + '/actions', 'interrupt\n');
    setTimeout(() => {
        fs.writeFileSync(root + '/result.mp4', 'synthetic video');
        clearInterval(timer);
        process.exit(0);
    }, 350);
});
if (process.env.RECORDING_TEST_FAIL === '1') process.exit(1);
JS
cat > "$test_dir/bin/alerts" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$RECORDING_TEST/alerts"
if [[ ${5:-} == capture && ${6:-} == ready ]]; then
    printf 'readiness\n' >> "$RECORDING_TEST/actions"
    [[ ! -e $RECORDING_TEST/readiness-unavailable ]] || exit 2
    if [[ -e $RECORDING_TEST/readiness-held ]]; then printf 'false\n'; else printf 'true\n'; fi
fi
SH
cat > "$test_dir/bin/pactl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$RECORDING_TEST/audio"
case $1 in
    load-module) printf '99\n' ;;
    unload-module) [[ ! -e $RECORDING_TEST/fail-cleanup ]] ;;
esac
SH
cat > "$test_dir/src/services/launcher/providers/_common/utils.sh" <<'SH'
open_file_explorer() { printf 'reveal\n' >> "$RECORDING_TEST/actions"; }
SH
chmod +x "$test_dir/bin/"*
control() { bash "$worker" "$1" "$database" "$test_dir"; }
state() { control --status | jq -r .state; }
wait_state() {
    for ((attempt=0;attempt<100;attempt++)); do
        [[ $(state) != "$1" ]] || return 0
        sleep 0.03
    done
    printf 'Timed out waiting for %s; got %s\n' "$1" "$(state)" >&2
    cat "$test_dir/worker.log" >&2
    exit 1
}
start_worker() { bash "$worker" --run "$database" "$test_dir" "$(prepared_options)" > "$test_dir/worker.log" 2>&1 & worker_pid=$!; }
reset_logs() { : > "$test_dir/actions"; : > "$test_dir/alerts"; : > "$test_dir/audio"; rm -f "$test_dir/recorder.pid" "$test_dir/result.mp4"; }

reset_logs
start_worker
wait_state starting
bash "$worker" --run "$database" "$test_dir" "$(prepared_options)" & other_pid=$!
wait "$other_pid"; other_pid=''
wait_state recording
for ((attempt=0;attempt<100;attempt++)); do
    [[ ! -s $test_dir/recorder.pid ]] || break
    sleep 0.02
done
[[ $(rg -c '^capture$' "$test_dir/actions") == 1 ]]
start_ns=$(date +%s%N)
control --toggle >/dev/null
control --toggle >/dev/null
wait "$worker_pid"; worker_pid=''
elapsed=$(( ($(date +%s%N)-start_ns)/1000000 ))
[[ $(state) == idle && -s $test_dir/result.mp4 ]]
[[ $(rg -c '^interrupt$' "$test_dir/actions") == 1 ]]
rg -q 'recording.worker.finishing' "$test_dir/alerts"
rg -q '^reveal$' "$test_dir/actions"
[[ $elapsed -lt 2500 ]]
printf 'PASS: duplicate setup excluded, one owned interrupt, repeated stop safe, finalization awaited (%s ms)\n' "$elapsed"

reset_logs
start_worker
wait_state starting
control --toggle >/dev/null
wait "$worker_pid"; worker_pid=''
[[ $(state) == idle && ! -e $test_dir/recorder.pid ]]
rg -q 'recording.worker.cancelled' "$test_dir/alerts"
printf 'PASS: starting-delay shortcut cancels capture\n'

reset_logs
touch "$test_dir/readiness-held" "$test_dir/readiness-unavailable"
start_worker
wait_state starting
for ((attempt=0;attempt<100;attempt++)); do
    if rg -q '^readiness$' "$test_dir/actions"; then break; fi
    sleep 0.03
done
[[ $(state) == starting && ! -e $test_dir/recorder.pid ]]
rm "$test_dir/readiness-unavailable"
sleep 0.15
[[ $(state) == starting && ! -e $test_dir/recorder.pid ]]
rm "$test_dir/readiness-held"
wait_state recording
control --toggle >/dev/null
wait "$worker_pid"; worker_pid=''
rg -Fq 'postMessage recording recording.worker.starting  [] success 1000 true' "$test_dir/alerts"
printf 'PASS: missing readiness retries through bar reconnect, closing overlays block capture, and readiness releases the same worker\n'

reset_logs
touch "$test_dir/readiness-held"
start_worker
wait_state starting
for ((attempt=0;attempt<100;attempt++)); do
    if rg -q '^readiness$' "$test_dir/actions"; then break; fi
    sleep 0.03
done
control --toggle >/dev/null
wait "$worker_pid"; worker_pid=''
rm "$test_dir/readiness-held"
[[ $(state) == idle && ! -e $test_dir/recorder.pid ]]
rg -q 'recording.worker.cancelled' "$test_dir/alerts"
printf 'PASS: recording shortcut cancels during shared-readiness waiting without starting a recorder\n'

reset_logs
touch "$test_dir/readiness-unavailable"
start_worker
if wait "$worker_pid"; then exit 1; fi
worker_pid=''
rm "$test_dir/readiness-unavailable"
[[ $(state) == idle && ! -e $test_dir/recorder.pid ]]
rg -q 'recording.worker.notReady' "$test_dir/alerts"
printf 'PASS: unavailable readiness cancels startup within the bounded retry and releases its runtime claim\n'

reset_logs
if bash "$worker" --run "$database" "$test_dir" > "$test_dir/worker.log" 2>&1; then exit 1; fi
[[ $(state) == idle && ! -e $test_dir/recorder.pid ]]
printf 'PASS: missing prepared options release the runtime claim without capture\n'

reset_logs
RECORDING_TEST_AUDIO=both start_worker
wait_state recording
control --toggle >/dev/null
wait "$worker_pid"; worker_pid=''
rg -q '^load-module module-loopback source=test.mic sink=test.output$' "$test_dir/audio"
[[ $(rg -c '^unload-module 99$' "$test_dir/audio") == 1 ]]
printf 'PASS: combined audio loads once and is released after recorder exit\n'

reset_logs
RECORDING_TEST_AUDIO=both RECORDING_TEST_FAIL=1 start_worker
if wait "$worker_pid"; then exit 1; fi
worker_pid=''
[[ $(state) == idle ]]
rg -q '^unload-module 99$' "$test_dir/audio"
rg -q 'recording.worker.error' "$test_dir/alerts"
! rg -q '^reveal$' "$test_dir/actions"
printf 'PASS: recorder failure cleans audio and never claims a saved file\n'

# A reused PID, different start time, or previous boot cannot receive a signal.
sleep 30 & other_pid=$!
boot=$(cat /proc/sys/kernel/random/boot_id)
saved=$(jq -nc --argjson pid "$other_pid" --arg boot "$boot" '{pid:$pid,start:"incorrect",boot:$boot,state:"recording",token:"stale"}')
saved_hex=$(printf '%s' "$saved" | od -An -v -tx1 | tr -d ' \n')
sqlite3 "$database" "INSERT INTO recording_session VALUES(1,'stale',CAST(X'$saved_hex' AS TEXT));"
[[ $(state) == idle ]]
kill -0 "$other_pid"
kill "$other_pid"; wait "$other_pid" || true; other_pid=''
[[ $(stat -c %a "$database") == 600 ]]
printf 'PASS: stale process identities are cleared without signaling a reused PID; runtime DB is private\n'

# Simulate owner failure with a synthetic child; recovery signals only the recorded identity once.
reset_logs
start_worker
wait_state recording
kill -KILL "$worker_pid"; wait "$worker_pid" 2>/dev/null || true; worker_pid=''
wait_state recovering
wait_state idle
[[ $(rg -c '^interrupt$' "$test_dir/actions") == 1 ]]
printf 'PASS: dead-owner recovery finishes its surviving recorder without repeated interrupts\n'

# A failed audio cleanup remains recoverable rather than silently forgetting its module.
reset_logs
touch "$test_dir/fail-cleanup"
RECORDING_TEST_AUDIO=both start_worker
wait_state recording
control --toggle >/dev/null
if wait "$worker_pid"; then exit 1; fi
worker_pid=''
[[ $(sqlite3 "$database" 'SELECT count(*) FROM recording_session;') == 1 ]]
rm "$test_dir/fail-cleanup"
[[ $(state) == idle ]]
printf 'PASS: audio cleanup failure preserves its runtime record for retry\n'

# Production controller, independent worker, real automatic QML reload and full bar-process restart.
mkdir -p "$test_dir/src/config"
cp -r "$project_root/src/i18n" "$test_dir/src/i18n"
mkdir -m 700 "$test_dir/runtime"
cp "$project_root/src/services/recording/RecordingService.qml" "$test_dir/src/services/recording/"
cp "$project_root/src/services/recording/qmldir" "$test_dir/src/services/recording/"
# Setup choices have their own production-component suite. Mock only that UI here.
cat > "$test_dir/src/services/recording/RecordingSetup.qml" <<'QML'
import QtQml
import Quickshell
Scope {
    property bool active: false
    signal prepared(var options)
    signal failed(string message)
    function open() { if (!active) { active = true; submit.start() } }
    Timer {
        id: submit; interval: 30
        onTriggered: {
            active = false
            const folder = Quickshell.env("RECORDING_TEST")
            prepared({filename:folder+"/result.mp4",command:[folder+"/bin/recorder","--no-damage","-f",folder+"/result.mp4"],loopback:[]})
        }
    }
}
QML
printf 'singleton RecordingService 1.0 recording/RecordingService.qml\nsingleton DbService 1.0 DbService.qml\nsingleton AlertService 1.0 AlertService.qml\n' > "$test_dir/src/services/qmldir"
printf 'pragma Singleton\nimport QtQml\nQtObject { readonly property bool ready: true }\n' > "$test_dir/src/services/DbService.qml"
printf 'pragma Singleton\nimport QtQml\nQtObject { function post(id, text, severity, duration) { console.log(text) } }\n' > "$test_dir/src/services/AlertService.qml"
cat > "$test_dir/src/config/Config.qml" <<'QML'
pragma Singleton
import QtQml
import Quickshell
QtObject {
    readonly property string databasePath: Quickshell.shellPath("data/quickshell.db")
    readonly property string language: "en"
    readonly property string testThemeColor: "before"
}
QML
printf 'singleton Config 1.0 Config.qml\n' > "$test_dir/src/config/qmldir"
sed 's@"../../src@"src@g' "$project_root/tests/recording/service.qml" > "$test_dir/shell.qml"
export QS_NO_RELOAD_POPUP=1 QT_QPA_PLATFORM=offscreen QT_NO_XDG_DESKTOP_PORTAL=1 XDG_RUNTIME_DIR="$test_dir/runtime"
export XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$test_dir/no-session-bus"
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
start_shell() { "$qs_bin" -p "$test_dir" > "$test_dir/shell.log" 2>&1 & shell_pid=$!; }
ipc() { "$qs_bin" ipc -p "$test_dir" call "$@" 2>/dev/null; }
wait_ipc() {
    for ((attempt=0;attempt<100;attempt++)); do
        [[ $(ipc "$1" "$2" || true) != "$3" ]] || return 0
        sleep 0.05
    done
    printf 'IPC %s %s expected %s; received %s\n' "$1" "$2" "$3" "$(ipc "$1" "$2" || true)" >&2
    cat "$test_dir/shell.log" >&2
    exit 1
}
reset_logs
start_shell
wait_ipc fixture configuration before
ipc recording toggle >/dev/null
wait_state starting
ipc recording toggle >/dev/null
wait_state idle
[[ ! -e $test_dir/recorder.pid ]]
wait_ipc recording status "{\"state\":\"idle\",\"active\":false,\"filename\":\"\"}"
printf 'PASS: controller queues cancellation across worker startup before capture begins\n'
reset_logs
ipc recording toggle >/dev/null
wait_state recording
owner=$(sqlite3 "$database" "SELECT json_extract(payload,'$.pid') FROM recording_session;")
for ((attempt=0;attempt<100;attempt++)); do
    [[ ! -s $test_dir/recorder.pid ]] || break
    sleep 0.02
done
recorder=$(cat "$test_dir/recorder.pid")
wait_ipc recording status "{\"state\":\"recording\",\"active\":true,\"filename\":\"$test_dir/result.mp4\"}"
# Preserve the watched inode: Quickshell 0.3.2 can miss sed -i replacement events.
sed 's/"before"/"after"/' "$test_dir/src/config/Config.qml" > "$test_dir/config-updated.qml"
cat "$test_dir/config-updated.qml" > "$test_dir/src/config/Config.qml"
wait_ipc fixture configuration after
[[ $(sqlite3 "$database" "SELECT json_extract(payload,'$.pid') FROM recording_session;") == "$owner" ]]
kill -0 "$recorder"
printf 'PASS: automatic config/theme reload applies during capture without replacing the worker or recorder\n'

kill -TERM "$shell_pid"; wait "$shell_pid" || true; shell_pid=''
kill -0 "$owner"; kill -0 "$recorder"
start_shell
wait_ipc fixture configuration after
wait_ipc recording status "{\"state\":\"recording\",\"active\":true,\"filename\":\"$test_dir/result.mp4\"}"
[[ $(sqlite3 "$database" "SELECT json_extract(payload,'$.pid') FROM recording_session;") == "$owner" ]]
ipc recording toggle >/dev/null
wait_state idle
[[ $(rg -c '^interrupt$' "$test_dir/actions") == 1 ]]
! rg -q 'TypeError:|ReferenceError:|Failed to load configuration' "$test_dir/shell.log"
printf 'PASS: restarted controller recovers the detached recording from SQLite and stops the same recorder\n'
