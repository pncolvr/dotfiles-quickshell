#!/usr/bin/env bash

source "$(dirname -- "${BASH_SOURCE[0]}")/_common/utils.sh"

log_inactive() {
    "$ZDOTDIR/scripts/status/manager.sh" --log-system-event inactive
}

show_menu() {
    local entries=(
        $'' Reboot
        $'' Lock
        $'' Logout
        $'' Shutdown
        $'' Bios
    )
    local rows=() i
    for ((i = 0; i < ${#entries[@]}; i += 2)); do
        rows+=("$(jq -cn --arg glyph "${entries[i]}" --arg title "${entries[i + 1]}" \
            '{title:$title, glyph:$glyph, result:$title}')")
    done
    # Keep the original action order and render glyphs with the shell's icon font.
    bash "$PICKER_LAUNCHER" --json <(
        printf '%s\n' "${rows[@]}" | jq -s '{allowTyped:false, sort:false, smartCase:true, fuzzy:true, layout:"grid", items:.}'
    )
}

chosen="${1:-}"
if [[ -z "$chosen" ]]; then
    chosen=$(show_menu)
fi

case $chosen in
    *Reboot*)   log_inactive; systemctl reboot;;
    *Lock*)     log_inactive; loginctl lock-session;;
    *Logout*)   log_inactive; hyprctl dispatch exit;;
    *Shutdown*) log_inactive; systemctl poweroff;;
    *Bios*)     log_inactive; systemctl reboot --firmware-setup;;
    *)          exit 0;;
esac
