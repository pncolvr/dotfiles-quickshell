# Setup

## Start the shell

Place this repository at `~/.config/quickshell`, review
[configuration](configuration.md), then run:

```sh
qs -p "$HOME/.config/quickshell"
```

Keep `shell.qml` at the configuration root. It loads the QML implementation in
`src/`; no build step is required. Quickshell creates `data/quickshell.db` on first
run. Keep that directory writable.

## Dependencies

The current configuration uses Hyprland and its Lua command API. Some commands
call custom functions defined in the author's Hyprland configuration; review
those before running on another desktop.

| Dependency | Used for |
| --- | --- |
| Quickshell (developed with 0.3.1), Qt 6.10+ | QML shell, native services, trimmed notification outlines |
| Hyprland and `hyprctl` | Workspaces, window focus, submaps, screen sharing |
| Bash, coreutils, findutils, `awk`, `grep`, `sed`, `jq` | Command helpers, folder files, and parsing |
| Noto Sans Mono, JetBrains Mono, Font Awesome 7 Free Solid | Text and icons configured in `src/theme/Theme.qml` |
| PipeWire, WirePlumber, `pactl` | Audio devices, defaults, application routing and profiles |
| `pavucontrol` | Mixer opened by middle-clicking audio icons |
| `libsecret` (`secret-tool`), `oath-toolkit` (`oathtool`), Secret Service provider | TOTP storage and code generation |
| UPower | Laptop and peripheral batteries |
| `libxslt` (`xsltproc`) | Desktop recent-file history (with Bash, coreutils, and `jq`) |
| BlueZ | Bluetooth battery reporting |
| Solaar | Optional Logitech receiver battery readings |
| NetworkManager (`nmcli`), `ping` | Connected networks, VPN status and connectivity |
| `bandwhich` | Optional per-process network bandwidth |
| `powerprofilesctl` | Power profile controls |
| `twitch` CLI, `curl`, `notify-send` | Twitch data, avatars and stream notifications |
| qutebrowser and jq-compatible `yq` | Optional suggestions from saved browser sessions |
| `yay`, Ghostty | Arch package update checking and installation |
| `canberra-gtk-play` | Screen-sharing start/stop sounds |

A Secret Service provider can be GNOME Keyring or KeePassXC with Secret Service
support enabled. Test-only dependencies are listed in [development](development.md).

## Screen sharing

Notification popups, the notification manager, and the TOTP tooltip share the
layer namespace `quickshell-private` (`Config.screenShareHiddenNamespace`).
One capture rule in `~/.config/hypr/config/windowrules.lua` covers them all:

```lua
match = { namespace = "quickshell-private" },
```

Keep `NotificationsHidden`, `no_screen_share`, and `HideApplications(active)`.
The shell synchronizes capture state on native startup, screen-sharing changes
and Hypr configuration reloads. After the namespace edit, verify that both
notifications and TOTP remain visible locally but disappear from a shared stream,
and become screenshot-visible again when sharing ends.

## Notification ownership

For a deliberate switch, stop the existing Quickshell instance, stop/mask SwayNC,
make the namespace edit, reload Hypr, then start the shell:

```sh
systemctl --user mask --now swaync.service
qs -p "$HOME/.config/quickshell"
```

Verify ownership with `busctl --user status org.freedesktop.Notifications` and send
a sample with `notify-send`. SwayNC's installed D-Bus activation files can start
its systemd unit on demand, so disabling it alone does not block activation.

To restore SwayNC, stop Quickshell, restore `swaync-notification-window` in the
Hypr rule, reload Hypr, and unmask/start SwayNC:

```sh
systemctl --user unmask swaync.service
systemctl --user start swaync.service
```

Use a Quickshell configuration without the native notification server before
starting Quickshell alongside SwayNC. The new history database can be retained.
Only one handler should own the notification interface. Live screen-sharing
checks remain part of this manual handover.

See [notifications](features/notifications.md) for manager controls and source policies.

[Documentation](README.md)
