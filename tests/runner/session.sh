#!/usr/bin/env bash
# Keep the private bus alive until its activated desktop services have stopped.
set -euo pipefail
runner_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$runner_dir/../../src/services/processes/process-identity.sh"
bus_call() {
    timeout 3 gdbus call --session --dest org.freedesktop.DBus \
        --object-path /org/freedesktop/DBus --method "org.freedesktop.DBus.$1" "${@:2}"
}
connection_pid() {
    local reply
    reply=$(bus_call GetConnectionUnixProcessID "$1" 2>/dev/null) || return 1
    [[ $reply =~ ^\(uint32\ ([1-9][0-9]*),\)$ ]] || return 1
    printf '%s' "${BASH_REMATCH[1]}"
}
# Require the daemon and wrapper to be children of this dbus-run-session. This
# rejects accidental invocation on the desktop bus before installing any cleanup.
bus_pid=$(connection_pid org.freedesktop.DBus) || exit 2
bus_start=$(process_identity "$bus_pid") || exit 2
bus_parent=$(awk '/^PPid:/ { print $2 }' "/proc/$bus_pid/status")
parent_executable=$(readlink -- "/proc/$PPID/exe")
if [[ $bus_parent != "$PPID" || ${parent_executable##*/} != dbus-run-session || $# == 0 ]]; then
    printf 'Test session wrapper requires its own dbus-run-session and a command.\n' >&2
    exit 2
fi
cleanup() {
    local result=$? names service pid start alive deadline index
    local -a pids=() starts=()
    local -A seen=()
    trap - EXIT
    process_alive "$bus_pid" "$bus_start" "$PROCESS_BOOT_ID" || return "$result"
    names=$(bus_call ListNames 2>/dev/null) || return "$result"
    while IFS= read -r service; do
        pid=$(connection_pid "$service") || continue
        [[ -z ${seen[$pid]:-} ]] || continue
        seen[$pid]=true
        start=$(process_identity "$pid") || continue
        if process_alive "$pid" "$start" "$PROCESS_BOOT_ID"; then
            pids+=("$pid"); starts+=("$start")
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done < <({
        printf '%s\n' org.freedesktop.portal.Desktop
        tr "'" '\n' <<< "$names" | awk '
            /^org\.freedesktop\.(impl\.)?portal\./ || /^org\.gtk\.vfs\./ || $0 == "ca.desrt.dconf"
        '
    })
    deadline=$((SECONDS + 3))
    while :; do
        alive=false
        for index in "${!pids[@]}"; do
            if process_alive "${pids[index]}" "${starts[index]}" "$PROCESS_BOOT_ID"; then alive=true; fi
        done
        if ! $alive; then break; fi
        if ((SECONDS >= deadline)); then
            for index in "${!pids[@]}"; do
                if process_alive "${pids[index]}" "${starts[index]}" "$PROCESS_BOOT_ID"; then
                    kill -KILL "${pids[index]}" 2>/dev/null || true
                fi
            done
            break
        fi
        sleep 0.025
    done
    return "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
"$@"
