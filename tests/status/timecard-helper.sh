#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
executable=${TIMECARD_TEST_EXECUTABLE:-${ZDOTDIR:-$HOME/.config/zsh}/scripts/status/bin/timecard}
test_dir=$(mktemp -d /tmp/quickshell-timecard-helper.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
export TZ=Europe/Lisbon
# Fixed past dates exercise Monday/Sunday bounds, a month rollover, and the
# Lisbon daylight-saving transition on the last week's Sunday.
today=2020-10-28
yesterday=2020-10-27
today_start=$(date -d "$today 00:00:00" +%s)
yesterday_start=$(date -d "$yesterday 00:00:00" +%s)
source_file="$test_dir/time table.csv"
printf '%s;work\n%s;personal\n%s;inactive\n%s;active\n%s;work\n%s;personal\n%s;inactive\n' \
    "$yesterday_start" "$((yesterday_start+60))" "$((yesterday_start+120))" \
    "$today_start" "$today_start" "$((today_start+60))" "$((today_start+120))" > "$source_file"
for day in 2020-08-31 2020-09-01 2020-09-30 2020-10-18 2020-10-19 2020-10-25 2020-10-26 2020-11-01 2020-11-02; do
    day_start=$(date -d "$day 00:00:00" +%s)
    printf '%s;active\n%s;work\n%s;personal\n%s;inactive\n' \
        "$day_start" "$day_start" "$((day_start+60))" "$((day_start+120))" >> "$source_file"
done
before=$(sha256sum "$source_file")
read_report() {
    bash "$project_root/src/services/status/timecard.sh" --executable "$executable" --file "$source_file" --date "$today" "$@"
}
result=$(read_report)
jq -e --arg date "$today" '.date == $date and .error == "" and .weeksLoaded == false
    and .summary == "work     00:01:00\npersonal 00:01:00"
    and (.today | contains("blocks:") and contains("00:00:00 00:01:00 work"))
    and .currentWeek == "" and .lastWeek == "" and .monthsLoaded == false and .currentMonth == "" and .lastMonth == ""' <<< "$result" >/dev/null
result=$(read_report --weeks)
jq -e --arg today "$today" --arg yesterday "$yesterday" '.weeksLoaded == true
    and (.currentWeek | startswith("2020-10-26 – 2020-11-01\n\n")
        and contains($today) and contains($yesterday) and contains("2020-11-01\n")
        and (contains("2020-10-25\n") or contains("2020-11-02\n") | not))
    and (.lastWeek | startswith("2020-10-19 – 2020-10-25\n\n")
        and contains("2020-10-19\n") and contains("2020-10-25\n") and contains("blocks:")
        and (contains("2020-10-18\n") or contains("2020-10-26\n") or contains($today) | not))' <<< "$result" >/dev/null
# Monday starts a new week; Sunday stays in the preceding one.
result=$(read_report --date 2020-10-26 --weeks)
jq -e '.currentWeek | startswith("2020-10-26 – 2020-11-01\n\n")' <<< "$result" >/dev/null
result=$(read_report --date 2020-11-01 --weeks)
jq -e '.currentWeek | startswith("2020-10-26 – 2020-11-01\n\n")' <<< "$result" >/dev/null
[[ $(sha256sum "$source_file") == "$before" ]]

result=$(read_report --months)
jq -e '.monthsLoaded == true and .weeksLoaded == false
    and (.currentMonth | startswith("2020-10-01 – 2020-10-31\n\n")
        and contains("2020-10-18\n") and contains("2020-10-28\n")
        and (contains("2020-09-30\n") or contains("2020-11-01\n") | not))
    and (.lastMonth | startswith("2020-09-01 – 2020-09-30\n\n")
        and contains("2020-09-01\n") and contains("2020-09-30\n")
        and (contains("2020-08-31\n") or contains("2020-10-18\n") | not))' <<< "$result" >/dev/null
result=$(read_report --date 2020-03-01 --months)
jq -e '.lastMonth | startswith("2020-02-01 – 2020-02-29\n\n")' <<< "$result" >/dev/null
result=$(read_report --date 2021-03-01 --months)
jq -e '.lastMonth | startswith("2021-02-01 – 2021-02-28\n\n")' <<< "$result" >/dev/null
result=$(read_report --date 2021-01-15 --weeks --months)
jq -e '.weeksLoaded and .monthsLoaded and (.lastMonth | startswith("2020-12-01 – 2020-12-31\n\n"))' <<< "$result" >/dev/null
[[ $(sha256sum "$source_file") == "$before" ]]

# A no-records day must not call the existing crashing brief path.
result=$(read_report --date 2040-01-01 --weeks --months)
jq -e '.error == "" and .summary == "work     00:00:00\npersonal 00:00:00"
    and (.today | contains("No completed time blocks found."))
    and (.currentWeek | contains("No completed time blocks found."))
    and (.lastWeek | contains("No completed time blocks found."))
    and (.currentMonth | contains("No completed time blocks found."))
    and (.lastMonth | contains("No completed time blocks found."))' <<< "$result" >/dev/null
printf '%s;not-a-valid-event\n' "$today_start" > "$source_file"
status=0
result=$(read_report) || status=$?
[[ $status == 1 ]]
jq -e '.error | contains("Invalid event")' <<< "$result" >/dev/null
status=0
result=$(read_report --file "$test_dir/missing.csv") || status=$?
[[ $status == 1 ]]
jq -e '.error | contains("timetable")' <<< "$result" >/dev/null
status=0
result=$(read_report --executable "$test_dir/missing-executable") || status=$?
[[ $status == 1 ]]
jq -e '.error | contains("executable")' <<< "$result" >/dev/null
printf 'PASS: existing timecard reports, today/weeks/months, calendar boundaries, empty days, input errors and unchanged source\n'
