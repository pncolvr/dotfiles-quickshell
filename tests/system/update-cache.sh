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

checkupdates() {
    [[ $* == --nocolor ]] || return 1
    case $UPDATES_TEST_MODE in
        empty) return 0 ;;
        empty-exit-one|aur-only) return 2 ;;
        unexpected-exit) return 3 ;;
        query-failure) printf 'Query failed\n' >&2; return 1 ;;
        partial-failure) printf 'linux 1 -> 2\n'; return 1 ;;
        signal) kill -TERM "$UPDATES_TEST_SCRIPT_PID"; return 2 ;;
        malformed) printf 'linux 1 -> 2\nbroken row\n' ;;
        *) printf 'linux 1 -> 2\n' ;;
    esac
}
yay() {
    [[ $* == '-Qua --color never' ]] || return 2
    case $UPDATES_TEST_MODE in
        age|aur-only) printf 'visual-studio-code-bin 1.140.0-2 -> 1.141.0-1 [1d]\n' ;;
        invalid-age) printf 'example 1 -> 2 [1d] unexpected\n' ;;
        aur-failure) printf 'AUR failed\n' >&2; return 1 ;;
        aur-partial-failure) printf 'example 1 -> 2\n'; return 1 ;;
        empty-exit-one) return 1 ;;
    esac
    return 0
}
pacman() {
    [[ $* == "--dbpath $HOME/.cache/quickshell/updates.db -Si --color never "* ]] || return 1
    # Duplicate entries must retain the first repository (pacman's priority order).
    printf 'Repository : core\nName : linux\nArchitecture : x86_64_v3\n\nRepository : extra\nName : linux\nArchitecture : x86_64\n'
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
export -f checkupdates yay pacman qs mv

for mode in success age aur-only empty empty-exit-one unexpected-exit query-failure partial-failure aur-failure aur-partial-failure malformed invalid-age publish-failure signal; do
    printf '%s\n' "$UPDATES_TEST_PREVIOUS" > "$UPDATES_TEST_CACHE"
    : > "$test_dir/actions"
    status=0
    HOME="$test_dir/home" UPDATES_TEST_MODE="$mode" bash -c 'export UPDATES_TEST_SCRIPT_PID=$$; exec bash "$1"' \
        update-cache-test "$project_root/src/config/update-check.sh" 2> "$test_dir/error" || status=$?
    case $mode in
        success|age|aur-only)
            [[ $status == 0 ]]
            case $mode in
                success) [[ $(<"$UPDATES_TEST_CACHE") == 'core x86_64_v3 linux 1 2' ]] ;;
                age) [[ $(<"$UPDATES_TEST_CACHE") == $'aur x86_64 visual-studio-code-bin 1.140.0-2 1.141.0-1\ncore x86_64_v3 linux 1 2' ]] ;;
                aur-only) [[ $(<"$UPDATES_TEST_CACHE") == 'aur x86_64 visual-studio-code-bin 1.140.0-2 1.141.0-1' ]] ;;
            esac
            [[ $(<"$test_dir/actions") == $'rename\nipc call updates reload' ]]
            ;;
        empty*)
            [[ $status == 0 ]]
            [[ ! -s $UPDATES_TEST_CACHE ]]
            [[ $(<"$test_dir/actions") == $'rename\nipc call updates reload' ]]
            ;;
        signal)
            [[ $status == 143 && $(<"$UPDATES_TEST_CACHE") == "$UPDATES_TEST_PREVIOUS" ]]
            [[ ! -s $test_dir/actions ]]
            ;;
        *)
            [[ $status == 1 && -s $test_dir/error ]]
            [[ $(<"$UPDATES_TEST_CACHE") == "$UPDATES_TEST_PREVIOUS" ]]
            rg -q '^ipc call updates schedule$' "$test_dir/actions"
            ! rg -q 'updates reload' "$test_dir/actions"
            ;;
    esac
    [[ $(find "$test_dir/home/.cache/quickshell" -maxdepth 1 -type f | wc -l) -eq 2 ]]
done

# A simultaneous invocation leaves the active writer's files and snapshot intact.
printf '%s\n' "$UPDATES_TEST_PREVIOUS" > "$UPDATES_TEST_CACHE"
: > "$test_dir/actions"
exec 8>"$test_dir/home/.cache/quickshell/updates.lock"
flock -n 8
HOME="$test_dir/home" UPDATES_TEST_MODE=success bash "$project_root/src/config/update-check.sh"
[[ ! -s $test_dir/actions && $(<"$UPDATES_TEST_CACHE") == "$UPDATES_TEST_PREVIOUS" ]]
exec 8>&-

# Only old checker temporary files are removed, including after query failure.
cache_dir="$test_dir/home/.cache/quickshell"
touch "$cache_dir/updates.cache.ABC123" "$cache_dir/updates.err.ABC123" "$cache_dir/updates.cache.recent" "$cache_dir/updates.cache.backup-copy"
touch -d '2 hours ago' "$cache_dir/updates.cache.ABC123" "$cache_dir/updates.err.ABC123" "$cache_dir/updates.cache.backup-copy"
HOME="$test_dir/home" UPDATES_TEST_MODE=query-failure bash "$project_root/src/config/update-check.sh" 2> "$test_dir/error" && exit 1
[[ ! -e $cache_dir/updates.cache.ABC123 && ! -e $cache_dir/updates.err.ABC123 ]]
[[ -f $cache_dir/updates.cache.recent && -f $cache_dir/updates.cache.backup-copy ]]
printf 'PASS: repository/AUR snapshots, yay age suffixes, atomic publication, failures, signals, locking and stale-file cleanup\n'
