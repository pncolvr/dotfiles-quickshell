#!/usr/bin/env bash
# Read the same summary and timecard reports as the Conky/zsh commands.
set -euo pipefail
executable=''
events_file=''
report_date=$(date +%F)
include_weeks=false
fail() {
    jq -n --arg error "$1" '{summary: "", today: "", currentWeek: "", lastWeek: "", error: $error}'
    exit 1
}
while (($#)); do
    case "$1" in
        --executable|--file|--date)
            (($# >= 2)) || fail 'Missing timecard option value.'
            case "$1" in
                --executable) executable=$2 ;;
                --file) events_file=$2 ;;
                --date) report_date=$2 ;;
            esac
            shift 2 ;;
        --weeks) include_weeks=true; shift ;;
        *) fail 'Unknown timecard option.' ;;
    esac
done
[[ -x $executable ]] || fail 'The configured timecard executable is unavailable.'
[[ -f $events_file && -r $events_file ]] || fail 'The configured timetable file is unavailable.'
umask 077
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
# One snapshot keeps the reports consistent if the status manager appends an event.
cp -- "$events_file" "$work_dir/events.csv"
if ! "$executable" -f "$work_dir/events.csv" -d "$report_date" > "$work_dir/today" 2> "$work_dir/error"; then
    fail "$(cat "$work_dir/error")"
fi
if [[ $(cat "$work_dir/today") == 'No completed time blocks found.' ]]; then
    # The existing -b implementation throws when a day has no blocks.
    printf 'work     00:00:00\npersonal 00:00:00' > "$work_dir/summary"
elif ! "$executable" -f "$work_dir/events.csv" -d "$report_date" -b > "$work_dir/summary" 2> "$work_dir/error"; then
    fail "$(cat "$work_dir/error")"
fi
: > "$work_dir/current-week"
: > "$work_dir/last-week"
if $include_weeks; then
    weekday=$(date -d "$report_date" +%u) || fail 'Invalid timecard date.'
    current_start=$(date -d "$report_date -$((weekday - 1)) days" +%F)
    last_start=$(date -d "$current_start -7 days" +%F)
    current_end=$(date -d "$current_start +6 days" +%F)
    last_end=$(date -d "$last_start +6 days" +%F)
    # Keep the native report's midnight splitting and offline accounting, then
    # select complete daily sections using local Monday–Sunday calendar dates.
    if ! "$executable" -f "$work_dir/events.csv" > "$work_dir/report" 2> "$work_dir/error"; then
        fail "$(cat "$work_dir/error")"
    fi
    week_report() {
        printf '%s – %s\n\n' "$1" "$2"
        awk -v start="$1" -v end="$2" '
            /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ {
                selected = ($0 >= start && $0 <= end)
                if (selected) found = 1
            }
            selected { print }
            END { if (!found) print "No completed time blocks found." }
        ' "$work_dir/report"
    }
    week_report "$current_start" "$current_end" > "$work_dir/current-week"
    week_report "$last_start" "$last_end" > "$work_dir/last-week"
fi
jq -n --arg date "$report_date" --argjson weeksLoaded "$include_weeks" \
    --rawfile summary "$work_dir/summary" --rawfile today "$work_dir/today" \
    --rawfile currentWeek "$work_dir/current-week" --rawfile lastWeek "$work_dir/last-week" \
    '{date: $date, summary: $summary, today: $today, currentWeek: $currentWeek, lastWeek: $lastWeek, weeksLoaded: $weeksLoaded, error: ""}'
