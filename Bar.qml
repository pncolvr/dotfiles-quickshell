import QtQuick
import Quickshell
import "theme"
import "theme/ui" as UI
import "bar"

Scope {
  Variants {
    model: Quickshell.screens
    UI.PanelWindow {
      id: panelWindow
      required property var modelData
      screen: modelData

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
        anchors.centerIn: parent
      }
      
      RightModules {
        anchors.right: parent.right
        window: panelWindow
      }

      TooltipWindow {}

      SubmapWindow {}
      AlertWindow {}
    }
    
  }
}