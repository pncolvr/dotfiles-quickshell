import QtQuick
import Quickshell
import Quickshell.Wayland
import "theme"
import "theme/ui" as UI
import "bar"
import "services"
import "modules/system/notifications"

Scope {
  Variants {
    model: Quickshell.screens
    UI.PanelWindow {
      id: panelWindow
      required property var modelData
      screen: modelData
      // Keep the launcher's attachment visible above fullscreen applications.
      WlrLayershell.layer: PickerService.visible && PickerService.layout !== "expose"
        && PickerService.targetScreen === panelWindow.screen ? WlrLayer.Overlay : WlrLayer.Top

      anchors {
        top: true
        left: true
        right: true
      }
      
      implicitHeight: Theme.barHeight
      LeftModules {
        anchors.left: parent.left
      }

      CenterModules {
        window: panelWindow
        anchors.centerIn: parent
      }
      
      RightModules {
        anchors.right: parent.right
        window: panelWindow
      }

      TooltipWindow { screen: panelWindow.screen }
      NotificationImageCache {
        enabled: panelWindow.screen === Quickshell.screens[0]
      }

      SubmapWindow {}
      AlertWindow {}
    }
    
  }
}
