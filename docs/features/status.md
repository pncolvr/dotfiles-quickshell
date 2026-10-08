# Work/personal status and timecard

Hover the work/personal icon to see the current mode and whether it is automatic
or manually set. Work and Personal totals follow the selected period.

**Today** opens with a compact daily summary and hides session details until
expanded. **This week** and **Last week** cover Monday–Sunday; **This month** and
**Last month** cover full calendar months. Each period shows daily work/personal
totals and a proportional color bar, including days without activity. Dates keep
chronological order. Week views show the full weekday; hover its name for the
`yyyy-MM-dd` date. Month views show only `yyyy-MM-dd`, while Today shows the
full weekday followed by the date.
Click a day with activity to expand its start/end times, category and duration.
An ongoing session ends with “now”; hover its time range for precise timestamps.
Long lists scroll vertically within a bounded panel using the shared scrollbar.

The tooltip opens on Today and refreshes the timecard immediately, every minute
while open, and after a mode reload. The refresh button reruns the status manager's
`--check` and `--source` commands, then reloads the timecard. In automatic mode,
this reevaluates the configured work processes and open files. A manual override
stays in place. Week and month reports are read when their tabs are selected.
The mode button after Reload switches Work/Personal and sets a manual override.
The Reset button after it clears the override and restores automatic detection.
Left-clicking the bar icon pins or unpins the tooltip; the icon uses the accent
color while pinned. Bar clicks do not change the mode.

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
