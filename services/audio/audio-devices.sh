#!/usr/bin/env bash
# Card profiles are not exposed by Quickshell's native PipeWire node API.
set -euo pipefail
fail() { printf '%s\n' "$*" >&2; exit 1; }
for dependency in pactl jq timeout; do
    command -v "$dependency" >/dev/null || fail "Audio profiles require $dependency."
done
pulse() { timeout 5 pactl "$@"; }
cards=$(pulse -f json list cards) || fail 'Could not read audio device profiles.'
case ${1:-} in
    list)
        [[ $# == 1 ]] || fail 'Usage: audio-devices.sh list'
        sinks=$(pulse -f json list sinks) || fail 'Could not read audio outputs.'
        sources=$(pulse -f json list sources) || fail 'Could not read microphones.'
        jq -cn --argjson cards "$cards" --argjson sinks "$sinks" --argjson sources "$sources" '
            {cards: [$cards[] | {
                name, description: (.properties["device.description"] // .name),
                activeProfile: .active_profile,
                profiles: [.profiles | to_entries[] | {
                    name: .key, description: .value.description,
                    input: (.value.sources > 0), output: (.value.sinks > 0),
                    available: (.value.available == true or .value.available == "yes" or .value.available == "unknown")
                }]
            }], nodes: [($sinks + $sources)[] as $node
                | $cards[] | select(.name == $node.properties["device.name"] or
                    ($node.card != null and .index == $node.card)) | {name: $node.name, cardName: .name} ]}
        ' || fail 'Could not read audio device profiles.'
        ;;
    set-profile)
        [[ $# == 3 && -n $2 && -n $3 ]] || fail 'Usage: audio-devices.sh set-profile CARD PROFILE'
        jq -e --arg card "$2" --arg profile "$3" '
            any(.[]; .name == $card and (.profiles[$profile] | . != null and
                (.available == true or .available == "yes" or .available == "unknown")))
        ' <<< "$cards" >/dev/null || fail 'That audio profile is no longer available.'
        pulse set-card-profile "$2" "$3" || fail 'Could not change the audio device profile.'
        ;;
    *) fail 'Usage: audio-devices.sh list | set-profile CARD PROFILE' ;;
esac
