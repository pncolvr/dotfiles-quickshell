#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-browser-channels.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
helper="$project_root/services/twitch/qutebrowser-channels.sh"
session_file="$test_dir/session.yml"

check() {
    local actual
    actual=$(bash "$helper" "$session_file")
    [[ $actual == "$1" ]] || { printf 'FAIL: %s (got %s)\n' "$2" "$actual" >&2; exit 1; }
}

check '[]' 'missing session'
for malformed in '' 'windows: [' 'windows: null' 'windows: [null]' '- unexpected'; do
    printf '%s\n' "$malformed" > "$session_file"
    check '[]' 'empty or malformed session'
done

cat > "$session_file" <<'YAML'
windows:
  - tabs:
      - active: true
        history:
          - url: https://www.twitch.tv/historical
          - active: true
            url: https://www.twitch.tv/Zeta
  - tabs:
      - history:
          - active: true
            url: https://www.twitch.tv/alpha/schedule
      - history:
          - active: true
            url: https://m.twitch.tv/zeta/?ref=test
YAML
check '["alpha","zeta"]' 'all windows and background tabs, lowercase, sorted, deduplicated, and history excluded'

for channel_url in 'https://www.twitch.tv/Krysttl' 'https://twitch.tv/krysttl/' \
    'http://m.twitch.tv/krysttl?ref=test#about' 'https://www.twitch.tv/krysttl/schedule'; do
    jq -n --arg url "$channel_url" '{windows: [{tabs: [{history: [{active: true, url: $url}]}]}]}' > "$session_file"
    check '["krysttl"]' 'channel URL recognized'
done
for other_url in 'https://www.twitch.tv/directory' 'https://www.twitch.tv/videos/123' \
    'https://clips.twitch.tv/SomeClip' 'https://www.twitch.tv/' 'https://example.org/krysttl' \
    'https://twitch.tv.evil.org/krysttl' 'https://www.twitch.tv/abcdefghijklmnopqrstuvwxyz' \
    'https://[invalid' 'https://www.twitch.tv/krysttl/unknown'; do
    jq -n --arg url "$other_url" '{windows: [{tabs: [{history: [{active: true, url: $url}]}]}]}' > "$session_file"
    check '[]' 'non-channel URL excluded'
done

# Navigating within one tab and manually saving must replace the old autosave.
autosave_file="$test_dir/_autosave.yml"
manual_file="$test_dir/default.yml"
jq -n '{windows: [{tabs: [{history: [{active: true, url: "https://www.twitch.tv/old_streamer"}]}]}]}' > "$autosave_file"
jq -n '{windows: [{tabs: [{history: [
    {url: "https://www.twitch.tv/old_streamer"},
    {active: true, url: "https://www.twitch.tv/new_streamer"}
]}]}]}' > "$manual_file"
touch -t 202601010000 "$autosave_file"
touch -t 202601010001 "$manual_file"
[[ $(bash "$helper" "$autosave_file" "$manual_file") == '["new_streamer"]' ]]
[[ $(bash "$helper" "$manual_file" "$autosave_file") == '["new_streamer"]' ]]
touch -t 202601010002 "$autosave_file"
[[ $(bash "$helper" "$autosave_file" "$manual_file") == '["old_streamer"]' ]]
[[ $(bash "$helper" "$test_dir/missing.yml" "$manual_file") == '["new_streamer"]' ]]
printf 'PASS: qutebrowser current tabs, channel URLs, filtering, deduplication, and missing or malformed sessions\n'
