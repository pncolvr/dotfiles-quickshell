//@ pragma UseQApplication
// qt6ct contacts the portal before Qt's late Registry.Register call.
//@ pragma DefaultEnv QT_NO_XDG_DESKTOP_PORTAL = 1
import Quickshell
import "modules/system/notifications"

Scope {
  Bar {}
  NotificationPopupWindow {}
  NotificationManagerWindow {}
}
