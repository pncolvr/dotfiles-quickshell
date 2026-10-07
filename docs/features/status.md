# Work/personal status and timecard

Hover the work/personal icon to see the current mode, whether it was detected or
manually set, and today's work/personal totals. The summary uses the same brief
report as the previous Conky display.

The **Today** tab shows the detailed report used by the zsh `timecard` function:
start, end, category, duration, and ongoing blocks. **Current week** and **Last week**
show each day's totals and blocks within their Monday–Sunday ranges, displayed
at the top of each report. Reports keep their original
monospace columns, with scrolling for long or wide tables. The summary above
the tabs always refers to today.

The tooltip opens on Today and refreshes immediately, then every minute while
open, and after a mode reload. Use the refresh button to update it manually.
Weekly reports are read when either week tab is selected. Left-clicking the bar icon still
toggles the manual mode; right-clicking clears the override and restores
automatic detection.

## Commands and configuration

The integration calls the existing native `timecard` executable directly; it
does not launch Conky or an interactive zsh session. Its Bash helper only reads
a snapshot of the timetable. Durations and blocks come from the existing
timecard implementation, including its treatment of offline periods. A day
without records shows zero work/personal totals and the normal empty report,
avoiding the existing brief command's no-records exception.

In `src/config/Config.qml`:

- `_internal.statusManager`: the existing mode manager at
  `~/.config/zsh/scripts/status/manager.sh`.
- `statusTimecardExecutable`: `$ZDOTDIR/scripts/status/bin/timecard`, falling back
  to `~/.config/zsh/scripts/status/bin/timecard`.
- `statusTimetableFile`: exported `$TIMETABLE_FILE`, falling back to
  `~/Documents/timetable.csv`, matching the current zsh/Conky setup.
- `statusTimecardRefreshInterval`: one minute by default.
- `statusTimecardCommand`: the report helper's arguments, including today's date.

`statusTooltipWidth` and `statusTooltipMaxHeightRatio` in `Theme.qml` control the
panel dimensions. Missing commands, missing logs, and malformed events appear
as errors in the tooltip. The status manager continues to own mode changes and
event logging.

[Development checks](../development.md#status-and-timecard)
