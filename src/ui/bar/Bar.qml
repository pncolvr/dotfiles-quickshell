pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../panels"
import Quickshell.Wayland
import "../../theme"
import "../../config"
import ".." as UI
import "../../services"
import "../../modules/system/notifications"

Scope {
  Variants {
    model: Quickshell.screens
    UI.PanelWindow {
      id: panelWindow
      required property var modelData
      screen: modelData
      color: "transparent"
      readonly property bool islands: AdaptiveBarService.islandsFor(screen)
      readonly property rect leftBounds: Qt.rect(0, 0, left.width + Theme.controlFieldPadding, height)
      readonly property rect centerBounds: Qt.rect(center.x - Theme.controlFieldPadding, 0,
          center.width + Theme.controlFieldPadding * 2, height)
      readonly property rect rightBounds: Qt.rect(right.x - Theme.controlFieldPadding, 0,
          right.width + Theme.controlFieldPadding, height)
      mask: Region {
        width: panelWindow.islands ? 0 : panelWindow.width
        height: panelWindow.height
        Region { x: panelWindow.leftBounds.x; width: panelWindow.leftBounds.width; height: panelWindow.height; bottomRightRadius: Theme.tooltipRadius }
        Region { x: panelWindow.centerBounds.x; width: panelWindow.centerBounds.width; height: panelWindow.height; bottomLeftRadius: Theme.tooltipRadius; bottomRightRadius: Theme.tooltipRadius }
        Region { x: panelWindow.rightBounds.x; width: panelWindow.rightBounds.width; height: panelWindow.height; bottomLeftRadius: Theme.tooltipRadius }
      }
      Loader {
        active: Config.adaptiveBarEnabled
        sourceComponent: AdaptiveBarState { screen: panelWindow.screen; foregroundRoot: panelWindow.contentItem }
      }
      BarBackground {
        anchors.fill: parent
        islands: panelWindow.islands
        background: AdaptiveBarService.backgroundFor(panelWindow.screen)
        leftBounds: panelWindow.leftBounds
        centerBounds: panelWindow.centerBounds
        rightBounds: panelWindow.rightBounds
        bridges: AdaptiveBarService.bridges(panelWindow.screen)
      }
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
        id: left
        anchors.left: parent.left
      }

      CenterModules {
        id: center
        window: panelWindow
        anchors.centerIn: parent
      }
      
      RightModules {
        id: right
        anchors.right: parent.right
        window: panelWindow
      }

      TooltipWindow { screen: panelWindow.screen }
      NotificationImageCache {
        enabled: panelWindow.screen === Quickshell.screens[0]
      }

      SubmapWindow {}
      AlertWindow { screen: panelWindow.screen }
    }
    
  }
}
