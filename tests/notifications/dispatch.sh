#!/usr/bin/env bash
# Outgoing notification batching uses mocked notify-send commands only.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-notification-dispatch.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -m700 "$test_dir/runtime"
mkdir -p "$test_dir/bin" "$test_dir/data" "$test_dir/cache"
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$test_dir" -xf -
sed -i \
    -e 's/readonly property int notificationBatchJoinWindow:.*/readonly property int notificationBatchJoinWindow: 120/' \
    -e 's/readonly property int notificationBatchMaxWait:.*/readonly property int notificationBatchMaxWait: 350/' \
    "$test_dir/src/config/Config.qml"
cat > "$test_dir/bin/notify-send" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
jq -cn --argjson time "$(date +%s%3N)" --args '{time:$time,args:$ARGS.positional}' -- "$@" >> "$DISPATCH_TEST_STATE/calls"
MOCK
chmod +x "$test_dir/bin/notify-send"
sed 's@"../../src@"src@g' "$project_root/tests/notifications/dispatch.qml" > "$test_dir/shell.qml"
output=$(PATH="$test_dir/bin:$PATH" DISPATCH_TEST_STATE="$test_dir" QT_QPA_PLATFORM=offscreen \
    QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" \
    XDG_CACHE_HOME="$test_dir/cache" timeout 8 qs -p "$test_dir" 2>&1) || {
        printf '%s\n' "$output" >&2
        exit 1
    }
if [[ $output != *'PASS: notification batches'* || $output == *'DISPATCH FAIL:'* \
    || $output == *'TypeError:'* || $output == *'ReferenceError:'* \
    || $output == *'Binding loop'* || $output == *'Failed to load configuration'* ]]; then
    printf '%s\n' "$output" >&2
    exit 1
fi
jq -se '
    length == 5
    and ([.[] | select(.args[-1] == "twitch-batched" or .args[-1] == "updates-batched")] | length == 2)
    and (([.[] | select(.args[-1] == "twitch-batched" or .args[-1] == "updates-batched") | .time] | max - min) < 200)
    and any(.[]; .args[-1] == "timeout-release")
    and any(.[]; .args[-1] == "peer-empty")
    and any(.[]; .args[-1] == "direct-send")
    and all(.[]; (.args | index("--expire-time=10000")) != null)
' "$test_dir/calls" >/dev/null
printf '%s\n' "$output" | rg 'PASS:'
