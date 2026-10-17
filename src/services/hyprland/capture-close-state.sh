#!/usr/bin/env bash
# Read-only compositor state; one bounded request never alters animation settings.
set -euo pipefail
timeout 1 hyprctl -j --batch 'animations; getoption animations:enabled; monitors' \
    | jq -sc 'if length == 3 then {animations:.[0],enabled:.[1],monitors:.[2]} else error("Incomplete capture close state") end'
