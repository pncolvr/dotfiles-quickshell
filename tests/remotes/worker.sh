#!/usr/bin/env bash
# Detached owners and real SQLite/signals; all SSH/RDP/VM/network actions are mocked.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-remotes-worker.XXXXXXXX)
workers=() foreign_pid=''
cleanup() {
    for pid in "${workers[@]}"; do kill -TERM "$pid" 2>/dev/null || true; done
    if [[ -f $fixture/runtime.db ]]; then
        for id in alpha beta gamma; do bash "$repo/src/services/remotes/remote-worker.sh" --disconnect "$fixture/runtime.db" "$id" >/dev/null 2>&1 || true; done
    fi
    [[ -z $foreign_pid ]] || kill -TERM "$foreign_pid" 2>/dev/null || true
    for pid in "${workers[@]}"; do wait "$pid" 2>/dev/null || true; done
    rm -rf -- "$fixture"
}
trap cleanup EXIT
mkdir "$fixture/bin" "$fixture/home"
export HOME="$fixture/home"
export REMOTE_TEST_DIR="$fixture" QS_PICKER_EXECUTABLE="$fixture/bin/alerts"
export PATH="$fixture/bin:$PATH"
cp "$repo/tests/remotes/mock-command.mjs" "$fixture/bin/mock"
chmod +x "$fixture/bin/mock"
for command in ssh rdp virsh probe alerts getent terminal; do ln -s mock "$fixture/bin/$command"; done
node - "$fixture" <<'JS'
const {DatabaseSync}=require('node:sqlite'),fs=require('node:fs'),dir=process.argv[2];const db=new DatabaseSync(dir+'/main.db');db.exec('CREATE TABLE remotes(id TEXT PRIMARY KEY,payload_json TEXT)');
for(const [id,type] of [['alpha','remote'],['beta','vm']]) db.prepare('INSERT INTO remotes VALUES(?,?)').run(id,JSON.stringify({id,name:id,type,enabled:true,endpoint:'test.example',port:3389,displayName:'Test "title"',username:'user;literal',password:'pa$$ \\ "quoted" $(no-execution)',domain:'domain name',hopHost:'jump.example',hopUsername:'test',sshKeyPath:'~/key path/key',vmName:'fixture-vm',arguments:['/drive:Docs,/some path','/cert:ignore']}));db.close()
JS
options=$(jq -nc --arg dir "$fixture/bin" '{rdp:[$dir+"/rdp"],ssh:[$dir+"/ssh"],virsh:[$dir+"/virsh"],probe:[$dir+"/probe"],waitSeconds:1}')
worker="$repo/src/services/remotes/remote-worker.sh"
start() { bash "$worker" --run "$fixture/runtime.db" "$1" "$fixture/main.db" "$fixture" "$options" > "$fixture/log-$1" 2>&1 & workers+=("$!"); }
status() { bash "$worker" --status "$fixture/runtime.db"; }
# The worker publishes its child PID before Node's mock appends its action log.
# Read the current session's PID instead of racing the previous launch's log row.
session_terminal_pid() {
    sqlite3 -readonly "$fixture/runtime.db" "SELECT json_extract(payload,'$.rdp.pid') FROM remote_sessions WHERE id='gamma';"
}
wait_count() {
    for ((attempt=0;attempt<80;attempt++)); do
        if status | jq -e --argjson count "$1" 'length==$count and all(.[];.state=="running")' >/dev/null; then return; fi
        sleep 0.05
    done
    cat "$fixture"/log-* >&2; printf 'Timed out waiting for %s sessions\n' "$1" >&2; exit 1
}
start alpha
wait_count 1
start alpha
wait "${workers[1]}"
[[ $(jq -s '[.[]|select(.program=="ssh")]|length' "$fixture/actions") == 1 ]]
start beta
wait_count 2
jq -se --arg key "$HOME/key path/key" 'any(.program=="ssh" and (.args|index($key))!=null) and any(.program=="ssh" and any(.args[]; contains(":192.0.2.5:3389"))) and any(.program=="virsh" and .args==["start","--","fixture-vm"]) and all(.[]; .args | all(.[]; contains("pa$$")|not))' "$fixture/actions" >/dev/null
node - "$fixture" <<'JS'
const fs=require('node:fs'),assert=require('node:assert/strict'),dir=process.argv[2];for(const file of fs.readdirSync(dir).filter(f=>f.startsWith('rdp-'))){const args=fs.readFileSync(dir+'/'+file,'utf8').trimEnd().split('\n');assert(args.includes('/p:pa$$ \\ "quoted" $(no-execution)'));assert(args.includes('/u:user;literal@domain name'));assert(args.includes('/drive:Docs,/some path'));}assert.equal(fs.readdirSync(dir).filter(f=>f.startsWith('rdp-')).length,2)
JS
bash "$worker" --disconnect "$fixture/runtime.db" alpha
wait_count 1
status | jq -e '.[0].id=="beta"' >/dev/null
printf 'PASS: separate owned connections, duplicate prevention, literal stdin-only credentials and targeted disconnect\n'
# A controller restart reads the worker record; no UI process owns the children.
status | jq -e '.[0].id=="beta" and .[0].state=="running"' >/dev/null
kill -KILL "${workers[2]}"
wait "${workers[2]}" 2>/dev/null || true
wait_count 0
printf 'PASS: status recovers an orphaned RDP child after its owner crashes\n'
# A stale identity must never signal an unrelated process, even when its PID matches.
"$fixture/bin/ssh" foreign >/dev/null 2>&1 & foreign_pid=$!
source "$repo/src/services/processes/process-identity.sh"
foreign_start=$(process_identity "$foreign_pid")
row=$(jq -nc --argjson pid "$foreign_pid" --arg start "$foreign_start-wrong" --arg boot "$PROCESS_BOOT_ID" '{token:"stale",pid:$pid,start:$start,boot:$boot,state:"running",rdp:{pid:$pid,start:$start},tunnel:{pid:0,start:""}}')
row_hex=$(printf '%s' "$row" | od -An -v -tx1 | tr -d ' \n')
sqlite3 "$fixture/runtime.db" "INSERT INTO remote_sessions VALUES('stale','stale',CAST(X'$row_hex' AS TEXT));"
wait_count 0
kill -0 "$foreign_pid"
printf 'PASS: stale PID identity is cleaned without signalling an unrelated process\n'
touch "$fixture/not-ready"
start beta
sleep 0.25
bash "$worker" --disconnect "$fixture/runtime.db" beta
wait_count 0
printf 'PASS: disconnect cancels VM readiness wait\n'
start beta
if wait "${workers[4]}"; then printf 'Expected VM timeout\n' >&2; exit 1; fi
wait_count 0
printf 'PASS: failed VM readiness prevents RDP dispatch and clears session\n'

rm "$fixture/not-ready"
touch "$fixture/ssh-fail"
start alpha
if wait "${workers[5]}"; then printf 'Expected SSH failure\n' >&2; exit 1; fi
wait_count 0
printf 'PASS: SSH failure prevents RDP dispatch and cleans the session\n'

rm "$fixture/ssh-fail"
node - "$fixture" <<'JS'
const {DatabaseSync}=require('node:sqlite'),dir=process.argv[2],db=new DatabaseSync(dir+'/main.db');
db.prepare('INSERT INTO remotes VALUES(?,?)').run('gamma',JSON.stringify({id:'gamma',type:'ssh',name:'SSH terminal',enabled:true,
 endpoint:'server.example',port:2222,username:'test',password:'PRIVATE_TARGET_PASSWORD',sshKeyPath:'~/key path/key',
 hopHost:'',hopPort:22,hopUsername:'',hopPassword:'',hopKeyPath:'',sshArguments:[]}));db.close();
JS
options=$(jq --arg terminal "$fixture/bin/terminal" '. + {terminal:[$terminal,"-e"]}' <<< "$options")
start gamma
wait_count 1
# A terminal process alone does not prove that the helper reached SSH. In
# particular, a command-line quoting failure can leave Ghostty's error window open.
for ((attempt=0;attempt<80;attempt++)); do
    if jq -se 'any(.program=="ssh" and (.args|index("server.example"))!=null and (.args|index("-G"))==null)' "$fixture/actions" >/dev/null; then break; fi
    sleep 0.05
done
jq -se 'any(.program=="ssh" and (.args|index("server.example"))!=null and (.args|index("-G"))==null)' "$fixture/actions" >/dev/null || {
    printf 'SSH terminal did not reach the SSH client\n' >&2; exit 1;
}
start gamma
wait "${workers[7]}"
[[ $(jq -s '[.[]|select(.program=="terminal")]|length' "$fixture/actions") == 1 ]]
status | jq -e '.[0].id=="gamma" and .[0].state=="running"' >/dev/null
terminal_pid=$(session_terminal_pid)
terminal_ssh_pid=$(jq -sr '[.[]|select(.program=="ssh" and (.args|index("server.example"))!=null)][-1].pid' "$fixture/actions")
bash "$worker" --disconnect "$fixture/runtime.db" gamma
wait_count 0
! kill -0 "$terminal_pid" 2>/dev/null
! kill -0 "$terminal_ssh_pid" 2>/dev/null
! rg -q 'PRIVATE_TARGET_PASSWORD' "$fixture/actions" "$fixture"/log-*
printf 'PASS: owned SSH terminal launch, duplicate prevention, restart status and targeted terminal/SSH disconnect\n'
start gamma
wait_count 1
terminal_pid=$(session_terminal_pid)
kill -TERM "$terminal_pid"
wait_count 0
printf 'PASS: closing the SSH terminal clears the managed session\n'
start gamma
wait_count 1
terminal_pid=$(session_terminal_pid)
kill -KILL "${workers[-1]}"
wait "${workers[-1]}" 2>/dev/null || true
wait_count 0
! kill -0 "$terminal_pid" 2>/dev/null
printf 'PASS: orphan recovery closes only the owned SSH terminal\n'

rdp_errors() { jq -s '[.[]|select(.program=="alerts" and (.args|index("remotes.worker.rdp"))!=null)]|length' "$fixture/actions"; }
vm_client() {
    for ((attempt=0;attempt<80;attempt++)); do
        vm_pid=$(sqlite3 -readonly "$fixture/runtime.db" "SELECT json_extract(payload,'$.rdp.pid') FROM remote_sessions WHERE id='beta';")
        if [[ -n $vm_pid && -f $fixture/rdp-$vm_pid ]]; then printf '%s' "$vm_pid"; return; fi
        sleep 0.02
    done
    return 1
}
shutdown_vm() { bash "$worker" --shutdown "$fixture/runtime.db" beta "$fixture/main.db" "$fixture" "$options"; }

errors=$(rdp_errors)
start beta
wait_count 1
kill -USR2 "$(vm_client)"
if wait "${workers[-1]}"; then printf 'Expected unexpected RDP failure\n' >&2; exit 1; fi
wait_count 0
[[ $(rdp_errors) == $((errors+1)) ]]
printf 'PASS: unexpected VM RDP failures still raise an alert\n'

errors=$(rdp_errors)
start beta
wait_count 1
vm_client > "$fixture/shutdown-rdp-pid"
shutdown_vm
wait "${workers[-1]}"
wait_count 0
[[ $(rdp_errors) == "$errors" ]]
rm "$fixture/shutdown-rdp-pid"
printf 'PASS: requested VM shutdown suppresses RDP failure even before virsh returns\n'

touch "$fixture/not-ready"
start beta
for ((attempt=0;attempt<80;attempt++)); do
    if status | jq -e 'length==1 and .[0].id=="beta" and .[0].state=="connecting"' >/dev/null; then break; fi
    sleep 0.02
done
status | jq -e 'length==1 and .[0].state=="connecting"' >/dev/null
shutdown_vm
rm "$fixture/not-ready"
wait_count 1
[[ $(sqlite3 "$fixture/runtime.db" "SELECT json_extract(payload,'$.shutdownRequested') FROM remote_sessions WHERE id='beta';") == 1 ]]
kill -USR2 "$(vm_client)"
wait "${workers[-1]}"
wait_count 0
[[ $(rdp_errors) == "$errors" ]]
printf 'PASS: VM shutdown intent survives the connecting-to-running lifecycle update\n'

start beta
wait_count 1
touch "$fixture/shutdown-fail"
if shutdown_vm; then printf 'Expected failed VM shutdown\n' >&2; exit 1; fi
rm "$fixture/shutdown-fail"
[[ $(sqlite3 "$fixture/runtime.db" "SELECT json_extract(payload,'$.shutdownRequested') IS NULL FROM remote_sessions WHERE id='beta';") == 1 ]]
kill -USR2 "$(vm_client)"
if wait "${workers[-1]}"; then printf 'Expected RDP failure after rejected shutdown\n' >&2; exit 1; fi
wait_count 0
[[ $(rdp_errors) == $((errors+1)) ]]
printf 'PASS: rejected shutdown clears expected-disconnect state and preserves RDP errors\n'

# A new session for the same entry must not inherit an earlier shutdown request.
start beta
wait_count 1
kill -USR2 "$(vm_client)"
if wait "${workers[-1]}"; then printf 'Expected reconnected RDP failure\n' >&2; exit 1; fi
wait_count 0
[[ $(rdp_errors) == $((errors+2)) ]]
shutdown_vm
[[ $(status) == '[]' ]]
printf 'PASS: reconnect starts without shutdown intent and VM shutdown also works without an RDP session\n'
