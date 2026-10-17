#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-audio-route.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir "$test_dir/bin"
export AUDIO_TEST_STATE="$test_dir"
export PATH="$test_dir/bin:$PATH"
cat > "$test_dir/bin/pactl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\t' "$@" >> "$AUDIO_TEST_STATE/calls"
printf '\n' >> "$AUDIO_TEST_STATE/calls"
if [[ $1 == -f && $2 == json && $3 == list ]]; then
    cat "$AUDIO_TEST_STATE/$4.json"
elif [[ $1 == move-sink-input || $1 == move-source-output ]]; then
    if [[ ${AUDIO_TEST_FAIL_INDEX:-} == "$2" ]]; then
        if [[ ${AUDIO_TEST_DISAPPEAR:-0} == 1 ]]; then
            printf '[]\n' > "$AUDIO_TEST_STATE/sink-inputs.json"
        fi
        exit 1
    fi
else
    printf 'Unexpected command\n' >&2
    exit 1
fi
MOCK
chmod +x "$test_dir/bin/pactl"
cat > "$test_dir/sinks.json" <<'JSON'
[{"index":10,"name":"speaker (desk) $literal"},{"index":11,"name":"headset"}]
JSON
cat > "$test_dir/sources.json" <<'JSON'
[{"index":12,"name":"mic","monitor_source":""},{"index":13,"name":"speaker.monitor","monitor_source":"speaker"}]
JSON
cat > "$test_dir/sink-inputs.json" <<'JSON'
[
 {"index":21,"properties":{"application.name":"Browser","object.serial":"101"}},
 {"index":22,"properties":{"application.name":"Player","object.serial":"102"}},
 {"index":23,"properties":{"node.name":"effect_output.virtual-surround","object.serial":"103"}},
 {"index":24,"properties":{"application.name":"Quickshell Peak Detect","object.serial":"104"}},
 {"index":25,"properties":{"application.name":"Monitor","node.name":"quickshell-peak-monitor","object.serial":"105"}},
 {"index":26,"properties":{"application.name":"Quickshell Spectrum Detect","object.serial":"106"}},
 {"index":27,"properties":{"application.name":"Monitor","node.name":"quickshell-spectrum-monitor","object.serial":"107"}}
]
JSON
cat > "$test_dir/source-outputs.json" <<'JSON'
[{"index":31,"properties":{"application.name":"Recorder","object.serial":"201"}},{"index":32,"properties":{"application.name":"Quickshell Peak Detect","object.serial":"202"}},{"index":33,"properties":{"application.name":"Quickshell Spectrum Detect","object.serial":"203"}}]
JSON
helper="$project_root/src/services/audio/audio-route.sh"
result=$(bash "$helper" output 'speaker (desk) $literal')
[[ $(jq -r '.key' <<< "$result") == audio.route.status.apps && $(jq -r '.count' <<< "$result") == 2 ]]
mapfile -t moves < <(rg '^move-' "$test_dir/calls")
[[ ${#moves[@]} == 2 && ${moves[0]} == $'move-sink-input\t21\tspeaker (desk) $literal\t' && ${moves[1]} == $'move-sink-input\t22\tspeaker (desk) $literal\t' ]]
! rg -q 'set-default' "$test_dir/calls"

: > "$test_dir/calls"
result=$(bash "$helper" output headset 101)
[[ $(jq -r '.key' <<< "$result") == audio.route.status.app ]]
mapfile -t moves < <(rg '^move-' "$test_dir/calls")
[[ ${#moves[@]} == 1 && ${moves[0]} == $'move-sink-input\t21\theadset\t' ]]
! rg -q 'set-default' "$test_dir/calls"
: > "$test_dir/calls"
result=$(bash "$helper" input mic 201)
mapfile -t moves < <(rg '^move-' "$test_dir/calls")
[[ $(jq -r '.key' <<< "$result") == audio.route.status.app && ${#moves[@]} == 1 && ${moves[0]} == $'move-source-output\t31\tmic\t' ]]

cp "$test_dir/sink-inputs.json" "$test_dir/original-streams.json"
jq '. + [{index:26,properties:{"application.name":"Browser","object.serial":"106"}}]' \
    "$test_dir/original-streams.json" > "$test_dir/sink-inputs.json"
: > "$test_dir/calls"
result=$(bash "$helper" output headset 101 106)
mapfile -t moves < <(rg '^move-' "$test_dir/calls")
[[ $(jq -r '.key' <<< "$result") == audio.route.status.app && ${#moves[@]} == 2 && ${moves[0]} == $'move-sink-input\t21\theadset\t' && ${moves[1]} == $'move-sink-input\t26\theadset\t' ]]
cp "$test_dir/original-streams.json" "$test_dir/sink-inputs.json"

for serial in 999 103 104 105; do
    : > "$test_dir/calls"
    if bash "$helper" output headset "$serial" > "$test_dir/out" 2> "$test_dir/error"; then
        printf 'FAIL: moved missing app or internal stream\n' >&2; exit 1
    fi
    [[ $(jq -r .key "$test_dir/error") == audio.route.errors.appStopped ]]
    ! rg -q '^move-' "$test_dir/calls"
done
: > "$test_dir/calls"
result=$(bash "$helper" input mic)
[[ $(jq -r '.key' <<< "$result") == audio.route.status.apps && $(jq -r '.count' <<< "$result") == 1 ]]
mapfile -t moves < <(rg '^move-' "$test_dir/calls")
[[ ${#moves[@]} == 1 && ${moves[0]} == $'move-source-output\t31\tmic\t' ]]
! rg -q 'set-default' "$test_dir/calls"

for arguments in 'input speaker.monitor' 'output missing'; do
    read -r direction device <<< "$arguments"
    if bash "$helper" "$direction" "$device" > "$test_dir/out" 2> "$test_dir/error"; then
        printf 'FAIL: accepted unavailable or monitor device\n' >&2; exit 1
    fi
    [[ $(jq -r .key "$test_dir/error") == audio.route.errors.deviceUnavailable ]]
done

if AUDIO_TEST_FAIL_INDEX=21 bash "$helper" output headset > "$test_dir/out" 2> "$test_dir/error"; then
    printf 'FAIL: did not report routing failure\n' >&2; exit 1
fi
[[ $(jq -r .key "$test_dir/error") == audio.route.errors.switchApp ]]
result=$(AUDIO_TEST_FAIL_INDEX=21 AUDIO_TEST_DISAPPEAR=1 bash "$helper" output headset)
[[ $(jq -r '.key' <<< "$result") == audio.route.status.apps && $(jq -r '.count' <<< "$result") == 1 ]]
result=$(bash "$helper" output headset)
[[ $(jq -r .key <<< "$result") == audio.route.status.empty ]]
printf 'PASS: audio routing, individual apps, multiple streams, separate defaults, monitor filtering, disappearing apps, and errors\n'
