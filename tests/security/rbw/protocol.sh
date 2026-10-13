#!/usr/bin/env bash
# Byte-preservation and failure cases with synthetic replies, no actual vault.
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
helper="$project_root/src/services/launcher/secret_prompt.sh"
pinentry="$project_root/src/services/launcher/pinentry-rbw"
export QS_PICKER_TIMEOUT=4 QS_PICKER_EXECUTABLE="$test_dir/bin/qs"
cat > "$QS_PICKER_EXECUTABLE" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$RBW_TEST_ROOT/arguments"
case ${6:-} in
    open)
        jq -e '.kind == "secret" and .items == [] and .ownerPid > 0 and (.ownerStart|length > 0)' "$7/request.json" >/dev/null
        case ${RBW_TEST_RESPONSE_MODE:-normal} in
            fragmented)
                { printf '%s' "${RBW_TEST_REPLY:0:8}"; sleep 1.2; printf '%s\n' "${RBW_TEST_REPLY:8}"; } > "$7/reply" & ;;
            silent) ;;
            *) printf '%s\n' "$RBW_TEST_REPLY" > "$7/reply" & ;;
        esac ;;
    alive|cancel) ;;
    *) exit 1 ;;
esac
MOCK
chmod +x "$QS_PICKER_EXECUTABLE"
export RBW_TEST_ROOT="$test_dir"
export RBW_TEST_REPLY='{"status":"accepted","secret":"  PROTOCOL_MARKER_%_é_\"\\\r\n\n\u0000"}'
printf '%s' "$RBW_TEST_REPLY" | jq -j '.secret' > "$test_dir/expected"
for mode in normal fragmented; do
    RBW_TEST_RESPONSE_MODE=$mode bash "$helper" > "$test_dir/result" 2> "$test_dir/error"
    cmp "$test_dir/expected" "$test_dir/result"; assert_empty "$test_dir/error"
done
printf '%s' "$RBW_TEST_REPLY" | jq -j '"D " + (.secret | gsub("%";"%25")|gsub("\r";"%0D")|gsub("\n";"%0A")|gsub("\u0000";"%00")) + "\nOK\n"' > "$test_dir/expected"
printf 'SETPROMPT Master%%20Password\nSETDESC Check%%2520literal\nGETPIN\nBYE\n' | bash "$pinentry" > "$test_dir/result" 2> "$test_dir/error"
tail -n 3 "$test_dir/result" | head -n 2 | cmp "$test_dir/expected" -
assert_empty "$test_dir/error"
for reply in '{"status":"cancelled"}' 'not-json' '[]' '{"status":"accepted","secret":5}' \
    '{"status":"accepted","secret":"x","extra":true}' '{"status":"accepted","secret":"x"} {}'; do
    export RBW_TEST_REPLY=$reply
    status=0; bash "$helper" > "$test_dir/result" 2> "$test_dir/error" || status=$?
    if [[ $reply == '{"status":"cancelled"}' ]]; then expected=1; else expected=2; fi
    [[ $status == "$expected" ]]; assert_empty "$test_dir/result"; assert_empty "$test_dir/error"
done
export RBW_TEST_REPLY='{"status":"accepted","secret":"x"}'
status=0
QS_PICKER_TIMEOUT=1 RBW_TEST_RESPONSE_MODE=silent bash "$helper" > "$test_dir/result" 2> "$test_dir/error" || status=$?
[[ $status == 2 ]]; assert_empty "$test_dir/result"; assert_empty "$test_dir/error"
RBW_TEST_REPLY=$(jq -nc '{status:"accepted",secret:([range(70000)]|map("x")|join(""))}')
export RBW_TEST_REPLY
status=0; bash "$helper" > "$test_dir/result" 2> "$test_dir/error" || status=$?
[[ $status == 2 ]]; assert_empty "$test_dir/result"; assert_empty "$test_dir/error"
export RBW_TEST_REPLY='{"status":"cancelled"}'
printf 'GETPIN\nRESET\nBOGUS\nBYE\n' | bash "$pinentry" > "$test_dir/result" 2> "$test_dir/error"
rg -q '^ERR 83886179 Cancelled$' "$test_dir/result"
rg -q '^ERR 83886183 Unsupported request$' "$test_dir/result"
! rg -q '^D ' "$test_dir/result"
printf 'SETPROMPT %%00\n' | bash "$pinentry" > "$test_dir/result" 2> "$test_dir/error" && exit 1
rg -q '^ERR 83886183 Invalid request$' "$test_dir/result"
assert_empty "$test_dir/error"
[[ -z $(find "$XDG_RUNTIME_DIR/quickshell-picker" -name 'request.*' -print -quit) ]]
! rg -q PROTOCOL_MARKER "$test_dir/arguments"
printf 'PASS: Bash secret byte preservation, fragmented replies, Assuan escaping, malformed/oversized replies and timeouts\n'
