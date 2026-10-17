#!/usr/bin/env bash
# Synthetic SQLite records, a mock SSH client and an isolated pseudo-terminal.
# No real hosts, keys, desktop terminals or credentials are used.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d "/tmp/qs-ssh 'quoted % path.XXXXXX")
trap 'result=$?; if ((result)) && [[ -f $fixture/output ]]; then cat "$fixture/output" >&2; fi; rm -rf -- "$fixture"' EXIT
mkdir "$fixture/home"
export HOME="$fixture/home" SSH_TEST_DIR="$fixture"
node - "$fixture" <<'JS'
const {DatabaseSync}=require('node:sqlite'),dir=process.argv[2],db=new DatabaseSync(dir+'/main.db');
db.exec('CREATE TABLE remotes(id TEXT PRIMARY KEY,payload_json TEXT)');
const entry={id:'fixture',name:'Public test',type:'ssh',enabled:true,endpoint:'server.example',port:2222,
 username:'target-user',password:'PUBLIC_TARGET_TEST_PASSWORD',sshKeyPath:'~/keys/target key',
 hopHost:'jump.example',hopPort:2200,hopUsername:'jump-user',hopPassword:'PUBLIC_JUMP_TEST_PASSWORD',
 hopKeyPath:'/keys/jump key',sshArguments:['-o','ServerAliveInterval=30']};
for(const [id,patch]of [['fixture',{}],['direct',{hopHost:'',username:'',sshKeyPath:''}],['manual',{password:'',hopHost:''}]])
 db.prepare('INSERT INTO remotes VALUES(?,?)').run(id,JSON.stringify({...entry,...patch,id}));
db.close();
JS
cat > "$fixture/mock-ssh" <<'JS'
#!/usr/bin/env node
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
const args=process.argv.slice(2),dir=process.env.SSH_TEST_DIR,role=process.env.QS_REMOTE_SSH_ROLE;
if(args[0]==='--ask-child') {
 const result=spawnSync(process.env.SSH_ASKPASS,[process.env.QS_REMOTE_SSH_USER+'@'+process.env.QS_REMOTE_SSH_HOST+"'s password: "],{encoding:'utf8'});
 fs.writeSync(1,result.stdout);process.exit(result.status??1);
}
if(args.includes('-G')) {
 console.log('hostname '+(process.env.SSH_TEST_RESOLVED_HOST??args.at(-1)));console.log('user '+(args.includes('-l')?args[args.indexOf('-l')+1]:'config-user'));
 process.exit(0);
}
assert.equal(process.env.SSH_ASKPASS_REQUIRE,'force');
assert(!args.some(arg=>arg.includes('TEST_PASSWORD')));
assert(args.includes('ControlPath=none') && args.includes('ForkAfterAuthentication=no'));
assert(!args.includes('StrictHostKeyChecking=no'));
function ask(prompt,hint) {
 const result=spawnSync(process.env.SSH_ASKPASS,[prompt],{encoding:'utf8',env:{...process.env,SSH_ASKPASS_PROMPT:hint??''}});
 assert.equal(result.status,0); return result.stdout.trimEnd();
}
if(process.env.SSH_TEST_MODE==='guard') {
 assert.equal(ask("jump-user@implicit-jump.example's password: "),'manual-jump-password');
 const child=spawnSync(process.execPath,[process.argv[1],'--ask-child'],{encoding:'utf8'});
 assert.equal(child.status,0);assert.equal(child.stdout.trimEnd(),'manual-child-password');
 assert.equal(ask("config-user@server.example's password: "),'PUBLIC_TARGET_TEST_PASSWORD');
 fs.appendFileSync(dir+'/results','unrelated prompt guard\n');
} else if(process.env.SSH_TEST_MODE==='manual') {
 assert.equal(ask("target-user@server.example's password: "),'manual-password');
 assert.equal(ask('Enter passphrase for key: '),'key-passphrase');
 assert.equal(ask('Continue connecting (yes/no)? ','confirm'),'yes');
 assert.equal(ask('Touch your security key','none'),'');
 fs.appendFileSync(dir+'/results','manual prompts\n');
} else if(role==='jump') {
 assert.equal(args[args.indexOf('-p')+1],'2200');
 assert.equal(args[args.indexOf('-l')+1],'jump-user');
 assert.equal(args[args.indexOf('-i')+1],'/keys/jump key');
 assert.equal(args[args.indexOf('-W')+1],'[server.example]:2222');
 assert.equal(ask("jump-user@jump.example's password: "),'PUBLIC_JUMP_TEST_PASSWORD');
 fs.appendFileSync(dir+'/results','jump credentials\n');
} else {
 assert.equal(args[args.indexOf('-p')+1],'2222');
 assert.equal(ask(process.env.QS_REMOTE_SSH_USER+'@'+process.env.QS_REMOTE_SSH_HOST+"'s password: "),'PUBLIC_TARGET_TEST_PASSWORD');
 const proxy=args.find(arg=>arg.startsWith('ProxyCommand='));
 if(proxy) {
  assert.equal(args[args.indexOf('-i')+1],process.env.HOME+'/keys/target key');
  const command=proxy.slice('ProxyCommand='.length).replace(/%%|%h|%p/g,value=>({'%%':'%','%h':'server.example','%p':'2222'})[value]);
  const result=spawnSync('/bin/sh',['-c',command],{encoding:'utf8'});
  assert.equal(result.status,0,result.stderr);
 } else assert(!args.includes('-l') && !args.includes('-i'));
 fs.appendFileSync(dir+'/results',proxy?'destination credentials\n':'SSH config defaults\n');
}
JS
chmod +x "$fixture/mock-ssh"
options=$(jq -nc --arg ssh "$fixture/mock-ssh" '{ssh:[$ssh]}')
helper=$repo/src/services/remotes/ssh-session.sh
bash "$helper" --connect "$fixture/main.db" fixture "$options" > "$fixture/output" 2>&1
bash "$helper" --connect "$fixture/main.db" direct "$options" >> "$fixture/output" 2>&1
SSH_TEST_RESOLVED_HOST=resolved.example bash "$helper" --connect "$fixture/main.db" direct "$options" >> "$fixture/output" 2>&1
# script provides a controlling terminal only for the synthetic prompt callbacks.
printf -v command '%q ' bash "$helper" --connect "$fixture/main.db" manual "$options"
printf 'manual-password\nkey-passphrase\nyes\n' | SSH_TEST_MODE=manual timeout -k 2 8 \
    script -q -e -E never -c "$command" /dev/null >> "$fixture/output" 2>&1
printf -v command '%q ' bash "$helper" --connect "$fixture/main.db" direct "$options"
{ printf 'manual-jump-password\nmanual-child-password\n'; sleep 1; } | SSH_TEST_MODE=guard timeout -k 2 8 \
    script -q -e -E never -c "$command" /dev/null >> "$fixture/output" 2>&1
[[ $(cat "$fixture/results") == $'jump credentials\ndestination credentials\nSSH config defaults\nSSH config defaults\nmanual prompts\nunrelated prompt guard' ]] || { cat "$fixture/output"; exit 1; }
! rg -q 'PUBLIC_TARGET_TEST_PASSWORD|PUBLIC_JUMP_TEST_PASSWORD|manual-password|manual-jump-password|manual-child-password|key-passphrase' "$fixture/output"
printf 'PASS: separate SSH/jump credentials, literal paths and arguments, SSH config defaults, terminal password/passphrase/host-key prompts and no secret output\n'
