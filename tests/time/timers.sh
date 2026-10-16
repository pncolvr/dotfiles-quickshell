#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-timers-test.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -m 700 "$test_dir/runtime"
mkdir -p "$test_dir/bin" "$test_dir/data" "$test_dir/cache"
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$test_dir" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$test_dir/src/config/Config.qml"
# Make the real asynchronous preparation gap deterministic in every process.
mv "$test_dir/src/services/storage/prepare-database.sh" "$test_dir/src/services/storage/prepare-database-real.sh"
cat > "$test_dir/src/services/storage/prepare-database.sh" <<'PREPARE'
#!/usr/bin/env bash
sleep 0.2
exec bash "${BASH_SOURCE[0]%/*}/prepare-database-real.sh" "$@"
PREPARE
cat > "$test_dir/bin/canberra-gtk-play" <<'BASH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TIMERS_TEST_SOUND_LOG"
BASH
chmod +x "$test_dir/bin/canberra-gtk-play"
sed 's@"../../src@"src@g' "$project_root/tests/time/timers-smoke.qml" > "$test_dir/shell.qml"
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
export TIMERS_TEST_SOUND_LOG="$test_dir/sounds.log"
output=$(PATH="$test_dir/bin:$PATH" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" \
    timeout -k 2 15 qs -p "$test_dir/shell.qml" 2>&1) || {
    printf '%s\n' "$output" >&2
    exit 1
}
printf '%s\n' "$output"
[[ $output == *'PASS: countdowns, elapsed timers, bar priority and panel controls'* \
    && $output != *'TIMERS FAIL:'* && $output != *'Failed to load configuration'* \
    && $output != *'Binding loop detected'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* ]]
[[ $(wc -l < "$TIMERS_TEST_SOUND_LOG") -eq 4 ]]
[[ $(sort -u "$TIMERS_TEST_SOUND_LOG") == '-i alarm-clock-elapsed' ]]
printf '%s\n' 'PASS: exactly one mocked alarm per countdown run, including reuse'

sed 's@"../../src@"src@g' "$project_root/tests/time/timers-restore-smoke.qml" > "$test_dir/shell.qml"
for phase in seed late restore again empty; do
    output=$(PATH="$test_dir/bin:$PATH" TIMERS_TEST_PHASE="$phase" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
        XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" \
        timeout -k 2 10 qs -p "$test_dir/shell.qml" 2>&1) || {
        printf '%s\n' "$output" >&2
        exit 1
    }
    printf '%s\n' "$output"
    [[ $output == *"PASS: timer persistence $phase"* && $output != *'TIMERS FAIL:'* \
        && $output != *'Failed to load configuration'* && $output != *'Binding loop detected'* \
        && $output != *'TypeError:'* && $output != *'ReferenceError:'* ]]
    snapshot=$(sqlite3 -readonly "$test_dir/data/quickshell.db" "SELECT value_json FROM preferences WHERE key='timers.state';")
    [[ -n $snapshot ]] || { printf 'TIMERS FAIL: no persisted snapshot after %s\n' "$phase" >&2; exit 1; }
    case $phase in
        seed|late) countdown_count=5; timer_count=2 ;;
        restore) countdown_count=4; timer_count=2 ;;
        again|empty) countdown_count=0; timer_count=0 ;;
    esac
    jq -e --argjson countdowns "$countdown_count" --argjson timers "$timer_count" \
        '(.countdowns | length) == $countdowns and (.timers | length) == $timers' <<< "$snapshot" >/dev/null
    printf 'PASS: persisted database snapshot verified after %s\n' "$phase"
done
[[ $(wc -l < "$TIMERS_TEST_SOUND_LOG") -eq 5 ]]
printf '%s\n' 'PASS: countdowns, timers, resets and deletions survive restarts; overdue alarm plays once'
