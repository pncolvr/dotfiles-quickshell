#!/usr/bin/env bash
function connect_ssh () {
    local host=$1
    local port=$2
    local remotePort=$3
    local hopHost=$4
    local hopUsername=$5
    local hopSSHKey=$6

    ssh -N -L $LOCALHOST_SSH:$port:$host:$remotePort -i $hopSSHKey $hopUsername@$hopHost & disown
    echo "$!"
}

function dns () {
    local endpoint=$1
    local new_endpoint=$(nslookup "$endpoint" | grep Address: | tail -n 1 | awk -F ':' '{print $2}' | xargs)

    if [ -n "$new_endpoint" ]; then
        echo "$new_endpoint"
    else
        echo "$endpoint"
    fi
}

function get_random_port () {
    local port
    while true; do
        port=$((RANDOM % 16384 + 49152))  # Random port between 49152-65535
        if ! ss -tuln 2>/dev/null | grep -q ":$port "; then
            echo $port
            return 0
        fi
    done
}

function handle_remote() {
    local picked=$1
    local endpoint
    local username
    local password
    local domain
    local rdpParams
    local hopHost
    local hopUsername
    local displayName
    local hopSSHKey
    local port=$(get_random_port)

    IFS=';' read endpoint username password domain rdpParams hopHost hopUsername displayName remotePort hopSSHKey\
        <<< "$(jq -r --arg name "$picked" '.hosts[] | select(.name==$name) | [.endpoint, .username , .password, .domain, .rdpParams, .hopHost, .hopUsername, .displayName, .port, .sshKeyPath] | join(";")' "$HOSTS_FILE")"
    base_rdp_params=$(jq -r '.baseRDPParams' "$HOSTS_FILE")
    endpoint=$(dns "$endpoint")
    local ssh_pid=$(connect_ssh "$endpoint" "$port" "$remotePort" "$hopHost" "$hopUsername" "$hopSSHKey")
    handle_rdp "$LOCALHOST_SSH" "$port" "$displayName" "$username" "$password" "$rdpParams $base_rdp_params" "$domain"
    kill "$ssh_pid"
}