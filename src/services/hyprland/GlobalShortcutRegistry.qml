pragma ComponentBehavior: Bound
// Installed GlobalShortcut metadata references a non-exported PostReloadHook base.
import "../../i18n"
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
        {name: "launcher-apps", description: Translations.text("shortcuts.applications"), activate: () => PickerService.apps()},
        {name: "launcher-projects", description: Translations.text("shortcuts.projects"), activate: () => PickerService.projects()},
        {name: "launcher-project-urls", description: Translations.text("shortcuts.projectUrls"), activate: () => PickerService.projects(true)},
        {name: "launcher-directories", description: Translations.text("shortcuts.directories"), activate: () => PickerService.directories()},
        {name: "launcher-webapps", description: Translations.text("shortcuts.webapps"), activate: () => PickerService.webapps()},
        {name: "launcher-remotes", description: Translations.text("shortcuts.remotes"), activate: () => PickerService.remotes()},
        {name: "launcher-n8n", description: Translations.text("shortcuts.n8n"), activate: () => PickerService.n8n()},
        {name: "launcher-windows-all", description: Translations.text("shortcuts.windows"), activate: () => PickerService.windows("all")},
        {name: "window-switch", description: Translations.text("shortcuts.windows"), activate: () => PickerService.switchWindows()},
        {name: "launcher-windows-current", description: Translations.text("shortcuts.workspaceWindows"), activate: () => PickerService.windows("current")},
        {name: "launcher-expose-current", description: Translations.text("shortcuts.expose"), activate: () => PickerService.expose("current")},
        {name: "launcher-clipboard", description: Translations.text("shortcuts.clipboard"), activate: () => PickerService.clipboard()},
        {name: "launcher-wallpaper", description: Translations.text("shortcuts.wallpaper"), activate: () => WallpaperService.open()},
        {name: "launcher-encode-qr", description: Translations.text("shortcuts.qrEncode"), activate: () => QrEncodeService.open()},
        {name: "launcher-bookmarks", description: Translations.text("shortcuts.bookmarks"), activate: () => BookmarkService.open()},
        {name: "launcher-power", description: Translations.text("shortcuts.power"), activate: () => PowerService.open()},
        {name: "launcher-screenshot", description: Translations.text("shortcuts.screenshot"), activate: () => ScreenshotService.open()},
        ...["region", "output", "window", "ocr", "qrcode"].map(method => ({
            name: "screenshot-" + method, description: Translations.text("shortcuts.capture",[Translations.text("screenshot.modes."+method)]),
            activate: () => ScreenshotService.open(method)
        })),
        {name: "recording-toggle", description: Translations.text("shortcuts.recording"), activate: () => RecordingService.toggle()},
        {name: "vault-toggle", description: Translations.text("shortcuts.vault"), activate: () => RbwService.open()},
        {name: "notifications-toggle-dnd", description: Translations.text("shortcuts.dnd"), activate: () => NotificationService.toggle()},
        {name: "shell-reload", description: Translations.text("shortcuts.reload"), activate: () => root.reloadShell()},
        {name: "windows-next", description: Translations.text("shortcuts.nextWindow"), activate: () => WindowService.cycleNext()},
        {name: "windows-prev", description: Translations.text("shortcuts.previousWindow"), activate: () => WindowService.cyclePrev()}
    ].concat(
        ["updates", "clock", "files", "timers", "mic", "volume", "stats", "twitch",
          "status", "totp", "batteries", "notifications", "tray", "sharing"].map(moduleName => ({
            name: "bar-" + moduleName, description: Translations.text("shortcuts.panel",[Translations.text("bar.modules."+moduleName)]),
            activate: () => BarModuleService.open(moduleName)
          })),
        Array.from({length: 10}, (_, index) => (index + 1) % 10).map(key => ({
          name: "windows-focus-" + key, description: Translations.text("shortcuts.group",[key]),
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
