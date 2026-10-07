
#!/usr/bin/env bash

function rdp () {
    local host=$1
    local port=$2
    local domain=$3
    local user=$4
    local password=$5
    local title=$6
    local extraParams=$7
    local params=""
    [ -n "$title" ] && params="$params /t:\"$title\""
    [ -n "$host" ] && params="$params /v:\"$host\""
    [ -n "$port" ] && params="$params:\"$port\""
    [ -n "$user" ] && params="$params /u:\"$user\""
    [ -n "$domain" ] && params="$params@\"$domain\""
    # TODO: handle this safely
    [ -n "$password" ] && params="$params /p:\"$password\""
    [ -n "$extraParams" ] && params="$params $extraParams"

    # couldnt figure out why sdl-freerdp3 was complaining about params but with eval it doesnt
    eval "sdl-freerdp3 $params"
    echo "$!"
}

function handle_rdp () {
    local endpoint=$1
    local port=$2
    local displayName=$3
    local username=$4
    local password=$5
    local rdpParams=$6
    local domain=$7

    rdp "$endpoint" "$port" "$domain" "$username" "$password" "$displayName" "$rdpParams"
}

function handle_picked_option () {
    local picked=$1

    IFS=';' read type  \
        <<< "$(jq -r --arg name "$picked" '.hosts[] | select(.name==$name) | [ .type ] | join(";")' "$HOSTS_FILE")"

    source "$WORKSPACE/components/hosts/${type}.sh"
    handle_remote "$picked"
}