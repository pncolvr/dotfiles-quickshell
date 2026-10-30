-- Optional example: review integrations/README.md before loading.
hl.bind("SUPER + D", hl.dsp.global("quickshell:launcher-apps"), { desc = "Applications" })
hl.bind("SUPER + V", hl.dsp.global("quickshell:launcher-clipboard"), { desc = "Clipboard" })
hl.bind("ALT + TAB", hl.dsp.global("quickshell:window-switch"), { desc = "Switch window" })
hl.bind("SUPER + PRINT", hl.dsp.global("quickshell:launcher-screenshot"), { desc = "Screenshot" })
hl.bind("SUPER + R", hl.dsp.global("quickshell:recording-toggle"), { desc = "Recording" })
-- Add inside your existing tools submap:
-- hl.bind("v", hl.dsp.global("quickshell:media-fullscreen"), { desc = "Fullscreen media" })

hl.bind("XF86AudioMute", hl.dsp.global("quickshell:audio-mic-mute"), { locked = true, desc = "Toggle microphone mute" })
hl.bind("XF86Eject", hl.dsp.global("quickshell:audio-speaker-mute"), { locked = true, desc = "Toggle speakers and Discord deafen" })
