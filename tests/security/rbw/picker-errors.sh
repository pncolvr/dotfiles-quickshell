#!/usr/bin/env bash
# Synthetic startup/response failures must not be reported as user cancellation.
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
export QS_PICKER_EXECUTABLE="$test_dir/bin/qs" QS_PICKER_TIMEOUT=2
export RBW_TEST_ROOT="$test_dir"
cat > "$QS_PICKER_EXECUTABLE" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case ${6:-} in
    open)
        case $(<"$RBW_TEST_ROOT/control") in
            ipc-failure) exit 1 ;;
            malformed) printf 'not-json\n' > "$7/reply" ;;
            cancelled) printf '{"status":"cancelled","items":[],"exitCode":1}\n' > "$7/reply" ;;
        esac ;;
    alive|cancel) ;;
    *) exit 1 ;;
esac
MOCK
chmod +x "$QS_PICKER_EXECUTABLE"
printf '%s\n' '{"items":[{"title":"Synthetic entry","result":"dummy"}]}' > "$test_dir/options.json"
for failure in ipc-failure malformed cancelled; do
    printf '%s\n' "$failure" > "$test_dir/control"
    status=0
    bash "$project_root/src/services/launcher/launcher.sh" --json "$test_dir/options.json" > "$test_dir/result" 2> "$test_dir/error" || status=$?
    if [[ $failure == cancelled ]]; then expected=1; else expected=2; fi
    [[ $status == "$expected" ]] || { printf 'FAIL: %s returned %s; expected %s\n' "$failure" "$status" "$expected" >&2; exit 1; }
    assert_empty "$test_dir/result"
done
[[ -z $(find "$XDG_RUNTIME_DIR/quickshell-picker" -name 'request.*' -print -quit) ]]
printf 'PASS: startup and malformed-reply errors are distinct from explicit cancellation\n'
