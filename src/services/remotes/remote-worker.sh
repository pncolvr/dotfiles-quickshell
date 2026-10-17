#!/usr/bin/env bash
# Detached SSH/RDP owner. Credentials come from SQLite and reach FreeRDP through stdin.
set +x
set -uo pipefail
umask 077
ulimit -c 0
worker_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$worker_dir/../processes/process-identity.sh" || exit 2
action=${1:?} runtime=${2:?} entry_id=${3:-}
[[ -d ${runtime%/*} && -O ${runtime%/*} && ! -L $runtime ]] || exit 2
[[ ! -e $runtime || ( -f $runtime && -O $runtime ) ]] || exit 2
hex() { printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n'; }
sql() { sqlite3 -batch -cmd '.timeout 5000' "$runtime" "$1" 2>/dev/null; }
key="CAST(X'$(hex "$entry_id")' AS TEXT)"
sql 'CREATE TABLE IF NOT EXISTS remote_sessions (id TEXT PRIMARY KEY, token TEXT NOT NULL, payload TEXT NOT NULL);' || exit 2
chmod 600 -- "$runtime" || exit 2
child_alive() { local row=$1 child=$2; process_alive "$(jq -r ".$child.pid // 0" <<< "$row")" "$(jq -r ".$child.start // \"\"" <<< "$row")" "$(jq -r '.boot' <<< "$row")"; }
stop_child() {
    local row=$1 child=$2 signal=${3:-TERM}
    child_alive "$row" "$child" && kill -"$signal" "$(jq -r ".$child.pid" <<< "$row")" 2>/dev/null || true
}
recover() {
    local row=$1
    if process_alive "$(jq -r '.pid' <<< "$row")" "$(jq -r '.start' <<< "$row")" "$(jq -r '.boot' <<< "$row")"; then return; fi
    # Never mistake a reused PID or a process from a previous boot for our connection.
    local orphaned now
    orphaned=$(jq -r '.orphanedAt // 0' <<< "$row"); now=$(date +%s)
    if [[ $orphaned == 0 ]]; then
        row=$(jq -c --argjson now "$now" '.state="disconnecting" | .orphanedAt=$now' <<< "$row")
        sql "UPDATE remote_sessions SET payload=CAST(X'$(hex "$row")' AS TEXT) WHERE token=CAST(X'$(hex "$(jq -r '.token' <<< "$row")")' AS TEXT);" >/dev/null || return 2
    fi
    stop_child "$row" rdp; stop_child "$row" tunnel
    if [[ $orphaned != 0 ]] && ((now-orphaned>=3)); then stop_child "$row" rdp KILL; stop_child "$row" tunnel KILL; fi
    if ! child_alive "$row" rdp && ! child_alive "$row" tunnel; then
        sql "DELETE FROM remote_sessions WHERE token=CAST(X'$(hex "$(jq -r '.token' <<< "$row")")' AS TEXT);" >/dev/null
    fi
}
case $action in
    --status)
        while IFS= read -r row; do [[ -z $row ]] || recover "$row"; done < <(sql 'SELECT payload FROM remote_sessions;')
        sql "SELECT COALESCE(json_group_array(json_object('id',id,'state',json_extract(payload,'$.state'))),'[]') FROM remote_sessions;"
        exit ;;
    --disconnect)
        row=$(sql "SELECT payload FROM remote_sessions WHERE id=$key;") || exit 2
        [[ -n $row ]] || exit 0
        recover "$row"
        if process_alive "$(jq -r '.pid' <<< "$row")" "$(jq -r '.start' <<< "$row")" "$(jq -r '.boot' <<< "$row")"; then
            kill -USR1 "$(jq -r '.pid' <<< "$row")" 2>/dev/null || true
        fi
        exit ;;
    --run) ;;
    *) exit 2 ;;
esac
main_database=${4:?} config_root=${5:?} options=${6:?}
fail() {
    "${QS_PICKER_EXECUTABLE:-qs}" ipc -p "$config_root" call alerts postMessage remotes "$1" '[]' error 5000 false >/dev/null 2>&1 || true
    exit 1
}
[[ -f $main_database && -O $main_database && ! -L $main_database ]] || fail "remotes.worker.database"
jq -e 'all(.rdp,.ssh,.virsh,.probe; type=="array" and length>0 and all(.[];type=="string")) and (.waitSeconds|type=="number" and .>=1 and .<=300)' <<< "$options" >/dev/null || fail 'remotes.worker.configuration'
entry=$(sqlite3 -readonly -batch -cmd '.timeout 5000' "$main_database" "SELECT payload_json FROM remotes WHERE id=$key;" 2>/dev/null) || exit 2
jq -e '.enabled==true and (.type=="remote" or .type=="vm")' <<< "$entry" >/dev/null || exit 2
mapfile -d '' -t rdp_command < <(jq -j '.rdp[] | ., "\u0000"' <<< "$options")
mapfile -d '' -t ssh_command < <(jq -j '.ssh[] | ., "\u0000"' <<< "$options")
mapfile -d '' -t virsh_command < <(jq -j '.virsh[] | ., "\u0000"' <<< "$options")
mapfile -d '' -t probe_command < <(jq -j '.probe[] | ., "\u0000"' <<< "$options")
wait_seconds=$(jq -r '.waitSeconds' <<< "$options")
state=connecting stopping=false rdp_pid=0 rdp_start='' tunnel_pid=0 tunnel_start=''
start=$(process_identity "$$") || exit 2
token=$(cat /proc/sys/kernel/random/uuid) || exit 2
payload() {
    jq -nc --arg token "$token" --argjson pid "$$" --arg start "$start" --arg boot "$PROCESS_BOOT_ID" --arg state "$state" \
        --argjson rdpPid "$rdp_pid" --arg rdpStart "$rdp_start" --argjson tunnelPid "$tunnel_pid" --arg tunnelStart "$tunnel_start" \
        '{token:$token,pid:$pid,start:$start,boot:$boot,state:$state,rdp:{pid:$rdpPid,start:$rdpStart},tunnel:{pid:$tunnelPid,start:$tunnelStart}}'
}
publish() { sql "UPDATE remote_sessions SET payload=CAST(X'$(hex "$(payload)")' AS TEXT) WHERE token=CAST(X'$(hex "$token")' AS TEXT);" >/dev/null; }
stop_requested() { stopping=true; }
trap stop_requested USR1 TERM INT HUP
row=$(sql "SELECT payload FROM remote_sessions WHERE id=$key;") || exit 2
[[ -z $row ]] || recover "$row"
claimed=$(sql "INSERT OR IGNORE INTO remote_sessions VALUES($key,CAST(X'$(hex "$token")' AS TEXT),CAST(X'$(hex "$(payload)")' AS TEXT)); SELECT changes();") || exit 2
[[ $claimed == 1 ]] || exit 0
cleanup() {
    trap '' USR1 TERM INT HUP
    state=disconnecting; publish || true
    local row attempt
    row=$(payload)
    stop_child "$row" rdp; stop_child "$row" tunnel
    for ((attempt=0;attempt<30;attempt++)); do
        if ! child_alive "$row" rdp && ! child_alive "$row" tunnel; then break; fi
        sleep 0.1
    done
    stop_child "$row" rdp KILL; stop_child "$row" tunnel KILL
    [[ $rdp_pid == 0 ]] || wait "$rdp_pid" 2>/dev/null || true
    [[ $tunnel_pid == 0 ]] || wait "$tunnel_pid" 2>/dev/null || true
    sql "DELETE FROM remote_sessions WHERE token=CAST(X'$(hex "$token")' AS TEXT);" >/dev/null || true
}
trap cleanup EXIT
endpoint=$(jq -r '.endpoint' <<< "$entry") port=$(jq -r '.port' <<< "$entry")
case $(jq -r '.type' <<< "$entry") in
    remote)
        hop=$(jq -r '.hopHost' <<< "$entry") user=$(jq -r '.hopUsername' <<< "$entry") key_path=$(jq -r '.sshKeyPath' <<< "$entry")
        ssh_args=(-N -o ExitOnForwardFailure=yes -o BatchMode=yes -o ConnectTimeout=10)
        [[ $key_path != "~/"* ]] || key_path="$HOME/${key_path:2}"
        [[ -z $key_path ]] || ssh_args+=(-i "$key_path")
        # The kernel/SSH checks the bind; retry collisions without launching RDP prematurely.
        # Match the old provider: use local system DNS when available, then fall back
        # to letting the jump host resolve the original name.
        resolved=''
        if [[ $endpoint != *:* && ! $endpoint =~ ^[0-9.]+$ ]]; then
            read -r resolved _ < <(timeout 3 getent ahosts "$endpoint" 2>/dev/null) || true
            [[ -z $resolved ]] || endpoint=$resolved
        fi
        established=false
        for ((attempt=0;attempt<10;attempt++)); do
            $stopping && exit 0
            local_port=$((RANDOM % 16384 + 49152))
            if "${probe_command[@]}" -z -w 1 127.0.0.1 "$local_port" >/dev/null 2>&1; then continue; fi
            target=$endpoint; [[ $target != *:* || $target == \[*\] ]] || target="[$target]"
            "${ssh_command[@]}" "${ssh_args[@]}" -L "127.0.0.1:$local_port:$target:$port" -- "$user@$hop" >/dev/null 2>&1 & tunnel_pid=$!
            tunnel_start=$(process_identity "$tunnel_pid") || tunnel_start=''
            publish || exit 2
            deadline=$((SECONDS+12))
            while process_alive "$tunnel_pid" "$tunnel_start" "$PROCESS_BOOT_ID" && ((SECONDS<deadline)); do
                $stopping && exit 0
                if "${probe_command[@]}" -z -w 1 127.0.0.1 "$local_port" >/dev/null 2>&1; then established=true; break; fi
                sleep 0.1
            done
            $established && break
            row=$(payload); stop_child "$row" tunnel
            wait "$tunnel_pid" 2>/dev/null || true
            tunnel_pid=0; tunnel_start=''
            break
        done
        $established || fail 'remotes.worker.tunnel'
        endpoint=127.0.0.1; port=$local_port ;;
    vm)
        vm=$(jq -r '.vmName' <<< "$entry")
        vm_id=$(timeout 10 "${virsh_command[@]}" domid -- "$vm" 2>/dev/null) || vm_id='-'
        if [[ ! $vm_id =~ ^[0-9]+$ ]]; then
            timeout 15 "${virsh_command[@]}" start -- "$vm" >/dev/null 2>&1 || fail 'remotes.worker.vmStart'
        fi
        deadline=$((SECONDS+wait_seconds))
        until "${probe_command[@]}" -z -w 1 "$endpoint" "$port" >/dev/null 2>&1; do
            $stopping && exit 0
            ((SECONDS<deadline)) || fail 'remotes.worker.vmTimeout'
            sleep 0.2
        done ;;
esac
$stopping && exit 0
# FreeRDP reads one literal argument per line; validation excludes embedded line breaks.
rdp_arguments() {
    local address=$endpoint title username domain password
    [[ $address != *:* || $address == \[*\] ]] || address="[$address]"
    title=$(jq -r '.displayName' <<< "$entry") username=$(jq -r '.username' <<< "$entry")
    domain=$(jq -r '.domain' <<< "$entry") password=$(jq -r '.password' <<< "$entry")
    [[ -z $title ]] || printf '/t:%s\n' "$title"
    printf '/v:%s:%s\n' "$address" "$port"
    [[ -z $domain || -z $username ]] || username+="@$domain"
    [[ -z $username ]] || printf '/u:%s\n' "$username"
    [[ -z $password ]] || printf '/p:%s\n' "$password"
    jq -r '.arguments[]' <<< "$entry"
}
"${rdp_command[@]}" /args-from:stdin < <(rdp_arguments) >/dev/null 2>&1 & rdp_pid=$!
rdp_start=$(process_identity "$rdp_pid") || rdp_start=''
state=running; publish || exit 2
while process_alive "$rdp_pid" "$rdp_start" "$PROCESS_BOOT_ID"; do
    $stopping && exit 0
    if [[ $tunnel_pid != 0 ]] && ! process_alive "$tunnel_pid" "$tunnel_start" "$PROCESS_BOOT_ID"; then fail 'remotes.worker.disconnected'; fi
    sleep 0.15
done
wait "$rdp_pid"; result=$?
[[ $result == 0 ]] || $stopping || fail 'remotes.worker.rdp'
