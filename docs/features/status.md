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
Below Today's collapsible sessions, **Automatic detection** shows compact process
rows with their rule labels and distinct path counts. Click a row or press
Enter/Space while it is focused to reveal paths; one process expands at a time.
Paths abbreviate the home directory and elide long names; hover shows their full
values. Refresh preserves expansion for a process that remains present.
The evidence describes the current scan, not historical sessions. A refreshing
indicator retains the previous rows. Failed refreshes explicitly label retained
rows as the previous successful scan, and partial errors remain visible. Manual
override is labeled separately; automatic matches do not set the selected mode.
The report groups methods and paths independently, so rule labels describe the
process as a whole rather than attributing an individual path to a specific rule.

The tooltip opens on Today and refreshes the timecard immediately, every minute
while open, and after a mode reload. The refresh button reruns the status manager's
`--check` and `--source` commands, then reloads the timecard. In automatic mode,
this reevaluates the configured work processes and open files. A manual override
stays in place. Week and month reports are read when their tabs are selected.
Separate Work and Personal buttons after Reload set that exact mode as a manual
override, including when automatic detection already reports the same mode.
The selected manual mode is highlighted in the accent color. Mode controls are
disabled while a change is running. The Reset button after them clears the
override and restores automatic detection.
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
event logging. Work/personal changes restore the saved monitor wallpapers through
`launcher.sh provider wallpaper restore MODE`; system events such as active and
inactive only log their event and do not request a mode wallpaper.
The manager's read-only `--explain` command supplies the detection report as JSON.
The panel reads it on opening, mode refresh and each minute while visible, and
stops the scan when closed. This command does not change mode, wallpaper or the
timetable. The report requires `jq` and uses the manager's existing process and
work-directory configuration.

[Development checks](../development.md#status-and-timecard)
