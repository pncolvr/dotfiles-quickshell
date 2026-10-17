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
import "src/config"

Scope {
  // Release references to this generation before its tooltip owners are destroyed.
  Component.onDestruction: TooltipService.dismiss()
  // Register recording IPC and reconnect to any detached recording session.
  readonly property var recordingService: RecordingService
  IpcHandler {
    target: "shell"
    function reload(): void {
      shortcuts.reloadShell()
    }
  }

  GlobalShortcutRegistry { id: shortcuts }

  Bar {}
  NotificationPopupWindow {}
  NotificationManagerWindow {}
  LazyLoader { active: Config.totpEnabled; TotpWindow {} }
  PickerWindow {}
  PickerWindow { picker: ClipboardPickerService }
  PickerWindow { picker: CaptureMenuService }
  PrivatePickerWindow {}
  LazyLoader { active: Config.vaultEnabled; VaultWindow {} }
  ExposeWindow {}
  MediaFullscreenWindow {}
  Connections {
    target: BackupService
    function onRestored() { shortcuts.reloadShell() }
  }
}
