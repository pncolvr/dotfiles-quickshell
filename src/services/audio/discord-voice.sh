#!/usr/bin/env bash
# Synchronize Discord tray checkboxes and Vesktop accessibility voice switches.
set -euo pipefail

usage() {
    echo "Usage: ${0##*/} {mute|deafen} [0|1]"
}

fail() {
    echo "Discord voice sync: $*" >&2
    exit 1
}

if [[ "${1:-}" == --help ]]; then
    usage
    exit 0
fi
if (( $# < 1 || $# > 2 )); then
    usage >&2
    exit 2
fi
case "$1" in
    mute|deafen) label=${1^} ;;
    *) usage >&2; exit 2 ;;
esac
target=${2:-}
if (( $# == 2 )) && [[ "$target" != 0 && "$target" != 1 ]]; then
    usage >&2
    exit 2
fi

bus() {
    busctl --user --json=short --timeout=1 -- "$@"
}

names=$(bus call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ListNames |
    jq -r '.data[0][] | select(startswith("org.freedesktop.StatusNotifierItem-") or startswith("org.kde.StatusNotifierItem-"))')
menu_call() {
    bus call "$service" "$menu" com.canonical.dbusmenu "$@"
}

checkbox() {
    local layout values
    layout=$(menu_call GetLayout iias 0 -1 2 label toggle-state) || return 1
    if ! values=$(jq -er --arg label "$label" '
        .data[1] | recurse(.[2][]?.data)
        | select(((.[1].label.data // "") | gsub("[_&]"; "")) == $label)
        | select(.[1]["toggle-state"].data == 0 or .[1]["toggle-state"].data == 1)
        | [.[0], .[1]["toggle-state"].data] | @tsv
    ' <<<"$layout"); then
        fail "Discord tray has no readable $label checkbox"
    fi
    IFS=$'\t' read -r ident state <<<"$values"
}

sync_discord() (
    menu=$(bus get-property "$service" /StatusNotifierItem org.kde.StatusNotifierItem Menu | jq -er '.data') || exit 1
    menu_call AboutToShow i 0 >/dev/null || exit 1
    checkbox || exit 1
    if [[ -z "$target" ]]; then echo "$state"; exit 0; fi
    [[ "$state" != "$target" ]] || exit 0
    menu_call Event isvu "$ident" clicked i 0 0 >/dev/null || exit 1
    for (( attempt=0; attempt<40; attempt++ )); do
        checkbox || exit 1
        [[ "$state" != "$target" ]] || exit 0
        sleep 0.05
    done
    fail "Discord did not update its $1 state"
)

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
result=0
while IFS= read -r service; do
    [[ -n "$service" ]] || continue
    if ! id=$(bus get-property "$service" /StatusNotifierItem org.kde.StatusNotifierItem Id 2>/dev/null | jq -r '.data'); then
        continue
    fi
    case "$id" in
        discord_status_icon_*)
            sync_discord "$@" || result=1
            ;;
        vesktop_status_icon_*)
            if ! pid=$(bus call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s "$service" | jq -er '.data[0]'); then
                result=1
                continue
            fi
            bash "$script_dir/vesktop-voice.sh" "$pid" "$@" || result=1
            ;;
    esac
done <<<"$names"
exit "$result"
