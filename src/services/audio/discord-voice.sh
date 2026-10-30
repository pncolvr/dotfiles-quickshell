#!/usr/bin/env bash
# Read or set Discord voice checkboxes through its native tray menu.
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
menu=
while IFS= read -r service; do
    [[ -n "$service" ]] || continue
    if ! id=$(bus get-property "$service" /StatusNotifierItem org.kde.StatusNotifierItem Id 2>/dev/null | jq -r '.data'); then
        continue
    fi
    [[ "$id" == discord_status_icon_* ]] || continue
    menu=$(bus get-property "$service" /StatusNotifierItem org.kde.StatusNotifierItem Menu | jq -er '.data')
    break
done <<<"$names"
[[ -n "$menu" ]] || exit 0

menu_call() {
    bus call "$service" "$menu" com.canonical.dbusmenu "$@"
}

checkbox() {
    local layout values
    layout=$(menu_call GetLayout iias 0 -1 2 label toggle-state)
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

menu_call AboutToShow i 0 >/dev/null
checkbox
if [[ -z "$target" ]]; then
    echo "$state"
    exit 0
fi
[[ "$state" != "$target" ]] || exit 0
menu_call Event isvu "$ident" clicked i 0 0 >/dev/null
for (( attempt=0; attempt<40; attempt++ )); do
    checkbox
    [[ "$state" != "$target" ]] || exit 0
    sleep 0.05
done
fail "Discord did not update its $1 state"
