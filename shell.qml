//@ pragma UseQApplication
// qt6ct contacts the portal before Qt's late Registry.Register call.
//@ pragma DefaultEnv QT_NO_XDG_DESKTOP_PORTAL = 1
import Quickshell
import QtQml
import Quickshell.Io
import "src"
import "src/modules/system/notifications"
import "src/modules/system/totp"
import "src/modules/launcher"
import "src/modules/vault"
import "src/modules/system/audio"
import "src/services"

Scope {
  id: shellRoot
  function reloadShell() { Qt.callLater(() => Quickshell.reload(true)) }

  // Register recording IPC and reconnect to any detached recording session.
  readonly property var recordingService: RecordingService
  IpcHandler {
    target: "shell"
    function reload(): void {
      shellRoot.reloadShell()
    }
  }

  GlobalShortcutRegistry {
    actions: [
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
      {name: "launcher-bookmarks", description: "Open bookmarks", activate: () => BookmarkService.open()},
      {name: "launcher-power", description: "Open power menu", activate: () => PowerService.open()},
      {name: "recording-toggle", description: "Control screen recording", activate: () => RecordingService.toggle()},
      {name: "vault-toggle", description: "Toggle vault manager", activate: () => RbwService.open()},
      {name: "notifications-toggle-dnd", description: "Toggle notification do not disturb", activate: () => NotificationService.toggle()},
      {name: "shell-reload", description: "Reload Quickshell", activate: () => shellRoot.reloadShell()},
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
  }

  Bar {}
  NotificationPopupWindow {}
  NotificationManagerWindow {}
  TotpWindow {}
  PickerWindow {}
  PrivatePickerWindow {}
  VaultWindow {}
  ExposeWindow {}
  MediaFullscreenWindow {}
  Connections {
    target: BackupService
    function onRestored() { shellRoot.reloadShell() }
  }
}
