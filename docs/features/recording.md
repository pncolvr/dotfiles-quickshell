# Screen recording

Meta+R in the companion Hypr config dispatches `quickshell:recording-toggle`
through the shared native shortcut registry to `RecordingService.toggle()`.
`launcher.sh provider recording` remains available for shell callers and uses
`RecordingService` to control one detached recording worker. RecordingSetup gathers
Capture → Output/Region → Framerate → Audio → Devices through the shared native
picker. Config.recordingDirectory supplies the destination directly; no provider
script, temporary device-menu JSON or picker/Config IPC round trip is involved.
Native services read monitor/PulseAudio metadata, and region selection waits for
shared presentation readiness. The slurp input pipe is explicitly closed so it
receives EOF before mapping. Stopping does not load provider configuration.

The shortcut behaves according to the current phase:

| Phase | Shortcut |
| --- | --- |
| Idle | Open setup |
| Choosing options | Keep the current picker; Escape cancels |
| Starting, before capture | Cancel the pending recording |
| Recording | Send one SIGINT to the owned recorder and show “recording finishing” |
| Finishing or saving | Keep waiting; repeated presses do not restart or interrupt finalization |

Reloading the bar or Config/theme while still choosing options cancels unfinished
setup. Escape or another launcher also cancels it. Once prepared options have been
handed to the detached worker, starting, capture and saving survive reloads.
`Config.recordingEncoderArguments` supplies codec/quality arguments, defaulting to
the existing HEVC/NVENC settings. Framerate stays in the setup menu.
`RecordingOptions.mjs` preserves the filename format,
framerate defaults, default-first audio identities and off-profile filtering.
The worker still claims its runtime row atomically and receives prepared literal
arguments; it never reopens a picker. The old providers/recording.sh is removed;
`launcher.sh provider recording` remains a direct native compatibility entry.

Starting and stopped alerts expire after one second; errors after three seconds.
After the starting notice's one-second display,
the worker waits for the same CaptureHandoffService readiness used by screenshots:
only panels opting into `hideForCapture` must finish closing before the recorder
starts. The capture controls opt in; ordinary launcher/Manage views and bar
panels default to staying visible. Recording setup uses its own shared capture
menu session, preserving another launcher’s query, selection and draft. Submap
hints and notice animations do not block readiness. The same property governs
screenshots, including the Meta+Print chooser. Private namespace exclusions remain
a separate compositor policy.
This follows the centralized motion policy automatically, including when animations
are disabled. The detached worker retries missing readiness replies through a bar
restart for up to ten seconds; a repeated shortcut cancels during this wait. If
readiness does not return, startup is cancelled and its runtime/audio state is
cleaned up. No animation-duration guess is used to start capture.
The finishing alert stays until completion and can appear in the last captured
frames. Completion opens the saved file location only after a successful recorder
exit and a nonempty output file. Encoder quality parameters remain unchanged.

`wf-recorder --no-damage` captures continuously, including when the screen is
static. Without it, wf-recorder 0.6.0 can receive SIGINT while waiting for a
Wayland damage event and fail to finish until another event arrives. Continuous
capture adds work on otherwise idle screens. Native tests using synthetic pixels
and the existing HEVC/NVENC parameters measured a 143 ms stop at 640×360 and
1095 ms at 3840×2160. These are individual measurements, not shutdown limits;
encoder draining and MP4 finalization still take time. No forced kill is used
to shorten normal stops.

The detached worker owns the recorder and any microphone loopback through
finalization. Bar restarts and automatic Config/theme reloads leave it running;
the new controller reconnects using `recording-runtime.db` beside
`Config.databasePath`. Its private runtime row contains the worker/recorder PIDs,
kernel start times, boot identity, phase, destination and loopback ID. Atomic
registration prevents duplicate setup. Process identities are checked before
signaling or recovering a stale session. Missing owners are cleaned up, including
finishing a surviving owned recorder. Failed audio cleanup retains its record for
a later retry.

A red-pulsing **** bar indicator appears beside screen sharing during capture
and stays visible through finalization. Hover shows the saved-file destination
and changes the heading to “Recording finishing” while stopping. Left-click
pins/unpins it using the shared bar behavior. Recording and sharing reuse
`UI.ActivityIndicator`, which opts into visible-glyph vertical centering in the
shared icon component without changing bar height. Pulse animation goes through `MotionPolicy` and
`Config.recordingPulseEnabled`, which defaults to `animateIndicators`.

Runtime SQLite state is excluded from backups and untouched by restores.
`qs ipc call recording status` reports the current controller state. Recording
is separate from PipeWire screen sharing: it does not activate the sharing
indicator, sharing privacy rules or sharing animation policy.

[Documentation](../README.md)
