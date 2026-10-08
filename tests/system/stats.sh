#!/usr/bin/env bash
# Headless checks use private data, a mock clipboard and fake desktop commands.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
bash "$project_root/tests/system/stats-processes.sh"
test_dir=$(mktemp -d /tmp/quickshell-stats-test.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
tar -C "$project_root" --exclude='*.env' --exclude='hosts.json' -cf - src | tar -C "$test_dir" -xf -
mkdir -m 700 "$test_dir/runtime"
mkdir "$test_dir/data" "$test_dir/cache" "$test_dir/bin"
cat > "$test_dir/bin/wl-copy" <<'MOCK'
#!/usr/bin/env bash
printf '%s' "${!#}" > "$STATS_TEST_CLIPBOARD"
MOCK
chmod +x "$test_dir/bin/wl-copy"
sed -i 's@readonly property var networkCheckCommand:.*@readonly property var networkCheckCommand: ["true"]@;s@readonly property var networkVpnCommand:.*@readonly property var networkVpnCommand: ["true"]@' "$test_dir/src/config/Config.qml"
export STATS_TEST_CLIPBOARD="$test_dir/copied"
for fixture in stats-smoke stats-service-smoke stats-native-smoke; do
    sed 's@"../../src@"src@g' "$project_root/tests/system/$fixture.qml" > "$test_dir/shell.qml"
    output=$(PATH="$test_dir/bin:$PATH" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$test_dir/runtime" \
        XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" timeout 15 qs -p "$test_dir/shell.qml" 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
    while IFS= read -r line; do [[ $line != *'PASS:'* ]] || printf '%s\n' "$line"; done <<< "$output"
    [[ $output == *'PASS:'* && $output != *'STATS FAIL:'* && $output != *'TypeError:'* \
        && $output != *'ReferenceError:'* && $output != *'Binding loop'* && $output != *'Failed to load configuration'* ]] || { printf "%s\n" "$output" >&2; exit 1; }
done
[[ $(cat "$STATS_TEST_CLIPBOARD") == 2345 ]]
