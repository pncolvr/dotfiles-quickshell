#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
executable=${RBW_TEST_EXECUTABLE:-$(command -v rbw || true)}
if [[ -z $executable ]]; then printf 'SKIP: real rbw CLI check (not installed)\n'; exit 0; fi
export RBW_PROFILE=synthetic RUST_LOG=off
run() { timeout 5 "$executable" "$@"; }
[[ $(run --version) == rbw\ 1.15.* ]]
run list --help | rg -q -- --raw
run get --help | rg -q -- --raw
run config set email synthetic@example.test
run config set lock_timeout 900
run config set pinentry /synthetic/pinentry
run config show | jq -e '.lock_timeout == 900 and .pinentry == "/synthetic/pinentry"' >/dev/null
[[ -f $XDG_CONFIG_HOME/rbw-synthetic/config.json ]]
printf 'PASS: real rbw CLI/configuration in an isolated synthetic profile\n'
