#!/usr/bin/env bash
# Read/set Vesktop's checkable voice switches without focus or keyboard injection.
set -euo pipefail

fail() { echo "Vesktop voice sync: $*" >&2; exit 1; }
if (( $# < 2 || $# > 3 )) || [[ ! ${1:-} =~ ^[0-9]+$ ]]; then
    echo "Usage: ${0##*/} PID {mute|deafen} [0|1]" >&2
    exit 2
fi
pid=$1
case "$2" in
    mute) label=Mute; alternative=Unmute ;;
    deafen) label=Deafen; alternative=Undeafen ;;
    *) exit 2 ;;
esac
target=${3:-}
if (( $# == 3 )) && [[ "$target" != 0 && "$target" != 1 ]]; then exit 2; fi

address=$(busctl --user --json=short --timeout=1 -- call org.a11y.Bus /org/a11y/bus org.a11y.Bus GetAddress | jq -er '.data[0]')
accessible() { busctl --address="$address" --json=short --timeout=1 -- "$@"; }
apps=$(accessible call org.a11y.atspi.Registry /org/a11y/atspi/accessible/root org.a11y.atspi.Accessible GetChildren)
application=
while IFS=$'\t' read -r candidate root; do
    if ! owner=$(accessible call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s "$candidate" 2>/dev/null | jq -er '.data[0]'); then
        continue
    fi
    [[ "$owner" == "$pid" ]] || continue
    application=$candidate
    break
done < <(jq -r '.data[0][] | @tsv' <<<"$apps")
[[ -n "$application" ]] || fail 'Accessibility unavailable; launch Vesktop with ACCESSIBILITY_ENABLED=1 and --force-renderer-accessibility.'

read_state() {
    local flags low high
    flags=$(accessible call "$application" "$control" org.a11y.atspi.Accessible GetState | jq -er '
        .data[0] | select(type == "array" and length >= 2)
        | [.[0], .[1]] | select(all(.[]; type == "number")) | @tsv
    ') || return 1
    IFS=$'\t' read -r low high <<<"$flags"
    # Replaced/incomplete objects must not look like an unchecked voice switch.
    # DEFUNCT=6, STALE=27, CHECKABLE=41, CHECKED=4.
    (( (low & 134217792) == 0 && (high & 512) != 0 )) || return 1
    state=$(( (low & 16) != 0 ))
}

find_control() {
    local matches object name
    # CHECKABLE=41, TOGGLE_BUTTON=62; query only actionable voice switches.
    # Match rules are bitsets, followed by ALL=1 or ANY=2 for each criterion.
    matches=$(accessible call "$application" "$root" org.a11y.atspi.Collection GetMatches \
        '(aiia{ss}iaiiasib)uib' 2 0 512 1 0 1 2 0 1073741824 2 1 Action 1 false 1 0 true) || return 1
    while IFS=$'\t' read -r candidate object; do
        [[ "$candidate" == "$application" ]] || continue
        name=$(accessible get-property "$application" "$object" org.a11y.atspi.Accessible Name | jq -er '.data') || continue
        [[ "$name" == "$label" || "$name" == "$alternative" ]] || continue
        control=$object
        read_state && return 0
    done < <(jq -r '.data[0][] | @tsv' <<<"$matches")
    return 1
}

find_control || fail "No readable $label voice switch"
if [[ -z "$target" ]]; then echo "$state"; exit 0; fi
[[ "$state" != "$target" ]] || exit 0
reply=$(accessible call "$application" "$control" org.a11y.atspi.Action DoAction i 0) \
    || fail "D-Bus error requesting $label (PID=$pid, object=$control)"
jq -e '.data[0] == true' <<<"$reply" >/dev/null \
    || fail "Action rejected for $label (PID=$pid, object=$control)"
for (( attempt=0; attempt<40; attempt++ )); do
    if read_state || find_control; then
        [[ "$state" != "$target" ]] || exit 0
    fi
    sleep 0.05
done
fail "Vesktop did not update $2 (requested=$target, last_read=$state, PID=$pid, object=$control)"
