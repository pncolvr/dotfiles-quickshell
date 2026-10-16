# Clock, calendar and holidays

## Clock and calendar

The clock keeps its existing text color, format, width and controls. Hover opens
the monthly calendar; right-click switches between month and year views, and
left-click pins/unpins the panel and middle-click toggles seconds. The seconds preference persists in SQLite. Scrolling
changes the displayed month or year. The annual grid reuses twelve monthly views.

All dates open the Google Calendar event editor using `Config.calendarEventUrl`.
Ordinary dates and holiday-only dates start a blank all-day draft on the clicked
date, with no preset title or description. A clock-change date or its preceding
day opens the clock-change draft described below.

The implementation lives in:

- `src/services/time/CalendarService.qml`: holidays, transitions, day states,
  tooltip descriptions and calendar links.
- `src/services/time/TimeService.qml`: existing system clock and seconds preference.
- `src/modules/clock/Clock.qml`: bar controls and the shared previous-day notice.
- `src/modules/clock/MonthTooltip.qml`: month navigation and date cells.
- `src/modules/clock/YearTooltip.qml`: annual grid.

## Holidays

Portuguese national holidays, optional Carnaval and Easter-relative dates are
computed and cached per year. Municipal holidays come from
`calendarMunicipalHolidays` in `src/config/Config.qml`. The default is
`{month: 5, day: 22, name: "Dia de Leiria"}`. Configuration uses month numbers
1–12; an empty list disables municipal holidays. Invalid names and dates are
skipped. Coinciding holidays retain all distinct names in the hover tooltip.

## Previous-day clock-change warning

The **day before the change** has a warning-color background using the existing cell
shape, size and text colors. The bar color stays unchanged. The transition date
has no additional warning highlight or border.

Hovering the preceding date explains the direction and old/new times.
Only an indication for today's date says “tomorrow”. Transition-day hover text
also shows the change details. Clock-change tooltips omit the date line.

A small, single-line legend below the calendar labels only what occurs in the
displayed month or year: Today when the period contains today, Holiday when it
contains holidays, and the warning-colored Change eve when it contains a
clock-change eve. When no labels apply, the entire legend hides. The annual
view follows the same rules with one shared legend rather than one per month.

For mainland Portugal, examples are:

- “Clocks go forward tomorrow: 01:00 → 02:00”
- “Clocks go back tomorrow: 02:00 → 01:00”

Tooltips omit the timezone and use the same Font Awesome `Theme.rightIcon` as
updates, rendered with `Theme.fontFamilyIcons`. Upcoming changes say “tomorrow”
without repeating the date. Other dates show only the direction and times.
On the preceding day, the clock tooltip also shows one shared notice above the
month or year view. It disappears when the transition date begins. For the
25 October 2026 change, the warning is on 24 October and describes the upcoming
night's change.

`DayStyle` provides `Invalid`, `Regular`, `Weekend`, `Holiday`, `ClockChangeEve`
and `Today` states. A service resolver applies priority in this order: invalid,
clock-change eve, today, holiday, weekend, regular. Theme helpers map states to
colors. The warning takes priority over both today's accent and a holiday
background; ordinary dates retain today's highlight. Independent date metadata preserves all holiday and
clock-change descriptions even when only one background can be displayed.
`Direction` provides `Forward` and `Backward`; the clock keeps its existing
month/year view enum.

## Time-zone calculations and caching

Clock-change calculations use only `Europe/Lisbon`, matching the clock's local
region in this setup. There is no timezone setting. The clock and today's
calendar highlight continue to use the system's local date.

The service calculates transitions directly in QML for each displayed year,
including years reached by month scrolling or the annual view. No shell helper,
external process or request queue is needed. Each lookup calculates only the
requested year: Portuguese seasonal clock changes
and their preceding dates do not cross a year boundary. If support is extended
to regions with changes around New Year, add adjacent-year calculations and
filter by the civil transition date or preceding date, with dedicated tests.

Current EU rules use the last Sunday of March and October at 01:00 UTC. With
Sunday numbered zero, subtracting the weekday of the 31st from 31 gives the last
Sunday. `CalendarService` uses this rule for years from 2002 onward. UTC arithmetic
keeps the result independent of the machine's current offset. Lisbon uses
offsets of 0/3600 seconds.
The previous date is derived with calendar arithmetic. Years before 2002 return
no transitions: historical exceptions are outside the supported scope. Future
years assume the current rule continues; update the implementation if legislation
changes. Supporting historical rules or other regions would require additional
rules or a time-zone database lookup.
See [Directive 2000/84/EC](https://eur-lex.europa.eu/eli/dir/2000/84/oj/eng) and the
[2027–2031 schedule](https://eur-lex.europa.eu/eli/C/2026/1660/oj/eng).

Results are cached by year, following the holiday cache's on-demand pattern.

Like holidays, transitions are loaded on the first date lookup for a year and
reused for subsequent dates in that year. There is no separate startup preload
or separate refresh job. The current-day notice requests
its year through the same lookup path as calendar cells. Existing system-clock
updates change a civil date key; the notice follows that key across midnight,
resume and year rollover. Transitions are not recalculated on each tick.
Browsing another year changes
its calendar cells and hover details without changing the current-day notice.
There are no systemd timers, scheduled local notifications, polling jobs,
reminder IPC endpoints or reminder database entries.

## Prefilled Google Calendar event

Clicking either the clock-change date or its preceding date opens the same event
draft on the **previous day**, initially 18:00–18:15 in Europe/Lisbon.
The title describes the direction; the description contains the direction and
old/new times, without a transition date. The event's timezone is supplied separately
in its link. Browsing past or future years
uses that year's transition, rather than the current year's dates.

Configuration lives in `src/config/Config.qml`:

- `calendarEventUrl`: Google Calendar's event-template URL, including
  `action=TEMPLATE`.
- `calendarClockChangeEventHour` and `calendarClockChangeEventMinute`: local
  start time on the preceding day.
- `calendarClockChangeEventDurationMinutes`: event length.

The link encodes its title and details and supplies UTC start/end timestamps
and Europe/Lisbon. For Lisbon's 25 October 2026 change, the event starts
on 24 October at 18:00 local time (17:00 UTC), using the preceding day's offset.
Ordinary dates and holiday-only dates use the same template endpoint with an
all-day date range (the clicked day through the exclusive following day), and
no clock-change text. Their hover hint is “Create event” unless holiday names
already provide the date's description.

Opening the editor creates no saved event or local schedule. Review the event
and its notification settings, then save it in Google Calendar. The template
link does not force a reminder time. Google Calendar's
[reminder settings](https://developers.google.com/workspace/calendar/api/concepts/reminders)
control delivery after saving. Repeated clicks open separate drafts; the shell
does not inspect saved events or prevent duplicates.

URL construction is tested locally. An authenticated Google Calendar editor
still needs a manual check of the displayed draft and notification preferences.

## Verification

Run `bash tests/time/calendar.sh`. The Bash runner starts an isolated offscreen
QML check covering synchronous year calculations, cache reuse, the historical
scope limit, future dates,
previous-day-only warnings, direction and offsets, overlapping holiday metadata,
style priority, rendered warning color including when today, unchanged cell/grid
sizes, forward/backward year navigation in both views with rendered warning
dates and tooltip descriptions without dates, and right-clicking the clock then
scrolling its actual annual tooltip to 2027,
live date-boundary and resume updates, unchanged bar color, and previous-day
event URLs for spring and autumn. Tests create no Python scripts
and use isolated application data rather than live preferences.
