#!/usr/bin/env bash
source "$WORKSPACE/handle-virtual-machine.sh"

function handle_remote() {
    local picked=$1
    local endpoint
    local port
    local name
    local displayName
    local username
    local password
    echo $picked

    # NUL-separated fields preserve empty values, delimiters, and backslashes.
    local -a fields=()
    mapfile -d '' -t fields < <(jq -j --arg name "$picked" '.hosts[] | select(.name==$name)
        | [.endpoint, .port, .vmName, .username, .password, .displayName][]
        | (. // "" | tostring) + "\u0000"' "$HOSTS_FILE")
    [[ ${#fields[@]} -eq 6 ]] || return 1
    endpoint=${fields[0]}; port=${fields[1]}; name=${fields[2]}
    username=${fields[3]}; password=${fields[4]}; displayName=${fields[5]}
    base_rdp_params=$(jq -r '.baseRDPParams' "$HOSTS_FILE")
    start_virtual_machine "$name"
    monitor_virtual_machine "$endpoint" "$port" "$name"
    handle_rdp "$endpoint" "$port" "$displayName" "$username" "$password" "$base_rdp_params"
}
