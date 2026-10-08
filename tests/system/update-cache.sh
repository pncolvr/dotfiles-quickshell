#!/usr/bin/env bash
# Mock package queries and verify the published file stays intact until rename.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-update-cache-test.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/home/.cache/quickshell"
export UPDATES_TEST_DIRECTORY="$test_dir"
export UPDATES_TEST_CACHE="$test_dir/home/.cache/quickshell/updates.cache"
export UPDATES_TEST_PREVIOUS='old cache remains available'

yay() {
    if [[ $1 == -Si ]]; then
        printf 'Repository : core\nName : linux\nArchitecture : x86_64\n'
        return
    fi
    [[ $1 == -Qu ]] || return 2
    case $UPDATES_TEST_MODE in
        empty) return 0 ;;
        empty-exit-one) return 1 ;;
        unexpected-exit) return 2 ;;
        query-failure) printf 'Query failed\n' >&2; return 1 ;;
        partial-failure) printf 'linux 1 -> 2\n'; return 1 ;;
        malformed) printf 'linux 1 -> 2\nbroken row\n' ;;
        *) printf 'linux 1 -> 2\n' ;;
    esac
}
qs() { printf '%s\n' "$*" >> "$UPDATES_TEST_DIRECTORY/actions"; }
mv() {
    # Both the populated and empty cases must preserve the old file up to publication.
    [[ $(cat "$UPDATES_TEST_CACHE") == "$UPDATES_TEST_PREVIOUS" ]] || {
        printf 'Cache was modified before atomic publication\n' >&2
        return 1
    }
    printf 'rename\n' >> "$UPDATES_TEST_DIRECTORY/actions"
    [[ $UPDATES_TEST_MODE != publish-failure ]] || return 1
    command mv "$@"
}
export -f yay qs mv

for mode in success empty empty-exit-one unexpected-exit query-failure partial-failure malformed publish-failure; do
    printf '%s\n' "$UPDATES_TEST_PREVIOUS" > "$UPDATES_TEST_CACHE"
    : > "$test_dir/actions"
    HOME="$test_dir/home" UPDATES_TEST_MODE="$mode" bash "$project_root/src/config/update-check.sh"
    case $mode in
        success)
            [[ $(<"$UPDATES_TEST_CACHE") == 'core x86_64 linux 1 2' ]]
            [[ $(<"$test_dir/actions") == $'rename\nipc call updates reload' ]]
            ;;
        empty*)
            [[ ! -s $UPDATES_TEST_CACHE ]]
            [[ $(<"$test_dir/actions") == $'rename\nipc call updates reload' ]]
            ;;
        *)
            [[ $(<"$UPDATES_TEST_CACHE") == "$UPDATES_TEST_PREVIOUS" ]]
            rg -q '^ipc call updates schedule$' "$test_dir/actions"
            ! rg -q 'updates reload' "$test_dir/actions"
            ;;
    esac
    [[ $(find "$test_dir/home/.cache/quickshell" -maxdepth 1 -type f | wc -l) -eq 1 ]]
done
printf 'PASS: atomic update-cache publication, empty results, query/malformed/publish failures and cleanup\n'
