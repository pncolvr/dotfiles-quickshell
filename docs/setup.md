# Setup

## Start the shell

Place this repository at `~/.config/quickshell`, review
[configuration](configuration.md), then run:

```sh
qs -p "$HOME/.config/quickshell"
```

Keep `shell.qml` and `provider-config.qml` at the configuration root. The latter
exports provider settings headlessly when the bar is not running. Set capture
destinations and wallpaper paths in Config.qml; provider `.env` files are not used.

`shell.qml` loads the QML implementation in
`src/`; the audio spectrum helper builds automatically on first use. Quickshell creates `data/quickshell.db` on first
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
| `wl-clipboard`, `file`, util-linux (`flock`) | Background text/image clipboard capture and restoration |
| `wf-recorder`, `slurp`, NVIDIA HEVC/NVENC support | Detached screen recording with continuous capture and unchanged encoder quality settings |
| `qrencode` | QR PNG generation through `launcher.sh provider encode-qrcode` |
| `awww`, `awww-daemon` | Wallpaper picker, per-mode/output setting and restore |
| ImageMagick (`magick`) | Read original image dimensions for clipboard previews without enlarging small images |
| `sqlite3` with FTS5 (SQLite 3.42+) | Indexed clipboard search, temporary recording/remote ownership and backup snapshots/restores; Qt SQLite also needs FTS5 |
| 7-Zip (`7z` or `7zz`), `/dev/shm` tmpfs | Password-protected full-state backups, including TOTP secrets |
| `gtk-launch` | Desktop application launching, including terminal entries |
| `ydotool` and its daemon | Optional paste on clipboard activation |
| Noto Sans Mono, JetBrains Mono, Font Awesome 7 Free Solid | Text and icons configured in `src/theme/Theme.qml` |
| PipeWire, WirePlumber, `pactl` | Audio controls, routing, profiles and video capture detection |
| C compiler (`cc`), `pkg-config`, PipeWire and FFTW headers/libraries | Native cavacore spectrum helper; cached under `$XDG_RUNTIME_DIR/quickshell-spectrum` |
| `pavucontrol` | Mixer opened by middle-clicking audio icons |
| `libsecret` (`secret-tool`), `oath-toolkit` (`oathtool`), Secret Service provider | TOTP storage and code generation |
| UPower | Laptop and peripheral batteries |
| `libxslt` (`xsltproc`) | Desktop recent-file history (with Bash, coreutils, and `jq`) |
| BlueZ | Bluetooth battery reporting |
| Solaar | Optional Logitech receiver battery readings |
| NetworkManager (`nmcli`), `ping` | Native network devices, VPN discovery and connectivity |
| `bandwhich` | Optional per-process network bandwidth |
| power-profiles-daemon | Native Quickshell power profile controls |
| `twitch` CLI, `curl`, `notify-send` | Twitch data, avatars and stream notifications; curl also fetches n8n workflows |
| qutebrowser and jq-compatible `yq` | Optional suggestions from saved browser sessions |
| `yay`, Ghostty | Arch package update checking and installation |
| `canberra-gtk-play` | Screen-sharing start/stop sounds |
| `pgrep`, `readlink`, `jq`, `lsof`, `gdbus`, `busctl`, `hyprctl` | Optional native work/personal detection, session monitoring and time reports |

A Secret Service provider can be GNOME Keyring or KeePassXC with Secret Service
support enabled. Test-only dependencies are listed in [development](development.md).

## Webapps

Add Webapps entries in its Manage tab. Entries and browser profile choices live
in the local database and restore through the existing encrypted backup. No
provider JSON or browser environment file is required. Browser executable/argument
defaults live in `Config.webappBrowsers`.

## n8n

Open **Meta+Shift+N** and Manage to configure instances. Create each API key in
that instance's Settings → n8n API, then enter it in the masked field. Configure
browser/profile defaults in `Config.webappBrowsers`. Install `curl` for explicit
Refresh; cached links open without a network request. Multiple Personal/Work
connections and their caches restore through the encrypted database backup.

## Remotes

Open Remotes and use Manage to add SSH-tunnel/RDP hosts or local libvirt VMs.
The optional dependencies are OpenSSH, FreeRDP 3 with `sdl-freerdp3`, netcat
(with `-z -w` support), `getent` from libc, and libvirt's `virsh` for VM connections. Configure
command defaults in Config.qml. SSH keys/agents must already allow noninteractive
access. VM management uses the configured libvirt connection (system by default).
Credentials and private connection options are restored with the encrypted database
backup; runtime process records are deliberately excluded. No hosts JSON is required.

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
