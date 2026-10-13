#!/usr/bin/env bash
# Exercise the real userscript CLI, not a Bash reimplementation of its policy.
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
source "$rbw_test_root/mock.sh"
export RBW_TEST_URL=https://login.example.test/ QUTE_URL=https://login.example.test/ QUTERBW_MODE=login
export QUTERBW_HANDLE=0123456789abcdef0123456789abcdef
reset_mock
operation() {
    export QUTERBW_DIRECTORY="$test_dir/operation"
    rm -rf -- "$QUTERBW_DIRECTORY"
    mkdir -m 700 "$QUTERBW_DIRECTORY"
    export QUTE_FIFO="$QUTERBW_DIRECTORY/commands"
    mkfifo -m 600 "$QUTE_FIFO"
    exec {command_fd}<>"$QUTE_FIFO"
}
run_failure() {
    local expected=$1 status=0
    operation
    QUTERBW_BROWSER_PID=$$ timeout 8 "$scripts_root/qute-rbw" > "$test_dir/out" 2> "$test_dir/error" || status=$?
    exec {command_fd}>&-
    [[ $status == "$expected" ]]; assert_empty "$test_dir/out"; assert_empty "$test_dir/error"
}
run_success() {
    operation
    # The connecting process execs socat so its Linux peer PID is known before
    # starting the userscript. No Python socket harness is needed.
    bash -c '
        for ((attempt=0;attempt<200;attempt++)); do
            [[ -S $QUTERBW_DIRECTORY/reply ]] && exec socat "UNIX-CONNECT:$QUTERBW_DIRECTORY/reply" STDIO
            sleep 0.025
        done
        exit 1
    ' < <(printf 1) > "$test_dir/wire" 2> "$test_dir/client-error" & client_pid=$!
    QUTERBW_BROWSER_PID=$client_pid timeout 10 "$scripts_root/qute-rbw" > "$test_dir/out" 2> "$test_dir/error" & server_pid=$!
    IFS= read -r -t 8 command <&"$command_fd"
    [[ $command == "rbw-fill-once $QUTERBW_HANDLE" ]]
    wait "$server_pid"; server_pid=''
    wait_client 0
    exec {command_fd}>&-
    dd if="$test_dir/wire" bs=1 skip=4 status=none > "$test_dir/payload"
    jq -e '.version == 1 and .mode == env.QUTERBW_MODE and
        (if .mode == "login" then .username == env.RBW_TEST_USER and .password == env.RBW_TEST_SECRET and keys == ["mode","password","username","version"]
        elif .mode == "totp" then .totp == "123456" and keys == ["mode","totp","version"]
        elif .mode == "password" then .password == env.RBW_TEST_SECRET and keys == ["mode","password","version"]
        else .username == env.RBW_TEST_USER and keys == ["mode","username","version"] end)' "$test_dir/payload" >/dev/null
    assert_empty "$test_dir/out"; assert_empty "$test_dir/error"; assert_empty "$test_dir/client-error"
    [[ ! -e $QUTERBW_DIRECTORY/reply ]]
}
for mode in login password username totp; do export QUTERBW_MODE=$mode; run_success; done
export QUTERBW_MODE=login
printf 'PASS: actual userscript transfer, exact values, requested fields, FIFO handle and peer PID\n'

# Metadata deduplication: two identical labels retain distinct UUIDs, while the
# duplicate and non-login records are dropped. The mock validates secret absence.
jq '.[0] as $entry | [$entry, ($entry + {id:"22345678-1234-4234-8234-123456789abc"}), $entry, ($entry + {type:"Card"})]' "$test_dir/entries.json" > "$test_dir/new.json"
mv "$test_dir/new.json" "$test_dir/entries.json"
run_success
reset_mock
printf 'cancel\n' > "$test_dir/control"; run_failure 3
printf 'picker-fail\n' > "$test_dir/control"; run_failure 8
printf 'fail\n' > "$test_dir/control"; run_failure 1
reset_mock
for policy in 1 null false; do
    jq -nc --argjson policy "$policy" '{entries:[{id:env.RBW_TEST_ID,master_password_reprompt:$policy}]}' > "$XDG_CACHE_HOME/rbw/default:user@example.test.json"
    run_failure 5
done
reset_mock
rm "$XDG_CACHE_HOME/rbw/default:user@example.test.json"
ln -s "$test_dir/entry.json" "$XDG_CACHE_HOME/rbw/default:user@example.test.json"
run_failure 1
rm "$XDG_CACHE_HOME/rbw/default:user@example.test.json"
reset_mock

uri_case() {
    local uri=$1 kind=$2 target=$3 expected=$4
    reset_mock
    export QUTE_URL=$target
    # Keep suggestion filtering permissive to test selected-entry authorization.
    jq -nc '[{id:env.RBW_TEST_ID,type:"Login",name:"Fixture",uris:[env.QUTE_URL]}]' > "$test_dir/entries.json"
    jq --arg uri "$uri" --argjson kind "$kind" '.data.uris=[{uri:$uri,match_type:$kind}]' "$test_dir/entry.json" > "$test_dir/new.json"
    mv "$test_dir/new.json" "$test_dir/entry.json"
    if [[ $expected == yes ]]; then run_success; else run_failure 4; fi
}
uri_case https://example.test 0 https://login.example.test/ yes
uri_case https://example.test 1 https://login.example.test/ no
uri_case https://login.example.test/ 3 https://login.example.test/ yes
uri_case https://login.example.test/path 3 'https://login.example.test/path?different' no
uri_case https://login.example.test/ 2 https://login.example.test/path yes
uri_case https://login.example.test 2 https://login.example.test.evil.test/ no
uri_case https://login.example.test 5 https://login.example.test/ no
uri_case '.*' 4 https://login.example.test/ no
uri_case https://co.uk 0 https://victim.co.uk/ no
uri_case https://com 0 https://victim.com/ no
uri_case http://login.example.test 0 https://login.example.test/ no
uri_case https://login.example.test:444 1 https://login.example.test/ no
uri_case https://login.example.test:443 1 https://login.example.test/ yes
uri_case 127.0.0.1 0 https://127.0.0.1/ yes
uri_case 127.0.0.1 0 https://x.127.0.0.1/ no
uri_case 'https://[::1]' 1 'https://[::1]/' yes
uri_case https://bücher.test 1 https://xn--bcher-kva.test/ yes
reset_mock
export QUTE_URL=$RBW_TEST_URL
printf '[]\n' > "$test_dir/entries.json"; run_failure 2
reset_mock
jq '.data.password="invalid\npassword"' "$test_dir/entry.json" > "$test_dir/new.json"
mv "$test_dir/new.json" "$test_dir/entry.json"; run_failure 1
! rg -Fq "$RBW_TEST_SECRET" "$test_dir/calls"
printf 'PASS: URI rules, duplicate metadata, cancellation, error privacy and cache policy fail closed\n'
