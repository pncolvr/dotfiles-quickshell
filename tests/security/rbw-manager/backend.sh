#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
manager=$project_root/src/services/vault/rbw-manager.sh
call() { printf '%s\n' "$1" | bash "$manager" > "$test_dir/reply"; }
call '{"action":"list"}'
jq -e '.ok and (.entries|length)==2 and ([.entries[]|has("data") or has("notes")]|any|not)' "$test_dir/reply" >/dev/null
call "{\"action\":\"detail\",\"id\":\"$item_id\"}"
jq -e '.ok and .entry.data.password == "SYNTHETIC_SECRET_DO_NOT_LOG" and .entry.data.totp == "SYNTHETIC_SEED" and (.entry|has("history")|not)' "$test_dir/reply" >/dev/null
baseline=$(jq -r .baseline "$test_dir/reply")
call "{\"action\":\"totp\",\"id\":\"$item_id\"}"
jq -e '.ok and .token=="123456" and keys==["ok","token"]' "$test_dir/reply" >/dev/null
jq -se --arg id "$item_id" 'any(.[]; . == ["code",$id]) and (any(.[]; any(.[]; contains("SYNTHETIC_SEED") or contains("123456")))|not)' "$test_dir/calls" >/dev/null
for token in 01234567 234BC; do
    printf '%s\n' "$token" > "$test_dir/token"
    call "{\"action\":\"totp\",\"id\":\"$item_id\"}"
    jq -e --arg expected "$token" '.ok and .token==$expected' "$test_dir/reply" >/dev/null
done
printf 'SYNTHETIC_SEED\n' > "$test_dir/token"
call "{\"action\":\"totp\",\"id\":\"$item_id\"}"
jq -e '.ok==false and .error=="Invalid TOTP token response."' "$test_dir/reply" >/dev/null
rm "$test_dir/token"
touch "$test_dir/protect-on-code"
call "{\"action\":\"totp\",\"id\":\"$item_id\"}"
jq -e '.ok==false and (has("token")|not)' "$test_dir/reply" >/dev/null
rm "$test_dir/protect-on-code"
jq '.entries[0].master_password_reprompt=0' "$XDG_CACHE_HOME/rbw/default:user@example.test.json" > "$test_dir/cache-next"
mv "$test_dir/cache-next" "$XDG_CACHE_HOME/rbw/default:user@example.test.json"
request=$(jq -nc --arg id "$item_id" --arg baseline "$baseline" '{action:"edit",id:$id,baseline:$baseline,password:"new password",notes:"new notes"}')
call "$request"
jq -e '.ok and .saved' "$test_dir/reply" >/dev/null
printf 'new password\n\nnew notes' > "$test_dir/expected"
cmp "$test_dir/expected" "$test_dir/write-input"
jq -se --arg id "$item_id" 'any(.[]; . == ["edit",$id]) and (any(.[]; any(.[]; contains("new password") or contains("new notes")))|not)' "$test_dir/calls" >/dev/null
rm "$test_dir/write-input"
call "$(printf '%s' "$request" | jq -c '.notes="#cannot preserve"')"
jq -e '.ok==false' "$test_dir/reply" >/dev/null
[[ ! -f $test_dir/write-input ]]
call "$(printf '%s' "$request" | jq -c '.baseline="stale"')"
jq -e '.ok==false and (.error|contains("changed"))' "$test_dir/reply" >/dev/null
[[ ! -f $test_dir/write-input ]]
call '{"action":"add","name":"--title","username":"--user","password":"new password","notes":"new notes","folder":"New folder","uris":["https://example.test","https://other.test"]}'
jq -e '.ok and .saved' "$test_dir/reply" >/dev/null
cmp "$test_dir/expected" "$test_dir/write-input"
jq -se 'any(.[]; . == ["add","--folder","New folder","--uri","https://example.test","--uri","https://other.test","--","--title","--user"])' "$test_dir/calls" >/dev/null
call '{"action":"generate","length":24}'
jq -e '.password == "SYNTHETIC_GENERATED_PASSWORD"' "$test_dir/reply" >/dev/null
jq -se 'any(.[]; . == ["generate","24"])' "$test_dir/calls" >/dev/null
# Policies are checked before and after detail fetch; unknown/protected entries fail closed.
touch "$test_dir/protect-on-get"
call "{\"action\":\"detail\",\"id\":\"$item_id\"}"
jq -e '.ok==false' "$test_dir/reply" >/dev/null
! rg -q 'SYNTHETIC_SECRET' "$test_dir/reply"
rm "$test_dir/protect-on-get"
jq '.entries[0].master_password_reprompt=0' "$XDG_CACHE_HOME/rbw/default:user@example.test.json" > "$test_dir/cache-next"
mv "$test_dir/cache-next" "$XDG_CACHE_HOME/rbw/default:user@example.test.json"
jq '.data=null | .history=[]' "$test_dir/entry.json" > "$test_dir/entry-next"
mv "$test_dir/entry-next" "$test_dir/entry.json"
code_calls=$(jq -s '[.[]|select(.[0]=="code")]|length' "$test_dir/calls")
call "{\"action\":\"totp\",\"id\":\"$item_id\"}"
jq -e '.ok==false and .error=="This entry has no TOTP secret."' "$test_dir/reply" >/dev/null
[[ $(jq -s '[.[]|select(.[0]=="code")]|length' "$test_dir/calls") == "$code_calls" ]]
call "{\"action\":\"detail\",\"id\":\"$item_id\"}"
baseline=$(jq -r .baseline "$test_dir/reply")
call "$(jq -nc --arg id "$item_id" --arg baseline "$baseline" '{action:"edit",id:$id,baseline:$baseline,password:"",notes:"updated note"}')"
jq -e '.ok' "$test_dir/reply" >/dev/null
[[ $(<"$test_dir/write-input") == 'updated note' ]]
call "$(jq -nc --arg id "$item_id" --arg baseline "$baseline" '{action:"remove",id:$id,baseline:$baseline}')"
jq -e '.ok and .saved' "$test_dir/reply" >/dev/null
jq -se --arg id "$item_id" 'any(.[]; . == ["remove",$id])' "$test_dir/calls" >/dev/null
touch "$test_dir/fail"
call '{"action":"list"}'
jq -e '.ok==false' "$test_dir/reply" >/dev/null
! rg -q 'SYNTHETIC_SECRET' "$test_dir/reply"
# Sensitive clipboard selections are drained before the capture helper creates files.
QS_CLIPBOARD_DIRECTORY="$test_dir/clipboard" CLIPBOARD_STATE=sensitive bash "$project_root/src/services/clipboard/clipboard.sh" capture text/plain <<< 'SYNTHETIC_COPY_PASSWORD' > "$test_dir/capture-output"
[[ ! -d $test_dir/clipboard && ! -s $test_dir/capture-output ]]
printf 'PASS: manager metadata, TOTP secrets/tokens, policy gates, login creation, stdin edits, generation, deletion and sanitized failures\n'
