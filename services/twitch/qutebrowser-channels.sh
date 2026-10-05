#!/usr/bin/env bash
# Read Twitch channels from current tab entries in a qutebrowser session.
set -euo pipefail

session_file=""
# Manual :session-save updates default.yml separately from _autosave.yml.
# Read one complete snapshot, choosing the newest readable candidate.
for candidate in "$@"; do
    if [[ -f $candidate && -r $candidate && ( -z $session_file || $candidate -nt $session_file ) ]]; then
        session_file=$candidate
    fi
done
if [[ ! -r $session_file ]] || ! command -v yq >/dev/null 2>&1; then
    printf '[]\n'
    exit 0
fi

# A tab's active history entry is its current page, even in a background tab.
# Capture only channel pages, excluding Twitch's own top-level routes.
if channels=$(yq -c --argjson reserved '[
    "activate", "bits", "dashboard", "directory", "downloads", "drops",
    "friends", "inventory", "jobs", "login", "logout", "messages", "moderator",
    "p", "payments", "popout", "products", "search", "settings", "signup",
    "store", "subscriptions", "team", "teams", "turbo", "videos", "wallet"
]' '
    [select(type == "object") | .windows | select(type == "array") | .[]
        | select(type == "object") | .tabs | select(type == "array") | .[]
        | select(type == "object") | .history | select(type == "array") | .[]
        | select(type == "object" and .active == true)
        | .url | select(type == "string")
        | capture("^https?://(?:(?:www|m)\\.)?twitch\\.tv/(?<login>[a-z0-9_]{1,25})(?:/(?:about|schedule|videos|clips))?/?(?:[?#].*)?$"; "i")
        | .login | ascii_downcase
        | select(. as $login | $reserved | index($login) | not)
    ] | unique
' "$session_file" 2>/dev/null); then
    printf '%s\n' "${channels:-[]}"
else
    # Missing, malformed or partially written sessions have no suggestions.
    printf '[]\n'
fi
