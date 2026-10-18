# Desktop integrations

These optional files are templates to review, edit and install yourself. Nothing
here is installed automatically. Run the commands below from the Quickshell
repository root. Installed copies are independent of repository updates.

## Arch updates

Install `pacman-contrib`, `yay` and `sudo` as described in the
[Arch guide](../docs/install-arch.md). Both templates invoke the existing runtime
helper in `src/services/system/update-check.sh`; they do not replace it or copy
it elsewhere. The checkout must remain available at the configured path.

For a post-transaction hook, make a working copy:

```sh
cp integrations/arch/95-quickshell-updates.hook /tmp/95-quickshell-updates.hook
id -un
pwd -P
```

Edit `/tmp/95-quickshell-updates.hook`: replace `@USER@` with the desktop user's
name and `@QUICKSHELL_DIR@` with the absolute checkout path printed above. Keep
the path quotes. Hook commands do not expand `$HOME` or `~`. Then install it:

```sh
sudo install -Dm644 /tmp/95-quickshell-updates.hook /etc/pacman.d/hooks/95-quickshell-updates.hook
```

The hook runs the helper as your desktop user using `sudo -H -u`, without
loading a login profile. It covers package installation, upgrades and removal.
When the package database is locked, the helper asks the running shell to retry
after the transaction. Without a running shell, the next scheduled or manual
check refreshes the cache. Review an existing hook before replacing it.

For optional hourly checks, copy
[`cron/updates.crontab`](cron/updates.crontab), replace `@QUICKSHELL_DIR@` with
your absolute checkout path, and paste the job into your **user** crontab:

```sh
crontab -e
```

Keep existing jobs; do not install the template as a replacement crontab. Enable
your chosen cron service if using this schedule. No root database-sync job is
needed. The cron job and hook can coexist; the helper prevents overlapping checks.
The bar's Check now action works without either integration.

## Hyprland

The Lua files target Hyprland's Lua configuration API. Review them for your
installed compositor, paths and chosen shortcuts. Copy only the files you use:

```sh
install -Dm644 integrations/hyprland/bindings.lua "$HOME/.config/hypr/quickshell/bindings.lua"
install -Dm644 integrations/hyprland/autostart.lua "$HOME/.config/hypr/quickshell/autostart.lua"
install -Dm644 integrations/hyprland/capture-privacy.lua "$HOME/.config/hypr/quickshell/capture-privacy.lua"
```

Load your selected copies from the existing Hyprland Lua configuration. Load
privacy before startup when enabling the capture integration:

```lua
local examples = os.getenv("HOME") .. "/.config/hypr/quickshell/"
dofile(examples .. "capture-privacy.lua")
dofile(examples .. "bindings.lua")
dofile(examples .. "autostart.lua")
```

- [`bindings.lua`](hyprland/bindings.lua) maps desktop keys to registered shell
  actions. Adapt keys that conflict with your existing bindings. Panel shortcuts
  remain configured separately in `Config.keybinds`.
- [`autostart.lua`](hyprland/autostart.lua) starts the checkout at
  `~/.config/quickshell`. Edit that path if necessary. Use one startup mechanism;
  do not also start another instance through a service or another config file.
- [`capture-privacy.lua`](hyprland/capture-privacy.lua) defines `HideApplications`
  for the `quickshell-private` namespace. Match it to
  `Config.screenShareHiddenNamespace`. Set `hyprlandHideApplicationsEnabled` to
  `false` if you do not load this helper or an equivalent. It covers private
  Quickshell layers; additional application privacy rules are your desktop policy.

For submap hints, install the standalone parser; it needs `hyprctl` and `jq`:

```sh
install -Dm755 integrations/hyprland/submap-hints.sh "$HOME/.local/bin/quickshell-submap-hints"
"$HOME/.local/bin/quickshell-submap-hints" tools
```

Set the existing `Config.submapParserCommand` to
`_internal.home + "/.local/bin/quickshell-submap-hints"`. It accepts a submap name
and prints its described bindings as `key;description` lines. Use
`"/usr/bin/true"` when submap hints are unused.

See [onboarding](../docs/onboarding.md) and [capture setup](../docs/setup.md#screen-sharing)
for the remaining feature settings and manual checks.

## Browser routing

See [the optional browser desktop integration](browser/README.md) for installation,
fallback configuration and explicit default-browser commands. It does not replace
any existing desktop entry or association automatically.
