# Work/personal status and time tracking

`Config.workModeEnabled` enables automatic work/personal detection and native
SQLite time tracking. No external status manager or timecard executable is needed.
Hover the bar icon for reports; left-click pins or unpins the panel without
changing mode. Work and Personal buttons select a persistent manual override;
Reset restores automatic detection. A change between Work and Personal shows a
small bar alert for three seconds, for manual and automatic transitions. Restoring
the saved mode on startup/reload and selecting the current mode stay quiet.

Today shows totals and expandable sessions. Week views cover Monday–Sunday and
month views cover complete calendar months, including days without activity.
Intervals split at local midnight and use elapsed time across daylight-saving
changes. The current session ends with “now”. Long reports scroll within the
panel. Automatic detection evidence appears on Today, separately from history.

Manage retains its original panel width and two stacked text areas for work
folders and process patterns, each with one entry per line. Cancel and Apply sit
immediately to the right of the folder-picker button and are enabled only while
there are unsaved changes (and no folder dialog is open). Apply saves both lists;
Cancel restores the saved values.
The folder button appends the chosen folder to the list; existing entries remain.
Duplicate folders are ignored. Remove a folder by deleting its line. Patterns match full process names with `pgrep` regular
expressions. Processes whose working directory or open files are inside any configured
work folder also count as work. Open files are inspected once per scan, regardless
of the number of folders. Rules and the manual override are private database
preferences covered by encrypted backups. Refresh reevaluates detection; a
failed or partial scan retains the previous successful evidence and shows an
error. A manual override remains in effect until Reset.

Tracking pauses while the screen is locked, the desktop session is inactive,
the machine is suspended, or work mode is disabled. Unknown session state also
pauses tracking. The session monitor uses logind signals and checks logind and
Hyprland lock state every five seconds as a fallback. Native power actions pause
immediately before requesting lock, logout or shutdown.

Sessions are checkpointed every ten seconds and on mode/lifecycle changes.
Restart starts a new session without filling the gap when the bar was absent.
An abrupt process termination can lose the last ten seconds; a delayed heartbeat
never counts a long sleep or stopped process as activity. Tracking therefore
requires the bar to be running. History is retained for a rolling twelve calendar
months: startup and hourly maintenance delete expired sessions and trim any
session crossing the cutoff. History and detection rules use the existing
SQLite backup/restore flow.

When work mode is disabled:

- The Status icon, category selectors and status-filter shortcuts/hints are hidden.
- Projects, Directories, Webapps, Remotes and n8n show every category.
- Project apps launch without their `profileArguments`, using their default profile.
- Explicit saved Webapps/n8n browser profiles remain unchanged.
- Wallpaper selection skips the mode step and uses the saved Personal wallpaper.
- Detection and session monitoring stop. Existing categories, rules and retained
  history remain saved; enabling work mode starts a new interval.

`statusTooltipWidth` and `statusTooltipMaxHeightRatio` in Theme control the panel
size. Detection needs `pgrep`, `readlink`, `jq` and `lsof`; session monitoring needs
`gdbus`, `busctl` and `hyprctl`. The compositor's lock state and logind's session
properties are read only.

[Development checks](../development.md#status-and-timecard)
