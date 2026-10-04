#!/usr/bin/env bash
# Read receiver batteries through Solaar's public, read-only `show` command.

parse_devices() {
    local line name='' device_path='' serial='' level state status plugged_in native_path supply identity
    local header_re='^  [0-9]+: (.+)$'
    local detail_re='^[[:space:]]+(Device path|Serial number)[[:space:]]*:[[:space:]]*(.*)$'
    local battery_re='^     Battery: ([^,]+), ([^,]+)(,.*)?\.$'
    local -a records=() supplies=()
    while IFS= read -r line; do
        if [[ $line =~ $header_re ]]; then
            name=${BASH_REMATCH[1]}; device_path=''; serial=''
        elif [[ -n $line && $line != [[:space:]]* ]]; then
            name=$line; device_path=''; serial=''
        fi
        [[ -n $name ]] || continue
        if [[ $line =~ $detail_re ]]; then
            case ${BASH_REMATCH[1]} in
                'Device path') device_path=${BASH_REMATCH[2]} ;;
                'Serial number') serial=${BASH_REMATCH[2]} ;;
            esac
        fi
        # Feature details also print batteries. Only use the final device summary.
        [[ $line =~ $battery_re ]] || continue
        level=${BASH_REMATCH[1]}
        status=${BASH_REMATCH[2]#BatteryStatus.}
        status=${status//_/ }
        status=${status^^}
        [[ $status != OFFLINE && $level != *offline* ]] || continue
        if [[ $level =~ ([0-9]+)% ]]; then
            level=$((10#${BASH_REMATCH[1]}))
            ((level <= 100)) || level=100
        else
            level=null
        fi
        state=unknown; plugged_in=false
        case $status in
            DISCHARGING) state=discharging ;;
            RECHARGING|'ALMOST FULL'|'SLOW RECHARGE') state=charging; plugged_in=true ;;
            FULL|'FULLY CHARGED') state=charged; plugged_in=true ;;
        esac
        native_path=''; supplies=()
        if [[ $device_path == /dev/hidraw* ]]; then
            for supply in "${BATTERY_SYSFS_ROOT:-/sys}/class/hidraw/${device_path##*/}/device/power_supply/"*; do
                [[ -d $supply ]] && supplies+=("$supply")
            done
            if ((${#supplies[@]} == 1)); then native_path=${supplies[0]##*/}; fi
        fi
        identity=${serial:-$device_path:$name}
        records+=("$(jq -cn --arg id "solaar:$identity" --arg name "$name" --arg nativePath "$native_path" \
            --arg state "$state" --argjson percentage "$level" --argjson pluggedIn "$plugged_in" \
            '{id: $id, name: $name, nativePath: $nativePath, internal: false, percentage: $percentage,
              state: $state, pluggedIn: $pluggedIn, timeToFull: 0, timeToEmpty: 0}')")
    done
    printf '%s\n' "${records[@]}" | jq -sc 'unique_by(.id)'
}

read_batteries() {
    if ! command -v solaar >/dev/null; then
        printf '%s\n' '{"devices":[],"error":""}'
        return
    fi
    if ! command -v jq >/dev/null; then
        printf '%s\n' '{"devices":[],"error":"Some device batteries could not be read (jq is missing)"}'
        return
    fi
    local errors output devices
    errors=$(mktemp /tmp/quickshell-battery-errors.XXXXXX)
    trap 'rm -f -- "$errors"' EXIT
    if output=$(LC_ALL=C timeout 45 solaar show 2>"$errors"); then
        devices=$(parse_devices <<< "$output")
        jq -cn --argjson devices "$devices" '{devices: $devices, error: ""}'
    elif [[ $(<"$errors") == *'No supported device found'* ]]; then
        printf '%s\n' '{"devices":[],"error":""}'
    else
        printf '%s\n' '{"devices":[],"error":"Some device batteries could not be read"}'
    fi
    rm -f -- "$errors"
    trap - EXIT
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    read_batteries
fi
