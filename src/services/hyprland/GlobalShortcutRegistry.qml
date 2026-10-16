pragma ComponentBehavior: Bound
// Installed GlobalShortcut metadata references a non-exported PostReloadHook base.
import QtQml
import QtQml.Models
import Quickshell
import Quickshell.Hyprland
import "../"

// Register once per shell; callbacks reuse feature services and their lifecycle.
Scope {
    id: root
    property string appId: "quickshell"
    readonly property var actions: [
        {name: "launcher-apps", description: "Open applications", activate: () => PickerService.apps()},
        {name: "launcher-projects", description: "Open projects", activate: () => PickerService.projects()},
        {name: "launcher-project-urls", description: "Open project URLs", activate: () => PickerService.projects(true)},
        {name: "launcher-directories", description: "Open directories", activate: () => PickerService.directories()},
        {name: "launcher-webapps", description: "Open Webapps", activate: () => PickerService.webapps()},
        {name: "launcher-remotes", description: "Open Remotes", activate: () => PickerService.remotes()},
        {name: "launcher-n8n", description: "Open n8n workflows", activate: () => PickerService.n8n()},
        {name: "launcher-windows-all", description: "Switch windows", activate: () => PickerService.windows("all")},
        {name: "launcher-windows-current", description: "Switch current workspace windows", activate: () => PickerService.windows("current")},
        {name: "launcher-expose-current", description: "Open window overview", activate: () => PickerService.expose("current")},
        {name: "launcher-clipboard", description: "Open clipboard history", activate: () => PickerService.clipboard()},
        {name: "launcher-wallpaper", description: "Choose wallpaper", activate: () => WallpaperService.open()},
        {name: "launcher-encode-qr", description: "Encode QR code", activate: () => QrEncodeService.open()},
        {name: "launcher-bookmarks", description: "Open bookmarks", activate: () => BookmarkService.open()},
        {name: "launcher-power", description: "Open power menu", activate: () => PowerService.open()},
        {name: "recording-toggle", description: "Control screen recording", activate: () => RecordingService.toggle()},
        {name: "vault-toggle", description: "Toggle vault manager", activate: () => RbwService.open()},
        {name: "notifications-toggle-dnd", description: "Toggle notification do not disturb", activate: () => NotificationService.toggle()},
        {name: "shell-reload", description: "Reload Quickshell", activate: () => root.reloadShell()},
        {name: "windows-next", description: "Focus next window", activate: () => WindowService.cycleNext()},
        {name: "windows-prev", description: "Focus previous window", activate: () => WindowService.cyclePrev()}
    ].concat(
        ["updates", "clock", "files", "timers", "mic", "volume", "stats", "twitch",
          "status", "totp", "batteries", "notifications", "tray", "sharing"].map(moduleName => ({
            name: "bar-" + moduleName, description: "Open " + moduleName + " panel",
            activate: () => BarModuleService.open(moduleName)
          })),
        Array.from({length: 10}, (_, index) => (index + 1) % 10).map(key => ({
          name: "windows-focus-" + key, description: "Focus grouped window " + key,
          activate: () => WindowService.focusIndex(String(key))
        }))
    )

    function reloadShell() { Qt.callLater(() => Quickshell.reload(true)) }

    Instantiator {
        model: root.actions
        delegate: Component {
            // qmllint disable unresolved-type
            GlobalShortcut {
                // qmllint enable unresolved-type
                required property var modelData
                appid: root.appId
                name: modelData.name
                description: modelData.description
                onPressed: modelData.activate()
            }
        }
    }
}
