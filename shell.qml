//@ pragma UseQApplication
// qt6ct contacts the portal before Qt's late Registry.Register call.
//@ pragma DefaultEnv QT_NO_XDG_DESKTOP_PORTAL = 1
import Quickshell
import "src"
import "src/modules/system/notifications"
import "src/modules/system/totp"

Scope {
  Bar {}
  NotificationPopupWindow {}
  NotificationManagerWindow {}
  TotpWindow {}
}
