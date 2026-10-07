# Countdowns and timers

Hover the stopwatch before the mic on the right side of the bar to open the panel;
click to keep it open.
In the Countdowns tab, start a countdown using any combination of hours, minutes
and seconds. Fields accept larger values too, so 90 minutes or 120 seconds work
directly. Names are
optional. Press Enter in a countdown field or click its plus button to add and
start it. In the Timers tab, enter an optional name and click its plus
button (or press Enter) to add an elapsed timer that counts up from zero.

Each entry has a pause/resume button, a reset button and a red trash button that
stops and deletes it. Reset stops the entry and returns a countdown to its original
duration, or an elapsed timer to zero, ready to start with the green play button.
Names and countdown durations stay intact. Paused entries retain their time and
do not appear on the bar. The bar shows the running countdown with the least time
remaining. If none is running, it shows
the first running elapsed timer. With no running entries, only the icon appears.

Countdown text in the panel and bar turns warning-colored at 30 seconds and
urgent at 10 seconds. At zero, the countdown plays the desktop's
`alarm-clock-elapsed` sound once through `canberra-gtk-play`, automatically resets
to its original duration, and waits in the panel for another start. Its warning
colors clear and the bar shows the next running entry. Press its green play button
to run the same countdown again. Each run sounds once. Elapsed timers do not sound
an alarm.

Closing the panel leaves entries running. Entries are saved in the existing
preferences database and restored after a shell restart or config reload. Paused
entries retain their time; running entries include time while Quickshell was
closed. A countdown that expired while it was closed sounds once on startup and
resets ready to start. Already reset entries restore silently. Previously finished
entries also restore reset without sounding again. Time comes from timestamps
rather than subtracting ticks, so countdowns account for delayed updates and suspend.

`src/config/Config.qml` contains `countdownWarningThreshold`,
`countdownUrgentThreshold` (milliseconds), `timerTickInterval`, and
`countdownSoundCommand`. `src/theme/Theme.qml` contains `timersIcon`,
`timersTooltipWidth`, and `timersMaxHeightRatio`, using the shared warning, urgent,
pause/play and delete styles. The icon is Font Awesome's free solid
[stopwatch](https://fontawesome.com/icons/stopwatch).

Run `bash tests/time/timers.sh` for offscreen timing, bar priority, controls,
scrolling, restart persistence and alarm checks. Sounds are mocked and runtime
data is isolated.
