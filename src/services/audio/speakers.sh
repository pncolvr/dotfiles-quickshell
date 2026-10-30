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
    "Mute: yes") target=0; sink_expected="Mute: no" ;;
    "Mute: no") target=1; sink_expected="Mute: yes" ;;
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

if [[ "$mic_target" == 1 ]]; then mic_expected="Mute: yes"; else mic_expected="Mute: no"; fi
# Apply the system action immediately; client synchronization is best effort.
pactl set-source-mute "$source_name" "$mic_target"
pactl set-sink-mute "$sink_name" "$target"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if ! diagnostic=$(bash "$script_dir/discord-voice.sh" deafen "$target" 2>&1); then
    jq -nc --arg detail "$diagnostic" '{key:"audio.errors.discordSync",detail:$detail}' >&2
fi
# A client may also control hardware mute. Keep the requested system states.
if [[ "$(LC_ALL=C pactl get-source-mute "$source_name")" != "$mic_expected" ]]; then
    pactl set-source-mute "$source_name" "$mic_target"
fi
if [[ "$(LC_ALL=C pactl get-sink-mute "$sink_name")" != "$sink_expected" ]]; then
    pactl set-sink-mute "$sink_name" "$target"
fi
if [[ "$target" == 0 ]]; then
    rm -f -- "$state_file"
fi
