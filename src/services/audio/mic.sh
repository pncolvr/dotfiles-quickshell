#!/usr/bin/env bash
set -euo pipefail

# Ignore overlapping key events while the two audio controls settle.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/hypr-mic-mute-${UID}.lock"
flock -n 9 || exit 0

source_name=$(pactl get-default-source)
case "$(LC_ALL=C pactl get-source-mute "$source_name")" in
    "Mute: yes") target=0; expected="Mute: no" ;;
    "Mute: no") target=1; expected="Mute: yes" ;;
    *) exit 1 ;;
esac

# Apply the system action immediately; client synchronization is best effort.
pactl set-source-mute "$source_name" "$target"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if ! diagnostic=$(bash "$script_dir/discord-voice.sh" mute "$target" 2>&1); then
    jq -nc --arg detail "$diagnostic" '{key:"audio.errors.discordSync",detail:$detail}' >&2
fi
# A client may also control hardware mute. Keep the requested system state.
if [[ "$(LC_ALL=C pactl get-source-mute "$source_name")" != "$expected" ]]; then
    pactl set-source-mute "$source_name" "$target"
fi
