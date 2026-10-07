#!/usr/bin/env bash
WORKSPACE=$(echo "${BASH_SOURCE[0]:-0}" | xargs realpath | xargs dirname)

source "$(echo "$WORKSPACE" | xargs dirname)"/_common/utils.sh

HOSTS_FILE="$WORKSPACE/hosts.json"
LOCALHOST_SSH=localhost

options=$(jq -r '.hosts | map(select(.enabled == true)) | map(.name) | join("|")' "$HOSTS_FILE")
chosen=$(echo -n "$options|kill|shutdown vm" | bash "$PICKER_LAUNCHER" --dmenu -sep '|' -dmenu -case-smart -p "")
[ -z "$chosen" ] && exit

component="$WORKSPACE/components/options"
if echo "$options" | grep "$chosen" > /dev/null 2>&1; then
    component+="/host.sh"
else
    component+="/other.sh"
fi

source "$component"
handle_picked_option "$chosen"
