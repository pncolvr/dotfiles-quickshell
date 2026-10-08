#!/usr/bin/env bash

WORKSPACE=$(echo "${BASH_SOURCE[0]:-0}" | xargs realpath | xargs dirname | xargs dirname)/_common
source "$WORKSPACE"/utils.sh

links=$(realpath -- "${BASH_SOURCE[0]%.*}.json")
selection=$("$WORKSPACE"/handle.sh "$links" )

IFS=';' read action url execute_before execute_after <<< "$(jq -r '[.action, .url, .executeBefore, .executeAfter] | join(";")' <<< $selection)"

if [[ -z "$action" || -z "$url" ]]; then
    exit
fi

if [[ -n "$execute_before" ]]; then
    echo "executing $execute_before"
    eval "$execute_before"
fi

case "$action" in
    "qutebrowser-webapp")
        url="$action $url"
        ;;
esac

if [[ -n "$execute_after" ]]; then
    echo "executing $execute_after"
    eval "$execute_after"
fi

$ZDOTDIR/scripts/default-browser/default-browser.sh $(printf '%s' "$url")