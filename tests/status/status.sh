#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
executable=${TIMECARD_TEST_EXECUTABLE:-${ZDOTDIR:-$HOME/.config/zsh}/scripts/status/bin/timecard}
test_dir=$(mktemp -d /tmp/quickshell-status-test.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
export TZ=Europe/Lisbon
bash "$project_root/tests/status/timecard-helper.sh"
mkdir -m 700 "$test_dir/runtime"
mkdir "$test_dir/data" "$test_dir/cache" "$test_dir/bin"
cp -a -- "$project_root/src" "$test_dir/src"
export STATUS_TEST_MODE="$test_dir/mode" STATUS_TEST_SOURCE="$test_dir/source"
export TIMETABLE_FILE="$test_dir/events.csv"
printf personal > "$STATUS_TEST_MODE"
printf automatic > "$STATUS_TEST_SOURCE"
cat > "$test_dir/bin/manager" <<'BASH'
#!/usr/bin/env bash
case "$1" in
    --check) cat "$STATUS_TEST_MODE" ;;
    --source) cat "$STATUS_TEST_SOURCE" ;;
    --toggle)
        if [[ $(cat "$STATUS_TEST_MODE") == work ]]; then printf personal > "$STATUS_TEST_MODE";
        else printf work > "$STATUS_TEST_MODE"; fi
        printf manual > "$STATUS_TEST_SOURCE" ;;
    --clear) printf personal > "$STATUS_TEST_MODE"; printf automatic > "$STATUS_TEST_SOURCE" ;;
esac
BASH
chmod +x "$test_dir/bin/manager"
sed -i "s@readonly property string statusManager:.*@readonly property string statusManager: \"$test_dir/bin/manager\"@" "$test_dir/src/config/Config.qml"
sed -i "s@readonly property string statusTimecardExecutable:.*@readonly property string statusTimecardExecutable: \"$executable\"@" "$test_dir/src/config/Config.qml"
today_start=$(date -d 'today 00:00:00' +%s)
yesterday_start=$(date -d 'yesterday 00:00:00' +%s)
printf '%s;work\n%s;personal\n%s;inactive\n%s;active\n%s;work\n%s;personal\n%s;inactive\n' \
    "$yesterday_start" "$((yesterday_start+60))" "$((yesterday_start+120))" \
    "$today_start" "$today_start" "$((today_start+60))" "$((today_start+120))" > "$TIMETABLE_FILE"
before=$(sha256sum "$TIMETABLE_FILE")
for fixture in status-smoke timecard-parser; do
    sed 's@"../../src@"src@g' "$project_root/tests/status/$fixture.qml" > "$test_dir/shell.qml"
    output=$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$test_dir/runtime" \
        XDG_CACHE_HOME="$test_dir/cache" XDG_DATA_HOME="$test_dir/data" \
        timeout 15 qs -p "$test_dir/shell.qml" 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
    printf '%s\n' "$output"
    [[ $output == *'PASS:'* && $output != *'STATUS FAIL:'* \
        && $output != *'Failed to load configuration'* && $output != *'Binding loop detected'* \
        && $output != *'TypeError:'* && $output != *'ReferenceError:'* ]]
done
[[ $(sha256sum "$TIMETABLE_FILE") == "$before" ]]
