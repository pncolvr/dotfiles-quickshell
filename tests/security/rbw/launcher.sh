#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
copy_shell
sed 's@"../../../src@"src@g' "$rbw_test_root/launcher.qml" > "$test_dir/shell.qml"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QS_PICKER_CONFIG="$test_dir" QS_PICKER_TIMEOUT=3
export RBW_TEST_SECRET="  RBW_PINENTRY_MARKER_%_é_'  "
qs -p "$test_dir" > "$test_dir/log" 2>&1 & shell_pid=$!
wait_state '.visible == false'
picker="$project_root/src/services/launcher/launcher.sh"
pinentry="$project_root/src/services/launcher/pinentry-rbw"
open_secret() {
    bash "$picker" --secret --prompt 'Master Password' > "$test_dir/result" 2> "$test_dir/error" & client_pid=$!
    wait_state '.visible'
}
open_secret
snapshot | jq -e '.secret and .privateWindow and .masked and .query == "" and .preferences == "" and .textLength == 0' >/dev/null
request_dir=$(snapshot | jq -r '.directory')
! rg -Fq "$RBW_TEST_SECRET" "$request_dir/request.json"
ipc typeSecret
snapshot | jq -e '.masked and .valueIntact' >/dev/null
ipc toggleEye
snapshot | jq -e '.revealed and (.masked|not) and .valueIntact' >/dev/null
ipc toggleEye
snapshot | jq -e '.masked and (.revealed|not) and .valueIntact' >/dev/null
ipc toggleEye
ipc submit
wait_client 0
printf '%s' "$RBW_TEST_SECRET" > "$test_dir/expected"
cmp "$test_dir/expected" "$test_dir/result"
assert_empty "$test_dir/error"
snapshot | jq -e '.textLength == 0 and .masked and (.revealed|not)' >/dev/null

open_secret
snapshot | jq -e '.masked and .textLength == 0' >/dev/null
ipc typeSecret; ipc toggleEye
snapshot | jq -e '.revealed and .valueIntact' >/dev/null
ipc cancel
wait_client 1
assert_empty "$test_dir/result"; assert_empty "$test_dir/error"
snapshot | jq -e '.masked and .textLength == 0 and (.revealed|not)' >/dev/null

mkfifo "$test_dir/pinentry-input"
bash "$pinentry" --timeout 0 --no-global-grab < "$test_dir/pinentry-input" > "$test_dir/result" 2> "$test_dir/error" & client_pid=$!
exec {input_fd}>"$test_dir/pinentry-input"
printf 'SETTITLE rbw\nSETPROMPT Master%%20Password\nSETDESC Unlock%%20vault\nSETERROR Try%%20again\nOPTION grab\nGETPIN\n' >&"$input_fd"
wait_state '.visible and .masked and .textLength == 0'
ipc submit
exec {input_fd}>&-
wait_client 0
encoded=${RBW_TEST_SECRET//%/%25}
printf 'D %s\nOK\n' "$encoded" > "$test_dir/expected"
tail -n 2 "$test_dir/result" | cmp "$test_dir/expected" -
assert_empty "$test_dir/error"

printf '%s\n' '{"prompt":"Fill login on example.test","private":true,"showPrompt":true,"allowTyped":false,"items":[{"title":"Same | name","result":"first"},{"title":"Same | name","result":"second"}]}' > "$test_dir/options.json"
bash "$picker" --json "$test_dir/options.json" > "$test_dir/result" 2> "$test_dir/error" & client_pid=$!
wait_state '.visible and .privateWindow and .placeholder == "Fill login on example.test" and (.prompt | contains("example.test"))'
ipc submit; wait_client 0
[[ $(<"$test_dir/result") == first ]]; assert_empty "$test_dir/error"
for signal in TERM KILL; do
    open_secret
    kill -s "$signal" "$client_pid"
    wait "$client_pid" 2>/dev/null || true; client_pid=''
    wait_state '.visible == false'
done
open_secret
wait_client 2
assert_empty "$test_dir/result"; assert_empty "$test_dir/error"
wait_state '.visible == false'
[[ -z $(find "$XDG_RUNTIME_DIR/quickshell-picker" -name 'request.*' -print -quit) ]]
! rg -Fq "$RBW_TEST_SECRET" "$test_dir/log"
printf 'PASS: Bash secret input, eye/reset, pinentry, cancellation, cleanup, metadata and log privacy\n'
