# Onboarding

Install the [Arch packages](install-arch.md), then follow the
[first-run checklist](setup.md#first-run-checklist). These examples adapt the
integrations to your machine. Edit existing Config properties rather than adding
duplicate declarations.

## Optional modules

Review the switches grouped at the top of `config/Config.qml`. The
[switch table](configuration.md#optional-modules-and-integrations) explains each.
For example, omit the Network process tab and browser session suggestions with:

```qml
readonly property bool statsNetworkEnabled: false
readonly property bool twitchQutebrowserEnabled: false
```

For work mode, open Status → Manage and enter your process names and work folders.
Tracking and reports use the local database; no external status manager is needed.

## Paths and wallpapers

Create the default destinations, then place wallpaper images in the first:

```sh
mkdir -p "$HOME/Pictures/wallpapers" "$HOME/Pictures/.runtime" \
  "$HOME/Pictures/Screenshots" "$HOME/Videos/recordings"
awww-daemon
```

Start `awww-daemon` through desktop startup for subsequent sessions. To choose
other paths, edit the existing properties:

```qml
readonly property string wallpaperDirectory: `${_internal.home}/Pictures/wallpapers`
readonly property string wallpaperStateDirectory: `${_internal.home}/Pictures/.runtime`
readonly property string screenshotDirectory: `${_internal.home}/Pictures/Screenshots`
readonly property string recordingDirectory: `${_internal.home}/Videos/recordings`
```

## Applications and browser defaults

Check the applications you intend to use; only install the ones you need:

```sh
command -v xdg-open pcmanfm-qt ghostty code godot qutebrowser
xdg-settings get default-web-browser
```

Choose an installed browser ID from `browsers` for shared browser links and new
Webapps/n8n entries. For example, with Qutebrowser installed:

```qml
readonly property string defaultBrowserId: "qutebrowser"
readonly property var directoryOpenCommand: ["pcmanfm-qt"]
```

Saved entries retain their explicit browser/profile choices; edit them in Manage.
Review `projectApps` for editor commands/profiles before adding project sources.
For terminal and authentication options, see [Remotes setup](setup.md#remotes).

## Submap hints

The parser receives a submap name and prints `key;description` lines. This example
reads Hyprland's configured bind descriptions. Install the shared sample:

```sh
install -Dm755 integrations/hyprland/submap-hints.sh "$HOME/.local/bin/quickshell-submap-hints"
"$HOME/.local/bin/quickshell-submap-hints" tools
```

Run this from the repository root. See [integration instructions](../integrations/README.md#hyprland).

Configure its path:

```qml
readonly property string submapParserCommand: _internal.home + "/.local/bin/quickshell-submap-hints"
```

If you do not use submap hints, use `"/usr/bin/true"` instead. Desktop shortcuts
are configured separately; adapt the [Hypr binding examples](setup.md#first-run-checklist).

## Capture privacy

If Hypr defines `HideApplications`, keep the integration on. Otherwise disable
it, or install the [sample Lua helper](setup.md#screen-sharing):

```qml
readonly property bool hyprlandHideApplicationsEnabled: false
```

The disabled branch still synchronizes compositor animations. It does not remove
privacy rules configured separately in Hyprland.

## Temperature sensor

List the thermal zones and labels:

```sh
for zone in /sys/class/thermal/thermal_zone*; do
    [ -r "$zone/type" ] || continue
    printf '%s: ' "$zone/temp"
    cat "$zone/type"
done
```

Set the matching path, for example:

```qml
readonly property string statsTemperaturePath: "/sys/class/thermal/thermal_zone0/temp"
```

## Updates

Install `pacman-contrib` and configure `yay` as described in the
[Arch guide](install-arch.md#external-packages-and-application-choices). Refresh
the cache as your desktop user:

```sh
bash "$HOME/.config/quickshell/src/services/system/update-check.sh"
```

For an optional hourly schedule, fill in the path in the
[cron template](../integrations/cron/updates.crontab), then add its entry to your
user crontab with `crontab -e`. The
[pacman hook template](../integrations/arch/95-quickshell-updates.hook) can also
request refreshes after package transactions. Follow the
[installation instructions](../integrations/README.md#arch-updates).

Install/start your chosen cron service if using that schedule. The bar's
Check now button works without a cron schedule.

## Accounts and feature services

Follow the feature instructions for provider setup and commands:

- [TOTP and keyring](features/totp.md)
- [Vault account and pinentry](features/rbw.md#setup)
- [Backups](storage.md#backups)
- [Twitch, clipboard paste, batteries and capture](setup.md#optional-feature-activation)

Select `recordingEncoderArguments` for your GPU and desired quality/performance
before recording. For example, software H.264 replaces the NVIDIA arguments with:

```qml
readonly property var recordingEncoderArguments: ["-c", "libx264", "-p", "preset=veryfast", "-p", "crf=20"]
```
