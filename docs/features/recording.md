# Screen recording

Meta+R in the companion Hypr config dispatches `quickshell:recording-toggle`
through the shared native shortcut registry to `RecordingService.toggle()`.
`launcher.sh provider recording` remains available for shell callers and uses
`RecordingService` to control one detached recording worker. Capture, output or
region, frame rate and audio use the existing pickers. `Config.recordingDirectory`
supplies the destination through the shared provider Config bridge; `.env` files
are not read. Stopping does not load provider configuration.

The shortcut behaves according to the current phase:

| Phase | Shortcut |
| --- | --- |
| Idle | Open setup |
| Choosing options | Keep the current picker; Escape cancels |
| Starting, before capture | Cancel the pending recording |
| Recording | Send one SIGINT to the owned recorder and show “recording finishing” |
| Finishing or saving | Keep waiting; repeated presses do not restart or interrupt finalization |

Starting and stopped alerts expire after one second; errors after three seconds.
The existing 1.1-second starting delay keeps the starting alert outside capture.
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
`UI.ActivityIndicator`; pulse animation goes through `MotionPolicy` and
`Config.recordingPulseEnabled`, which defaults to `animateIndicators`.

Runtime SQLite state is excluded from backups and untouched by restores.
`qs ipc call recording status` reports the current controller state. Recording
is separate from PipeWire screen sharing: it does not activate the sharing
indicator, sharing privacy rules or sharing animation policy.

[Documentation](../README.md)
