#!/usr/bin/env bash
set -euo pipefail
control=$(<"$RBW_TEST_ROOT/control")
case $control in cancel) exit 1 ;; picker-fail) exit 2 ;; delay) sleep 2 ;; esac
[[ $1 == --json ]]
jq -e '.private == true and .showPrompt and (.allowTyped|not) and (.items | length > 0)
    and (tostring | contains(env.RBW_TEST_SECRET) | not)' "$2" >/dev/null
printf 'picker\n' >> "$RBW_TEST_ROOT/picker-calls"
jq -r '.items[0].result' "$2"
