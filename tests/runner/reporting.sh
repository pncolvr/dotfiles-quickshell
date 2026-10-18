#!/usr/bin/env bash
# Exercise the real runner with synthetic suites, without launching the suite.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-runner-reporting.XXXXXXXX)
cleanup() {
    for output in "$fixture"/*.log; do
        [[ -f $output ]] || continue
        while IFS= read -r directory; do
            [[ $directory == /tmp/quickshell-tests.* && -d $directory ]] && rm -rf -- "$directory"
        done < <(sed -n 's/^Logs: \([^[:space:]]*\).*/\1/p' "$output" | tr -d '\r')
    done
    rm -rf -- "$fixture"
}
trap cleanup EXIT
mkdir -p "$fixture/tests/runner"
cp "$repo/tests/runner/results.awk" "$fixture/tests/runner/"
awk '/^run isolated / { exit } { print }' "$repo/tests/run.sh" > "$fixture/tests/run.sh"
cat >> "$fixture/tests/run.sh" <<'SUITES'
run isolated example/pass bash -c 'printf "PASS: first check\nPASS: second check\n"'
run isolated example/fail bash -c 'printf "PASS: before failure\nCASE FAIL: expected failure\n"; exit 7'
run isolated example/crash bash -c 'exit 9'
run isolated example/skip bash -c 'printf "SKIP: optional device unavailable\n"'
run isolated example/quiet true
run isolated example/tap bash -c 'printf "TAP version 13\nok 1 - TAP success\nnot ok 2 - TAP failure\nok 3 - TAP skip # SKIP unavailable\n1..3\n# tests 3\n# pass 1\n# fail 1\n# skipped 1\n"; exit 1'
run isolated example/qt bash -c 'printf "PASS   : QtCase::first()\nPASS   : QtCase::second()\nFAIL!  : QtCase::failure()\nSKIP   : QtCase::skip()\nTotals: 2 passed, 1 failed, 1 skipped\n"'
for duration in '0|0s' '59|59s' '60|1m 0s' '3599|59m 59s' '3600|1h 0m 0s' '3661|1h 1m 1s'; do
    [[ $(format_duration "${duration%%|*}") == "${duration#*|}" ]] || exit 2
done
SUITES
awk '
    { lines[NR] = $0 }
    /^if ! \$list; then/ { summary = NR }
    END { for (i = summary; i <= NR; i++) print lines[i] }
' "$repo/tests/run.sh" >> "$fixture/tests/run.sh"

result=0
QS_TEST_RUNNER_BUS=1 bash "$fixture/tests/run.sh" > "$fixture/plain.log" 2>&1 || result=$?
[[ $result == 1 ]]
[[ $(rg -c '^(PASS|FAIL|SKIP) isolated/' "$fixture/plain.log") == 7 ]]
! rg -q '^RUN|\x1b\[' "$fixture/plain.log"
rg -q 'Suites: 1 passed, 5 failed, 1 skipped, 7 total' "$fixture/plain.log"
rg -q 'Tests: 6 passed, 5 failed, 3 skipped, 14 total' "$fixture/plain.log"
rg -q '^Total time: ([0-9]+h )?([0-9]+m )?[0-9]+s$' "$fixture/plain.log"
for name in fail crash quiet tap qt; do
    rg -q "^  isolated/example/$name \(" "$fixture/plain.log"
done
for name in 'expected failure' 'status 9' 'no named test results' 'TAP failure' 'QtCase::failure'; do
    rg -q "$name" "$fixture/plain.log"
done
results=$(sed -n 's/^All test results: //p' "$fixture/plain.log")
[[ $(wc -l < "$results") == 15 ]]
rg -q $'^PASS\tisolated\texample/pass\tfirst check\t' "$results"
printf 'PASS: one completed line per suite, separate suite/test totals, named failures, skips and complete TSV results\n'
printf 'PASS: total runtime summary and readable second/minute/hour formatting\n'

QS_TEST_RUNNER_BUS=1 bash "$fixture/tests/run.sh" example/pass isolated/example/skip example/pass > "$fixture/selected.log" 2>&1
rg -q 'Suites: 1 passed, 0 failed, 1 skipped, 2 total' "$fixture/selected.log"
! rg -q '^FAIL ' "$fixture/selected.log"
catalog=$(bash "$repo/tests/run.sh" --list ui/module-pins isolated/audio/controls)
[[ $(printf '%s\n' "$catalog" | wc -l) == 2 ]]
[[ $catalog == *$'isolated\taudio/controls\t'* && $catalog == *$'isolated\tui/module-pins\t'* ]]
native_catalog=$(bash "$repo/tests/run.sh" --native --list native/qml/pulse)
[[ $native_catalog == $'native\tqml/pulse\t'* && $native_catalog != *$'\n'* ]]
result=0
bash "$repo/tests/run.sh" --list ui/module-pins no-such-suite > "$fixture/invalid.log" 2>&1 || result=$?
[[ $result == 2 ]]
rg -q 'Unknown or disabled suite: no-such-suite' "$fixture/invalid.log"
result=0
bash "$repo/tests/run.sh" ui/module-pins no-such-suite > "$fixture/invalid-run.log" 2>&1 || result=$?
[[ $result == 2 ]]
! rg -q '^Logs:|^(RUN|PASS|FAIL) ' "$fixture/invalid-run.log"
result=0
bash "$repo/tests/run.sh" --list native/qml/pulse > "$fixture/disabled.log" 2>&1 || result=$?
[[ $result == 2 ]]
printf 'PASS: exact suite lists, mode selection, duplicate suppression and invalid-name preflight\n'

printf -v command 'env -u NO_COLOR QS_TEST_RUNNER_BUS=1 TERM=xterm bash %q' "$fixture/tests/run.sh"
result=0
# The parent runner uses timeout's separate process group. Reading its terminal
# here would stop this fixture with SIGTTIN/SIGTTOU instead of exercising output.
timeout --kill-after=2 5 script --quiet --return --command "$command" /dev/null \
    < /dev/null > "$fixture/tty.log" 2>&1 || result=$?
[[ $result == 1 ]]
output=$(cat "$fixture/tty.log")
[[ $output == *$'\e[32mPASS\e[0m'* && $output == *$'\e[31mFAIL\e[0m'* ]]
[[ $output == *$'RUN  isolated/example/pass\r\e[2K'* ]]
printf 'PASS: terminal RUN is replaced in place with green PASS or red FAIL\n'

printf '\033[34m DEBUG\033[0m qml: PASS: decorated checkpoint\n' > "$fixture/decorated.log"
awk -v mode=isolated -v suite=decorated -v log_path=fixture -v exit_status=0 \
    -f "$repo/tests/runner/results.awk" "$fixture/decorated.log" > "$fixture/decorated.tsv"
rg -q $'^PASS\tisolated\tdecorated\tdecorated checkpoint\tfixture$' "$fixture/decorated.tsv"
awk -v mode=isolated -v suite=timeout -v log_path=fixture -v exit_status=124 -v limit=3 \
    -f "$repo/tests/runner/results.awk" /dev/null > "$fixture/timeout.tsv"
rg -q 'Suite execution timed out after 3 seconds' "$fixture/timeout.tsv"
printf 'PASS: ANSI log prefixes and timed-out suite execution have explicit named results\n'
