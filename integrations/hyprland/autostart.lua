-- Optional example: review integrations/README.md before loading.
hl.on("hyprland.start", function()
    hl.exec_cmd('qs -p "' .. os.getenv("HOME") .. '/.config/quickshell"')
end)
