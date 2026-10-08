#!/usr/bin/env bash

# Split configured flags with shell-style quoting, without expanding shell code.
# RDP_OPTIONS is local to rdp(), available here through Bash's dynamic scope.
function split_rdp_options () {
    local input=$1 character quote='' word='' escaped=false started=false i
    RDP_OPTIONS=()
    for ((i=0; i<${#input}; i++)); do
        character=${input:i:1}
        if $escaped; then
            word+=$character; escaped=false; started=true
        elif [[ $quote == "'" ]]; then
            if [[ $character == "'" ]]; then quote=''; else word+=$character; fi
        elif [[ $character == '\' ]]; then
            if [[ $quote == '"' && ${input:i+1:1} != [\$\`\"\\] ]]; then word+=$character
            else escaped=true; fi
            started=true
        elif [[ -n $quote ]]; then
            if [[ $character == "$quote" ]]; then quote=''; else word+=$character; fi
        elif [[ $character == '"' || $character == "'" ]]; then
            quote=$character; started=true
        elif [[ $character == [[:space:]] ]]; then
            if $started; then RDP_OPTIONS+=("$word"); word=''; started=false; fi
        else
            word+=$character; started=true
        fi
    done
    if $escaped || [[ -n $quote ]]; then
        printf 'Invalid quoting in RDP options.\n' >&2
        return 1
    fi
    if $started; then RDP_OPTIONS+=("$word"); fi
}

function rdp () {
    local host=$1
    local port=$2
    local domain=$3
    local user=$4
    local password=$5
    local title=$6
    local extraParams=$7
    local -a params=() RDP_OPTIONS=()
    [ -n "$title" ] && params+=("/t:$title")
    if [[ -n $host ]]; then
        [ -n "$port" ] && host+=":$port"
        params+=("/v:$host")
    fi
    if [[ -n $user ]]; then
        [ -n "$domain" ] && user+="@$domain"
        params+=("/u:$user")
    fi
    [ -n "$password" ] && params+=("/p:$password")
    split_rdp_options "$extraParams" || return 1
    sdl-freerdp3 "${params[@]}" "${RDP_OPTIONS[@]}"
}

function handle_rdp () {
    local endpoint=$1
    local port=$2
    local displayName=$3
    local username=$4
    local password=$5
    local rdpParams=$6
    local domain=${7:-}

    rdp "$endpoint" "$port" "$domain" "$username" "$password" "$displayName" "$rdpParams"
}

function handle_picked_option () {
    local picked=$1

    IFS=';' read type  \
        <<< "$(jq -r --arg name "$picked" '.hosts[] | select(.name==$name) | [ .type ] | join(";")' "$HOSTS_FILE")"

    source "$WORKSPACE/components/hosts/${type}.sh"
    handle_remote "$picked"
}
