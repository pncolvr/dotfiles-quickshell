#!/usr/bin/env bash
# Reproduce an unavailable enum value without mutating/restarting the live shell.
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
copy_shell
sed -i '/enum Mode {/s/, Secret//' "$test_dir/src/services/launcher/PickerService.qml"
rg -Fq 'enum Mode {' "$test_dir/src/services/launcher/PickerService.qml"
if rg -q 'enum Mode.*\bSecret\b' "$test_dir/src/services/launcher/PickerService.qml"; then
    printf 'FAIL: enum fixture did not remove Secret\n' >&2
    exit 1
fi
sed 's@"../../../src@"src@g' "$rbw_test_root/launcher.qml" > "$test_dir/shell.qml"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QS_PICKER_CONFIG="$test_dir" QS_PICKER_TIMEOUT=3
qs -p "$test_dir" > "$test_dir/log" 2>&1 & shell_pid=$!
wait_state '.visible == false'
status=0
start=$SECONDS
bash "$test_dir/src/services/launcher/launcher.sh" --secret > "$test_dir/result" 2> "$test_dir/error" || status=$?
[[ $status == 2 && $((SECONDS - start)) -lt 3 ]]
assert_empty "$test_dir/result"; assert_empty "$test_dir/error"
snapshot | jq -e '.visible == false and .directory == ""' >/dev/null
rg -q 'Secret picker unavailable; restart Quickshell.' "$test_dir/log"
! rg -q 'Cannot assign.*undefined.*int' "$test_dir/log"
[[ -z $(find "$XDG_RUNTIME_DIR/quickshell-picker" -name 'request.*' -print -quit) ]]
printf 'PASS: an unavailable secret enum fails immediately instead of leaving an invisible prompt\n'
