#!/usr/bin/env bash
# A PID alone is reusable. Match owner, boot and kernel start time before signalling.
process_identity() {
    local pid=$1 stat rest
    local -a fields
    [[ $pid =~ ^[1-9][0-9]*$ && -O /proc/$pid ]] || return 1
    stat=$(cat "/proc/$pid/stat" 2>/dev/null) || return 1
    rest=${stat##*) }
    read -r -a fields <<< "$rest"
    [[ ${fields[0]} != Z && ${fields[0]} != X ]] || return 1
    printf '%s' "${fields[19]}"
}
process_alive() {
    [[ $1 =~ ^[1-9][0-9]*$ && -n $2 && $3 == "$PROCESS_BOOT_ID" ]] || return 1
    [[ $(process_identity "$1") == "$2" ]]
}
PROCESS_BOOT_ID=$(cat /proc/sys/kernel/random/boot_id) || return 2
