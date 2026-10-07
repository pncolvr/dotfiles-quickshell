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

    IFS=';' read endpoint port name username password displayName \
        <<< "$(jq -r --arg name "$picked" '.hosts[] | select(.name==$name) | [.endpoint, .port, .vmName, .username , .password, .displayName ] | join(";")' "$HOSTS_FILE")"
    base_rdp_params=$(jq -r '.baseRDPParams' "$HOSTS_FILE")
    start_virtual_machine "$name"
    monitor_virtual_machine "$endpoint" "$port" "$name"
    handle_rdp "$endpoint" "$port" "$displayName" "$username" "$password" "$base_rdp_params"
}