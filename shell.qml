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
  // Register recording IPC and reconnect to any detached recording session.
  readonly property var recordingService: RecordingService
  IpcHandler {
    target: "shell"
    function reload(): void {
      Qt.callLater(() => Quickshell.reload(true))
    }
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
    function onRestored() { Qt.callLater(() => Quickshell.reload(true)) }
  }
}
