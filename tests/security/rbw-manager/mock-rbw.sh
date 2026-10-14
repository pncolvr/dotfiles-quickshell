#!/usr/bin/env bash
set -euo pipefail
jq -nc '$ARGS.positional' --args -- "$@" >> "$RBW_TEST_ROOT/calls"
if [[ -f $RBW_TEST_ROOT/fail && $1 != --version ]]; then printf 'SYNTHETIC_SECRET_DO_NOT_LOG\n' >&2; exit 1; fi
case $1 in
    --version) printf 'rbw 1.15.0\n' ;;
    config) printf '{"email":"user@example.test","base_url":null}\n' ;;
    unlocked) [[ ! -f $RBW_TEST_ROOT/slow-poll ]] || sleep 0.6; [[ ! -f $RBW_TEST_ROOT/locked ]] ;;
    lock) touch "$RBW_TEST_ROOT/locked" ;;
    list) [[ ! -f $RBW_TEST_ROOT/slow ]] || sleep 0.6; cat "$RBW_TEST_ROOT/entries.json" ;;
    get)
        [[ ! -f $RBW_TEST_ROOT/slow ]] || sleep 0.6
        if [[ $3 == 22222222-2222-2222-2222-222222222222 && -f $RBW_TEST_ROOT/note.json ]]; then
            cat "$RBW_TEST_ROOT/note.json"
        elif [[ $3 == 33333333-3333-3333-3333-333333333333 && -f $RBW_TEST_ROOT/second-login.json ]]; then
            cat "$RBW_TEST_ROOT/second-login.json"
        else
            cat "$RBW_TEST_ROOT/entry.json"
        fi
        if [[ -f $RBW_TEST_ROOT/protect-on-get ]]; then
            jq '.entries[0].master_password_reprompt = 1' "$XDG_CACHE_HOME/rbw/default:user@example.test.json" > "$RBW_TEST_ROOT/cache-next"
            mv "$RBW_TEST_ROOT/cache-next" "$XDG_CACHE_HOME/rbw/default:user@example.test.json"
        fi
        ;;
    add|edit) cat > "$RBW_TEST_ROOT/write-input" ;;
    remove|sync) : ;;
    generate) printf 'SYNTHETIC_GENERATED_PASSWORD\n' ;;
    *) exit 1 ;;
esac
