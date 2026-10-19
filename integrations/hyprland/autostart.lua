-- Optional example: review integrations/README.md before loading.
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd PATH WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd('qs -p "' .. os.getenv("HOME") .. '/.config/quickshell"')
end)
