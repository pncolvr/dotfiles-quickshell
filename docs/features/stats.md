# Stats

Hover the Stats icon to open its panel. Left-click pins or unpins the panel;
the icon keeps the same width while hovering. Select **Power saver**, **Balanced**
or **Performance** directly from the profile buttons. The active profile is
highlighted; Performance is disabled when the system does not support it.

The panel uses the shared tabs, search field, buttons and scrollbar. Its height
is limited to 60% of the screen, with longer content scrolling inside it.

- **Overview:** CPU, memory and temperature totals, download/upload rates,
  connected networks and VPNs.
- **CPU:** total and per-core usage, temperature, and processes ordered by current
  CPU usage. Process usage treats one fully occupied logical core as 100%, so a
  process can exceed 100%; the machine total is normalized across all cores.
- **Memory:** used/total RAM, free, available and cached memory, swap, and processes
  ordered by resident memory (RSS).
- **Network:** traffic history, download/upload rates, connections and VPNs, and
  processes ordered by combined download and upload rate.

Each resource tab groups processes by application parent and name, adding their
usage before sorting. For example, qutebrowser includes its WebEngine children,
and Discord includes its renderers and utilities. Separate instances with the
same app name share one total. The number beside an app is its contributing
process count, shown as a muted badge. The compact table aligns application names,
PID buttons and resource values; Network has separate Download and Upload columns.
App totals are bold, with a subtle background on hover. Memory totals sum RSS,
including shared resident pages.

Click an app name or its chevron to expand its individual processes, ordered by
their usage. Quieter, indented rows sit beside a faint vertical guide and show each
process’s usage and PID copy button. Known Chromium/WebEngine roles appear as
Main process, Renderer, GPU process, Network service, Audio service or Zygote;
other helpers retain their process name. Hover a child name to see its original
process name and PID. The app
row keeps the combined total. Expanded groups stay open through refreshes and
filtering, with separate expansion states for each resource tab.

App and subprocess order stays fixed while a group is expanded, the pointer is
over the process list, or a PID button has focus. Usage values continue updating.
Sorting resumes after groups are collapsed and pointer/focus leave the list;
new entries appear at the end while order is held.

Type an app, child process name or detected role to filter without regard to case. The filter
stays above the process list, and filtering keeps the panel height stable.
Refreshes preserve input focus, the filter and scroll position. Long resource
summaries and process lists each scroll within the panel's height limit.

The muted PID button copies the app parent's plain PID to the clipboard. When
several instances share a name, it copies the lowest parent PID. Network traffic
with no identifiable owner displays a disabled button instead.

CPU and memory processes refresh every second. Network processes refresh every
three seconds. Process collection runs only for the selected resource tab and
stops when the panel closes; Overview does not collect process lists.

## Data sources

Quickshell `FileView` reads CPU, memory, temperature and network counters directly.
Its native Networking and PowerProfiles interfaces supply network devices and
power controls. Connectivity checks and VPN discovery retain their existing
`ping` and `nmcli` helpers.

The Bash process helper reads `/proc` and emits JSON through `jq`. **Bandwhich is
still used** for network process traffic, only while the Network tab is open.
The helper resolves PIDs from connection sockets and file descriptors. Missing
bandwhich or capture failures appear in the panel; CPU and Memory remain usable.

`Config.statsInterval` controls the main polling interval;
`Config.networkProcessesInterval` controls network process polling.
`Config.statsTemperaturePath` selects the temperature sensor.

[Documentation](../README.md)
