# Setup

Follow [Arch installation](install-arch.md), then complete the checklist below.
Installation instructions currently cover Arch only.
The shipped Config contains the author's enabled features; cloning does not
automatically disable optional modules. Their switches are grouped at the top of
`config/Config.qml` and listed in [configuration](configuration.md#optional-modules-and-integrations).

## Start the shell

Clone into a new, empty configuration location:

```sh
git clone https://github.com/pncolvr/dotfiles-quickshell.git "$HOME/.config/quickshell"
```

Review the checklist and [configuration](configuration.md), then run as your
desktop user inside Hyprland:

```sh
qs -p "$HOME/.config/quickshell"
```

Keep `shell.qml` and `provider-config.qml` at the configuration root. The latter
exports provider settings headlessly when the bar is not running. Set capture
destinations and wallpaper paths in Config.qml; provider `.env` files are not used.

`shell.qml` loads the QML implementation in
`src/`; the audio spectrum helper builds automatically on first use. Quickshell creates `data/quickshell.db` on first
run. Keep that directory writable.

## First-run checklist

1. Install a matching Quickshell/Qt stack and use a working Hyprland Wayland
   session with the Lua API (`hyprctl eval`). Qt 6.10+ is required.
   This tree is currently exercised with Quickshell 0.3.2.
2. Review the optional-switch block. For a first launch without optional
   accounts/tools, set the following to `false` in your own checkout:

   ```qml
   readonly property bool bookmarksEnabled: false
   readonly property bool clipboardMonitorEnabled: false
   readonly property bool workModeEnabled: false
   readonly property bool statsNetworkEnabled: false
   readonly property bool batteriesEnabled: false
   readonly property bool twitchEnabled: false
   readonly property bool twitchQutebrowserEnabled: false
   readonly property bool hyprlandHideApplicationsEnabled: false
   readonly property bool vaultEnabled: false
   readonly property bool totpEnabled: false
   ```

   Edit the existing declarations; do not add duplicate properties. This keeps
   clocks, calendars, timers, resource totals, native audio controls, tray and
   notifications available. It does not hide every action requiring an external
   tool: screenshots, recording, wallpaper and Arch updates have prerequisites
   of their own.
3. Install the configured fonts. Check `fc-match 'Font Awesome 7 Free'`,
   `fc-match 'Noto Sans Mono'` and `fc-match 'JetBrains Mono'`; a successful fallback
   match is not proof the requested font is installed.
4. Keep the session D-Bus bus and `$XDG_RUNTIME_DIR` available. Verify
   `systemctl --user status pipewire.socket wireplumber.service` and
   `pactl info`. For a new PipeWire setup, typical activation is
   `systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service`.
   Check existing services before changing providers.
5. If using NetworkManager, check `systemctl status NetworkManager.service`
   and `nmcli general status`. Enable it with
   `sudo systemctl enable --now NetworkManager.service` only when it is the
   intended network manager. UPower and power-profiles-daemon normally start
   through system D-Bus; Bluetooth needs an active BlueZ service for device data.
   Missing desktop services can leave their controls unavailable; the bar is not
   a replacement for configuring those services.
6. Stop another notification server before starting this shell. Follow
   [notification ownership](#notification-ownership); merely installing packages
   does not resolve competing notification owners.
7. Adjust your application commands, browser profiles, wallpaper/capture paths,
   temperature sensor path and Hypr workspace assumptions. See
   [onboarding examples](onboarding.md) for commands and configuration snippets.
8. Start the shell in a terminal and inspect its log. Check clock/calendar,
   Stats Overview, audio and a `notify-send` sample. Confirm that the local database
   is created and that a restart preserves it. For a read-only database check:

   ```sh
   sqlite3 "$HOME/.config/quickshell/data/quickshell.db" 'PRAGMA integrity_check;'
   ```

9. Add desktop bindings after startup works. The repository registers actions;
   it does not install the author's Hypr keybinds or submaps. For example, in a
   Hypr Lua configuration:

   ```lua
   hl.bind("SUPER + D", hl.dsp.global("quickshell:launcher-apps"), { desc = "Applications" })
   hl.bind("SUPER + V", hl.dsp.global("quickshell:launcher-clipboard"), { desc = "Clipboard" })
   hl.bind("ALT + TAB", hl.dsp.global("quickshell:window-switch"), { desc = "Switch window" })
   hl.bind("SUPER + PRINT", hl.dsp.global("quickshell:launcher-screenshot"), { desc = "Screenshot" })
   hl.bind("SUPER + R", hl.dsp.global("quickshell:recording-toggle"), { desc = "Recording" })
   ```

   `Config.keybinds` configures actions inside panels; it does not register these
   desktop shortcuts. See [IPC](ipc.md) for alternatives and action names.
10. Enable and configure optional features one at a time. Once stable, add this
    [startup hook](https://wiki.hypr.land/configuring/core/autostart/) to Hypr Lua:

    ```lua
    hl.on("hyprland.start", function()
        hl.exec_cmd('qs -p "' .. os.getenv("HOME") .. '/.config/quickshell"')
    end)
    ```

    Avoid also starting a second shell through a user service or another startup file.

## Optional feature activation

Package groups live in the [Arch guide](install-arch.md). Installation alone is not sufficient:

| Feature | First-use action |
| --- | --- |
| Work mode | Enable `workModeEnabled`; configure process/folder rules in Status → Manage. Native tracking uses SQLite and defaults to 36 months of retention; no external manager/timecard executable. |
| Clipboard | Enable `clipboardMonitorEnabled` for collection. For synthetic paste, run/configure ydotoold and give your user access to its socket/uinput according to the distro service configuration. Copy works without synthetic paste. |
| Wallpaper | Set `wallpaperDirectory` and `wallpaperStateDirectory`, start `awww-daemon` in the graphical session, then select a wallpaper. Package installation does not launch the daemon. |
| Audio spectrum | Run `bash src/services/audio/audio-spectrum.sh --build` from the repository to check compiler/headers. Compilation is otherwise automatic on first use into `$XDG_RUNTIME_DIR/quickshell-spectrum`. |
| TOTP | Enable `totpEnabled`; ensure an unlocked Secret Service provider (GNOME Keyring or KeePassXC with Secret Service enabled), `secret-tool` and `oathtool`. Add tokens through the module. See [TOTP](features/totp.md). |
| Vault | Install rbw **1.15.x**, configure account/server and pinentry, register/login/sync, then enable `vaultEnabled`. See [rbw setup](features/rbw.md#setup). Browser userscripts are external and opt-in; they are not installed by this repository. |
| Backups | Install 7-Zip, TOTP/keyring tools and retain writable `data/` plus `/dev/shm` tmpfs. Full-state backups include tokens even with the TOTP UI off. Use [backup IPC](storage.md#backups); verify a private test restore before relying on an archive. |
| Twitch | Install the official Twitch CLI, run `twitch configure` with your own application credentials, obtain a token using `twitch token`, then enable `twitchEnabled` and add channels. Follow [upstream configuration](https://github.com/twitchdev/twitch-cli/blob/main/docs/configure.md) and [token setup](https://github.com/twitchdev/twitch-cli/blob/main/docs/token.md). |
| Browser integration | Enable Bookmarks only after setting `bookmarkFile` to an existing plain-text source (`URL title` per line, as used by qutebrowser). Twitch session suggestions require `twitchQutebrowserEnabled`, qutebrowser saved sessions and jq-compatible `yq` (the Python/kislyuk variant, not the unrelated Go command). |
| Stats Network | Enable `statsNetworkEnabled` only with bandwhich available and permitted to capture. Follow [bandwhich's Linux permissions guidance](https://github.com/imsnif/bandwhich#installation); do not run the whole shell as root. Without capture permissions the tab shows an error. |
| Batteries | Enable `batteriesEnabled`; use UPower/BlueZ for native readings. Solaar is optional, and device/udev permissions must allow receiver access. |
| Recording | Set writable `recordingDirectory` and hardware-appropriate `recordingEncoderArguments`; the shipped encoder is NVIDIA HEVC/NVENC. Verify audio inputs/outputs and a short recording. |
| Screenshots | Install grim/slurp/hyprpicker and the `satty` command. OCR needs Tesseract Portuguese data; QR decoding needs ZBar. Follow the independent `hideForCapture` panel policy described in [panels](features/panels.md). |
| Remotes/n8n/Webapps | Add entries in Manage. Configure terminal/browser executables and profiles before opening entries; see below for connection/authentication requirements. |

## Dependencies

The current configuration uses Hyprland and its Lua command API. Some commands
call custom functions defined in the author's Hyprland configuration; review
those before running on another desktop.

| Dependency | Used for |
| --- | --- |
| Quickshell (currently checked with 0.3.2), Qt 6.10+ | QML shell, native services, trimmed notification outlines |
| Hyprland and `hyprctl` | Workspaces, window focus, submaps, screen sharing |
| Bash, coreutils, findutils, `awk`, `grep`, `sed`, `jq` | Command helpers, folder files, and parsing |
| `wl-clipboard`, `file`, util-linux (`flock`, `setsid`) | Background text/image clipboard capture and restoration; owned QR tool groups |
| `wf-recorder`, `slurp`, NVIDIA HEVC/NVENC support | Detached screen recording with continuous capture and unchanged encoder quality settings |
| `grim`, `slurp`, `hyprpicker`, Satty | Frozen region/window/output screenshots and reload-independent annotation; hyprshot is not required |
| Tesseract with Portuguese language data, ZBar (`zbarimg`) | Screen OCR and QR decoding |
| `qrencode` | Native QR encoding; `launcher.sh provider encode-qrcode` remains a compatibility entry |
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
| `libxslt` (`xsltproc`), GIO (`gio open`) | Desktop recent-file history and opening files through their default applications |
| BlueZ | Bluetooth battery reporting |
| Solaar | Optional Logitech receiver battery readings |
| NetworkManager (`nmcli`), `ping` | Native network devices, VPN discovery and connectivity |
| `bandwhich` | Required only for Stats’ Network tab (`statsNetworkEnabled: true`); disable the tab to omit it |
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

Open Remotes and use Manage to add SSH terminal, RDP, SSH-tunnel/RDP hosts or local libvirt VMs.
The optional dependencies are OpenSSH, FreeRDP 3 with `sdl-freerdp3`, netcat
(with `-z -w` support), `getent` from libc, and libvirt's `virsh` for VM connections. Configure
command defaults in Config.qml. SSH terminal uses Ghostty by default and supports
optional destination/jump credentials through OpenSSH askpass; missing credentials
and key/host confirmation prompts remain in the terminal. Jump hosts are optional.
Tunnelled RDP needs working SSH authentication for its configured tunnel.
VM management uses the configured libvirt connection (system by default); check
`virsh -c qemu:///system list --all` as your desktop user and arrange the host's
normal libvirt authorization. Installing the client alone does not create a VM host.
Credentials and private connection options are restored with the encrypted database
backup; runtime process records are deliberately excluded. No hosts JSON is required.

## Screen sharing

`hyprlandHideApplicationsEnabled` defaults to `true` for the author's setup.
When enabled, the shell calls the custom `HideApplications(active, animationsEnabled)`
function on startup, screen-sharing changes and compositor configuration reloads.
This function is not a Hyprland built-in. Set the switch to `false` if you have
not configured it; compositor animation synchronization still runs through
`hl.config` and the bar does not install privacy rules for you.

Notification popups/manager, TOTP, Vault and private picker windows use
`quickshell-private` (`Config.screenShareHiddenNamespace`). Here is a minimal
Lua example for that namespace, to load before starting the shell:

```lua
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
```

This covers private Quickshell layers only. The author's additional communication
application/Vault-client rules are desktop policy and are not prerequisites for
this example. Add your own client rules if needed. Review the current
[Hyprland layer-rule API](https://wiki.hypr.land/configuring/core/rules/layer-rules/)
for your installed compositor. Verify notifications and TOTP remain visible
locally, disappear from a shared stream and become screenshot-visible again
when sharing ends. The documentation example has not been applied to the host.

This privacy integration is separate from screenshot/recording menu closure:
only panels opting into `hideForCapture` close before capture; ordinary tooltips
and Manage panels remain visible.

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
