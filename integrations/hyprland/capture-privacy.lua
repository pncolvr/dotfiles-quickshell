-- Optional example: review integrations/README.md before loading.
local privatePanelsHidden = hl.layer_rule({
    name = "quickshell_private_capture",
    match = { namespace = "quickshell-private" },
    no_screen_share = true,
})
privatePanelsHidden:set_enabled(false)

function HideApplications(active, animationsEnabled)
    privatePanelsHidden:set_enabled(active)
    hl.config({ animations = { enabled = animationsEnabled } })
end
