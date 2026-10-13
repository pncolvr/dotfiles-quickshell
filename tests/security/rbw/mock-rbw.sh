#!/usr/bin/env bash
set -euo pipefail
control=$(<"$RBW_TEST_ROOT/control")
jq -nc '$ARGS.positional' --args -- "$@" >> "$RBW_TEST_ROOT/calls"
if [[ $control == fail ]]; then printf '%s' "$RBW_TEST_SECRET" >&2; exit 1; fi
case $1 in
    --version) printf 'rbw 1.15.0\n' ;;
    config) printf '{"email":"user@example.test","base_url":null}\n' ;;
    list) cat "$RBW_TEST_ROOT/entries.json" ;;
    get) cat "$RBW_TEST_ROOT/entry.json" ;;
    code) printf '123456\n' ;;
    *) exit 1 ;;
esac
