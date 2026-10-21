#!/usr/bin/env bash
# Detached recorder owner and controller. Runtime SQLite is deliberately outside backups.
set -uo pipefail
worker_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
action=${1:?}; database=${2:?}; config_root=${3:?}
export QS_PICKER_CONFIG=$config_root
umask 077
# Ignore duplicate requests during registration; setup preserves its existing picker.
trap ':' USR1
[[ -d ${database%/*} && -O ${database%/*} && ! -L $database ]] || exit 2
[[ ! -e $database || ( -f $database && -O $database ) ]] || exit 2
sql() { sqlite3 -batch -cmd '.timeout 5000' "$database" "$1"; }
hex() { printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n'; }
sql 'CREATE TABLE IF NOT EXISTS recording_session (id INTEGER PRIMARY KEY CHECK(id=1), token TEXT NOT NULL, payload TEXT NOT NULL);' || exit 2
chmod 600 -- "$database" || exit 2
source "$worker_dir/../processes/process-identity.sh" || exit 2
boot=$PROCESS_BOOT_ID
identity() { process_identity "$@"; }
alive() { process_alive "$@"; }
alert() {
    case $1 in
        post|postCapture)
            local capture_blocking=false
            [[ $1 == postCapture ]] && capture_blocking=true
            shift
            # JSON whitespace prevents qs from expanding the array as CLI arguments.
            "${QS_PICKER_EXECUTABLE:-qs}" ipc -p "$config_root" call alerts postMessage "$1" "$2" ' []' "$3" "$4" "$capture_blocking" >/dev/null 2>&1 || true
            ;;
        *) "${QS_PICKER_EXECUTABLE:-qs}" ipc -p "$config_root" call alerts "$@" >/dev/null 2>&1 || true ;;
    esac
}
read_session() { sql 'SELECT payload FROM recording_session WHERE id=1;'; }
delete_session() { sql "DELETE FROM recording_session WHERE token=CAST(X'$(hex "$1")' AS TEXT);"; }

recover_session() {
    local saved=$1 pid start saved_boot child child_start state token loopback
    read -r pid start saved_boot child child_start state token loopback < <(jq -r \
        '[.pid,.start,.boot,(.recorderPid // 0),(.recorderStart // "-"),.state,.token,(.loopback // "-")] | @tsv' <<< "$saved")
    if alive "$pid" "$start" "$saved_boot"; then printf '%s\n' "$saved"; return; fi
    if alive "$child" "$child_start" "$saved_boot"; then
        # A crashed owner must not leave a recorder running or signal it repeatedly.
        if [[ $state != recovering ]]; then
            saved=$(jq -c '.state="recovering"' <<< "$saved")
            sql "UPDATE recording_session SET payload=CAST(X'$(hex "$saved")' AS TEXT) WHERE token=CAST(X'$(hex "$token")' AS TEXT);" || return 2
            alive "$child" "$child_start" "$saved_boot" && kill -INT "$child"
            alert post recording 'recording.worker.finishing' info 0
        fi
        printf '%s\n' "$saved"
        return
    fi
    # Do not unload a reused PulseAudio module after a reboot.
    if [[ $boot == "$saved_boot" && $loopback =~ ^[0-9]+$ ]]; then
        pactl unload-module "$loopback" >/dev/null 2>&1 || return 2
    fi
    delete_session "$token" || return 2
    alert dismiss recording
    printf '{}\n'
}

case $action in
    --status|--toggle)
        saved=$(read_session) || exit 2
        if [[ -n $saved ]]; then saved=$(recover_session "$saved") || exit 2; else saved='{}'; fi
        if [[ $action == --toggle && $(jq -r '.state // "idle"' <<< "$saved") != idle ]]; then
            pid=$(jq -r '.pid' <<< "$saved")
            start=$(jq -r '.start' <<< "$saved")
            saved_boot=$(jq -r '.boot' <<< "$saved")
            alive "$pid" "$start" "$saved_boot" && kill -USR1 "$pid"
        fi
        jq -c --arg action "$action" '{state:(.state // "idle"),filename:(.filename // ""),
            start:($action == "--toggle" and .state == null)}' <<< "$saved"
        exit ;;
    --run) ;;
    *) exit 2 ;;
esac

token=$(cat /proc/sys/kernel/random/uuid) || exit 2
start=$(identity "$$") || exit 2
state=configuring recorder_pid=0 recorder_start='-' loopback_id='' filename='' delay_pid=0
cancelled=false stop_time=0
payload() {
    jq -nc --arg token "$token" --argjson pid "$$" --arg start "$start" --arg boot "$boot" \
        --arg state "$state" --argjson recorderPid "$recorder_pid" --arg recorderStart "$recorder_start" \
        --arg loopback "$loopback_id" --arg filename "$filename" \
        '{token:$token,pid:$pid,start:$start,boot:$boot,state:$state,recorderPid:$recorderPid,
            recorderStart:$recorderStart,loopback:$loopback,filename:$filename}'
}
publish() {
    local json
    json=$(payload) || return 1
    sql "UPDATE recording_session SET payload=CAST(X'$(hex "$json")' AS TEXT) WHERE token=CAST(X'$(hex "$token")' AS TEXT);" >/dev/null
}
# Atomic claim prevents concurrent shortcuts/reloads from launching duplicate pickers.
saved=$(read_session) || exit 2
[[ -z $saved ]] || recover_session "$saved" >/dev/null || exit 2
json=$(payload) || exit 2
claimed=$(sql "INSERT OR IGNORE INTO recording_session VALUES(1,CAST(X'$(hex "$token")' AS TEXT),CAST(X'$(hex "$json")' AS TEXT)); SELECT changes();") || exit 2
[[ $claimed == 1 ]] || exit 0

request_stop() {
    case $state in
        configuring|stopping|finalizing|recovering) return ;;
        starting)
            cancelled=true
            [[ $delay_pid == 0 ]] || kill -TERM "$delay_pid" 2>/dev/null || true ;;
        recording)
            state=stopping
            stop_time=$(date +%s%3N)
            publish
            # wf-recorder installs its own SIGINT handler, even as a background child.
            alive "$recorder_pid" "$recorder_start" "$boot" && kill -INT "$recorder_pid"
            alert post recording 'recording.worker.finishing' info 0 ;;
    esac
}
cleanup() {
    trap '' USR1
    if alive "$recorder_pid" "$recorder_start" "$boot"; then
        kill -INT "$recorder_pid" 2>/dev/null || true
        wait "$recorder_pid" 2>/dev/null || true
    fi
    if [[ -n $loopback_id ]]; then
        # Retain the runtime row for a later cleanup retry if PulseAudio is unavailable.
        pactl unload-module "$loopback_id" >/dev/null 2>&1 || return
        loopback_id=''
        publish
    fi
    delete_session "$token" >/dev/null
}
trap cleanup EXIT
trap request_stop USR1

prepared=${4:-}
[[ -n $prepared ]] || { alert post recording 'recording.worker.optionsMissing' error 3000; exit 2; }
jq -e '(.command | type == "array" and length > 0 and all(.[]; type == "string"))
    and (.loopback | type == "array" and all(.[]; type == "string")) and (.filename | type == "string")' \
    <<< "$prepared" >/dev/null || exit 2
filename=$(jq -r '.filename' <<< "$prepared")
[[ -n $filename && $filename == /* ]] || exit 2
mkdir -p -- "${filename%/*}" || { alert post recording 'recording.worker.folderUnavailable' error 3000; exit 1; }
mapfile -d '' -t command < <(jq -j '.command[] | ., "\u0000"' <<< "$prepared")
mapfile -d '' -t loopback < <(jq -j '.loopback[] | ., "\u0000"' <<< "$prepared")
if ((${#loopback[@]})); then
    loopback_id=$(pactl load-module "${loopback[@]}") || { alert post recording 'recording.worker.error' error 3000; exit 1; }
    [[ $loopback_id =~ ^[0-9]+$ ]] || exit 2
    publish
    sleep 0.25
fi
state=starting
publish
alert postCapture recording 'recording.worker.starting' success 1000
sleep 1 & delay_pid=$!
wait "$delay_pid" || true
delay_pid=0
alert dismiss recording
# The detached worker queries shared presentation readiness, not an animation duration.
# Retry through a bar reload, but never assume a missing IPC response means ready.
ready_deadline=$((SECONDS + 10))
while ! $cancelled; do
    if ((SECONDS >= ready_deadline)); then
        alert post recording 'recording.worker.notReady' error 3000
        exit 1
    fi
    capture_ready=$(timeout --kill-after=0.1 1 "${QS_PICKER_EXECUTABLE:-qs}" ipc -p "$config_root" call capture ready 2>/dev/null) || capture_ready=''
    [[ $capture_ready != true ]] || break
    sleep 0.05 & delay_pid=$!
    wait "$delay_pid" || true
    delay_pid=0
done
if $cancelled; then alert post recording 'recording.worker.cancelled' info 1000; exit 0; fi

"${command[@]}" & recorder_pid=$!
recorder_start=$(identity "$recorder_pid") || recorder_start='-'
state=recording
publish
recorder_status=0
# A trapped shortcut interrupts Bash's wait, not the child. Continue waiting for finalization.
while true; do
    wait "$recorder_pid"; recorder_status=$?
    alive "$recorder_pid" "$recorder_start" "$boot" || break
done
state=finalizing
publish
if ! cleanup; then alert post recording 'recording.worker.cleanup' error 3000; exit 1; fi
# cleanup is idempotent, but do not unload an already released module from EXIT.
loopback_id=''
trap - EXIT
if [[ $recorder_status != 0 || ! -s $filename ]]; then
    alert post recording 'recording.worker.error' error 3000
    exit 1
fi
alert post recording 'recording.worker.stopped' success 1000
if ((stop_time > 0)); then printf 'Recording stop completed in %s ms\n' "$(( $(date +%s%3N) - stop_time ))"; fi
source "$worker_dir/../launcher/providers/_common/utils.sh"
open_file_explorer "$filename"
