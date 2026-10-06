#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-audio-profiles.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir "$test_dir/bin"
export AUDIO_TEST_STATE="$test_dir"
export PATH="$test_dir/bin:$PATH"
cat > "$test_dir/bin/pactl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ $1 == -f && $2 == json && $3 == list ]]; then
    cat "$AUDIO_TEST_STATE/$4.json"
elif [[ $1 == set-card-profile ]]; then
    printf '%s\n' "$2" "$3" > "$AUDIO_TEST_STATE/selected"
    [[ ${AUDIO_TEST_PROFILE_FAIL:-0} == 0 ]]
else
    exit 1
fi
MOCK
chmod +x "$test_dir/bin/pactl"
cat > "$test_dir/cards.json" <<'JSON'
[
 {"index":7,"name":"headset (card)","active_profile":"duplex","properties":{"device.description":"Headset"},"profiles":{
  "duplex":{"description":"Stereo Output + Mono Input","sources":1,"sinks":1,"available":true},
  "stereo":{"description":"Stereo Output","sources":0,"sinks":1,"available":"unknown"},
  "unavailable":{"description":"Unavailable","sources":1,"sinks":0,"available":false},
  "off":{"description":"Off","sources":0,"sinks":0,"available":true}}},
 {"index":8,"name":"camera","active_profile":"off","properties":{"device.description":"Camera Microphone"},"profiles":{
  "input":{"description":"Mono Input","sources":1,"sinks":0,"available":true},
  "off":{"description":"Off","sources":0,"sinks":0,"available":true}}}
]
JSON
printf '%s\n' '[{"name":"headphones","properties":{"device.name":"headset (card)"}},{"name":"virtual","properties":{}}]' > "$test_dir/sinks.json"
printf '%s\n' '[{"name":"microphone","card":7,"properties":{}}]' > "$test_dir/sources.json"
helper="$project_root/src/services/audio/audio-devices.sh"
result=$(bash "$helper" list)
jq -e '
    (.cards | length) == 2 and (.nodes | length) == 2
    and any(.nodes[]; .name == "headphones" and .cardName == "headset (card)")
    and any(.nodes[]; .name == "microphone" and .cardName == "headset (card)")
    and any(.cards[]; .name == "camera" and .activeProfile == "off" and any(.profiles[]; .input and .available))
    and any(.cards[].profiles[]; .name == "stereo" and .available and .output and (.input | not))
    and any(.cards[].profiles[]; .name == "unavailable" and (.available | not))
' <<< "$result" >/dev/null
bash "$helper" set-profile 'headset (card)' stereo
mapfile -t selected < "$test_dir/selected"
[[ ${selected[0]} == 'headset (card)' && ${selected[1]} == stereo ]]
for profile in unavailable missing; do
    if bash "$helper" set-profile 'headset (card)' "$profile" > "$test_dir/out" 2> "$test_dir/error"; then
        printf 'FAIL: accepted unavailable profile\n' >&2; exit 1
    fi
    [[ $(<"$test_dir/error") == 'That audio profile is no longer available.' ]]
done
if AUDIO_TEST_PROFILE_FAIL=1 bash "$helper" set-profile 'headset (card)' stereo > "$test_dir/out" 2> "$test_dir/error"; then
    printf 'FAIL: ignored profile failure\n' >&2; exit 1
fi
[[ $(<"$test_dir/error") == 'Could not change the audio device profile.' ]]
printf 'PASS: audio profile discovery, disabled cards, exact device mapping, availability, selection, and errors\n'
