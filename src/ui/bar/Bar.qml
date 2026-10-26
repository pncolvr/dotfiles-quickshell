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
      readonly property color buttonSurfaceColor: AdaptiveBarService.backgroundFor(screen)
      readonly property bool islands: AdaptiveBarService.islandsFor(screen)
      readonly property rect leftBounds: Qt.rect(0, 0, left.width + Theme.controlFieldPadding, height)
      readonly property rect centerBounds: Qt.rect(center.x - Theme.controlFieldPadding, 0,
          center.width + Theme.controlFieldPadding * 2, height)
      readonly property rect rightBounds: Qt.rect(rightModules.x - Theme.controlFieldPadding, 0,
          rightModules.width + Theme.controlFieldPadding, height)
      BarLayerState { id: layerState; screen: panelWindow.screen }
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
      // Keep bar-attached overlays visually joined above fullscreen applications.
      WlrLayershell.layer: layerState.layer

      anchors {
        top: true
        left: true
        right: true
      }
      
      implicitHeight: Theme.barHeight
      LeftModules {
        id: left
        anchors.left: parent.left
        maximumWidth: Math.max(0, Math.min(center.x, rightModules.x) - x - Theme.moduleSpacing)
      }

      CenterModules {
        id: center
        window: panelWindow
        anchors.centerIn: parent
      }
      
      RightModules {
        id: rightModules
        anchors.right: parent.right
        window: panelWindow
      }

      TooltipWindow { screen: panelWindow.screen }
      NotificationImageCache {
        enabled: panelWindow.screen === Quickshell.screens[0]
      }

      SubmapWindow { screen: panelWindow.screen; requestedScreen: panelWindow.screen }
      AlertWindow { screen: panelWindow.screen; requestedScreen: panelWindow.screen }
    }
    
  }
}
