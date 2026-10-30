#!/usr/bin/env bash
set -euo pipefail

# Ignore overlapping key events while the two audio controls settle.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/hypr-mic-mute-${UID}.lock"
flock -n 9 || exit 0

source_name=$(pactl get-default-source)
case "$(LC_ALL=C pactl get-source-mute "$source_name")" in
    "Mute: yes") target=0 ;;
    "Mute: no") target=1 ;;
    *) exit 1 ;;
esac

# Read Discord's actual checkbox instead of assuming it matches the microphone.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if ! diagnostic=$(bash "$script_dir/discord-voice.sh" mute "$target" 2>&1); then
    jq -nc --arg detail "$diagnostic" '{key:"audio.errors.discordSync",detail:$detail}' >&2
fi
sleep 0.2
pactl set-source-mute "$source_name" "$target"
