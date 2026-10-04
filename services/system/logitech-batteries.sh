#!/usr/bin/env bash
# Read receiver batteries through Solaar's public, read-only `show` command.

brand_from_path() {
    local device_path=$1 brand_file brand=''
    [[ $device_path == /dev/hidraw* ]] || return 0
    local device_root="${BATTERY_SYSFS_ROOT:-/sys}/class/hidraw/${device_path##*/}/device"
    for brand_file in "$device_root/manufacturer" "$device_root/../manufacturer" \
        "$device_root/../../manufacturer" "$device_root/../../../manufacturer"; do
        [[ -r $brand_file ]] || continue
        IFS= read -r brand < "$brand_file" || true
        if [[ -n $brand ]]; then printf '%s' "$brand"; return; fi
    done
}

parse_devices() {
    local line name='' device_path='' serial='' level state status plugged_in native_path supply identity
    local brand='' receiver_path='' receiver_brand='' reported_brand
    local header_re='^  [0-9]+: (.+)$'
    local detail_re='^[[:space:]]+(Device path|Serial number|Manufacturer)[[:space:]]*:[[:space:]]*(.*)$'
    local battery_re='^     Battery: ([^,]+), ([^,]+)(,.*)?\.$'
    local -a records=() supplies=()
    while IFS= read -r line; do
        if [[ $line =~ $header_re ]]; then
            name=${BASH_REMATCH[1]}; device_path=''; serial=''; brand=''
        elif [[ -n $line && $line != [[:space:]]* ]]; then
            name=$line; device_path=''; serial=''; brand=''; receiver_path=''; receiver_brand=''
        fi
        [[ -n $name ]] || continue
        if [[ $line =~ $detail_re ]]; then
            case ${BASH_REMATCH[1]} in
                'Device path')
                    device_path=${BASH_REMATCH[2]}
                    if [[ $line == '  Device path'* ]]; then receiver_path=$device_path; fi
                    ;;
                'Serial number') serial=${BASH_REMATCH[2]} ;;
                'Manufacturer')
                    brand=${BASH_REMATCH[2]}
                    if [[ $line == '  Manufacturer'* ]]; then receiver_brand=$brand; fi
                    ;;
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
        reported_brand=${brand:-$(brand_from_path "$device_path")}
        reported_brand=${reported_brand:-${receiver_brand:-$(brand_from_path "$receiver_path")}}
        # Solaar handles the Logitech receiver family; use a reported OEM brand when present.
        reported_brand=${reported_brand:-Logitech}
        records+=("$(jq -cn --arg id "solaar:$identity" --arg name "$name" --arg nativePath "$native_path" \
            --arg brand "$reported_brand" \
            --arg state "$state" --argjson percentage "$level" --argjson pluggedIn "$plugged_in" \
            '{id: $id, name: $name, brand: $brand, nativePath: $nativePath, internal: false, percentage: $percentage,
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
