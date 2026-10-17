# Arch Linux installation

Use an up-to-date Arch system with a working Hyprland session. These commands
install packages; complete [first-run setup](setup.md#first-run-checklist) afterwards.

## Core and desktop services

```sh
sudo pacman -Syu --needed \
  quickshell hyprland qt6-declarative qt6-wayland qt6-svg qt6-imageformats \
  git bash coreutils findutils gawk grep sed jq sqlite util-linux file \
  wl-clipboard xdg-utils gtk3 fontconfig noto-fonts ttf-jetbrains-mono otf-font-awesome \
  pipewire wireplumber pipewire-pulse networkmanager iputils \
  upower bluez power-profiles-daemon
```

Quickshell is in the official Extra repository; `quickshell-git` from the AUR
is unnecessary. The checked package was 0.3.2, with Qt 6.12.0 and Hyprland
0.56.2. This configuration needs Qt 6.10+ and Hyprland's Lua API, including
`hyprctl eval`; retain a matching Quickshell/Qt stack when upgrading.
See [Quickshell installation](https://quickshell.org/docs/v0.3.0/guide/install-setup/),
[the Arch package](https://archlinux.org/packages/extra/x86_64/quickshell/) and
[Hyprland's command API](https://wiki.hypr.land/configuring/core/advanced-configuration/using-hyprctl/).

PipeWire/WirePlumber, NetworkManager, UPower and BlueZ are desktop service
dependencies, not requirements for parsing every QML component. Existing desktop
services may already provide them. Follow the shared service checks rather than
replacing another network/audio setup automatically.

## Optional features

Install only the rows you intend to use. All packages below resolved from official
repositories; the Twitch CLI and `yay` are handled separately.

| Feature | Install command |
| --- | --- |
| Screenshots and annotation | `sudo pacman -S --needed grim slurp hyprpicker satty` |
| OCR, QR decoding and QR generation | `sudo pacman -S --needed tesseract tesseract-data-por zbar qrencode` |
| Recording | `sudo pacman -S --needed wf-recorder slurp` |
| Wallpaper | `sudo pacman -S --needed awww` |
| Clipboard image dimensions | `sudo pacman -S --needed imagemagick` |
| Clipboard synthetic paste | `sudo pacman -S --needed ydotool` |
| Recent Files | `sudo pacman -S --needed libxslt` |
| Audio spectrum and mixer | `sudo pacman -S --needed gcc pkgconf libpipewire fftw pavucontrol` |
| TOTP and full-state backups | `sudo pacman -S --needed libsecret oath-toolkit gnome-keyring 7zip` |
| Vault manager | `sudo pacman -S --needed rbw` |
| Twitch/n8n HTTP and notifications | `sudo pacman -S --needed curl libnotify which` |
| qutebrowser session suggestions | `sudo pacman -S --needed qutebrowser yq` |
| Logitech receiver batteries | `sudo pacman -S --needed solaar` |
| Stats Network | `sudo pacman -S --needed bandwhich libcap` |
| SSH terminal/RDP/VMs | `sudo pacman -S --needed openssh freerdp openbsd-netcat libvirt ghostty` |
| Work detection/session monitoring | `sudo pacman -S --needed procps-ng lsof` |
| Timers/capture sounds | `sudo pacman -S --needed libcanberra sound-theme-freedesktop` |
| Default directory opener | `sudo pacman -S --needed pcmanfm-qt` |
| Arch update checking | `sudo pacman -S --needed pacman-contrib` plus `yay` below |

To install the combined official-repository optional set instead:

```sh
sudo pacman -S --needed \
  grim slurp hyprpicker satty wf-recorder tesseract tesseract-data-por zbar \
  qrencode awww imagemagick ydotool libxslt gcc pkgconf libpipewire fftw \
  pavucontrol libsecret oath-toolkit gnome-keyring 7zip rbw curl libnotify which \
  qutebrowser yq solaar bandwhich libcap openssh freerdp openbsd-netcat libvirt \
  ghostty procps-ng lsof libcanberra sound-theme-freedesktop pcmanfm-qt pacman-contrib
```

The recording defaults select NVIDIA HEVC/NVENC. Installing `wf-recorder` does
not make that encoder available on other GPUs; configure
`recordingEncoderArguments` for your hardware before recording.

## External packages and application choices

Install the official [Twitch CLI release](https://github.com/twitchdev/twitch-cli/releases)
as `twitch` in your user PATH; follow [Twitch configuration](setup.md#optional-feature-activation).
It is distinct from other tools with similar names.

`yay` is an AUR helper, not an official-repository dependency. Review its
[AUR package and build instructions](https://aur.archlinux.org/packages/yay)
if enabling package updates. Do not run AUR builds as root. The default update
installer launches `ghostty -e yay`; the check helper needs `checkupdates` from
pacman-contrib and `yay -Qua`.

Code, Godot, Vivaldi and browser profile paths are configurable application
choices, not core dependencies. Adjust `projectApps`, `webappBrowsers`,
`webappDefaultBrowser` and the opener commands to installed applications.

Next: [first-run checklist and optional service activation](setup.md#first-run-checklist).
