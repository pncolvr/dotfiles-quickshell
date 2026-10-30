#!/usr/bin/env bash
set -euo pipefail
umask 077

runtime_dir=${XDG_RUNTIME_DIR:-/tmp}
state_file="$runtime_dir/hypr-speaker-mute-${UID}.state"
# Share the mic lock so the two bindings cannot change it simultaneously.
exec 9>"$runtime_dir/hypr-mic-mute-${UID}.lock"
flock -n 9 || exit 0

sink_name=$(pactl get-default-sink)
case "$(LC_ALL=C pactl get-sink-mute "$sink_name")" in
    "Mute: yes") target=0 ;;
    "Mute: no") target=1 ;;
    *) exit 1 ;;
esac

source_name=$(pactl get-default-source)
case "$(LC_ALL=C pactl get-source-mute "$source_name")" in
    "Mute: yes") mic_target=1 ;;
    "Mute: no") mic_target=0 ;;
    *) exit 1 ;;
esac

if [[ "$target" == 1 ]]; then
    printf '%s\n%s\n' "$source_name" "$mic_target" >"$state_file"
    mic_target=1
elif [[ -f "$state_file" ]]; then
    {
        IFS= read -r source_name
        IFS= read -r mic_target
    } <"$state_file"
    [[ "$mic_target" == 0 || "$mic_target" == 1 ]] || exit 1
fi

# Read Discord's actual checkbox instead of assuming it matches the speakers.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if ! diagnostic=$(bash "$script_dir/discord-voice.sh" deafen "$target" 2>&1); then
    jq -nc --arg detail "$diagnostic" '{key:"audio.errors.discordSync",detail:$detail}' >&2
fi
sleep 0.2
pactl set-sink-mute "$sink_name" "$target"
pactl set-source-mute "$source_name" "$mic_target"
if [[ "$target" == 0 ]]; then
    rm -f -- "$state_file"
fi
