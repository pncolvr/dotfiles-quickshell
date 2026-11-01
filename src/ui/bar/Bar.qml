pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../panels"
import Quickshell.Wayland
import Quickshell.Hyprland
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
      readonly property var monitor: Hyprland.monitors.values.find(output => output.name === modelData.name) ?? null
      readonly property int activeWorkspaceId: monitor?.activeWorkspace?.id ?? 0
      readonly property int specialWorkspaceId: monitor?.lastIpcObject.specialWorkspace?.id ?? 0
      readonly property bool emptyWorkspace: !!monitor && !WindowService.allWindows.some(client =>
          client.monitor === monitor.id && client.mapped !== false && client.hidden !== true
          && (client.pinned || client.workspace?.id === activeWorkspaceId
              || (specialWorkspaceId !== 0 && client.workspace?.id === specialWorkspaceId)))
      BarLayerState { id: layerState; screen: panelWindow.screen }
      BarVisibilityState {
        id: visibilityState
        enabled: BarVisibilityService.enabled
        screenName: panelWindow.modelData.name
        hovered: barHover.hovered
        attachmentOpen: layerState.overlay
        emptyWorkspace: panelWindow.emptyWorkspace
        showOnEmptyWorkspace: Config.barShowOnEmptyWorkspace
        hideDelay: Theme.barHideDelay
        Component.onCompleted: BarVisibilityService.register(visibilityState)
        Component.onDestruction: BarVisibilityService.unregister(visibilityState)
      }
      readonly property bool barShown: visibilityState.shown
      exclusiveZone: barShown ? implicitHeight : 0
      mask: Region {
        width: panelWindow.barShown && !panelWindow.islands ? panelWindow.width : 0
        height: panelWindow.barShown ? panelWindow.height : Theme.barRevealEdgeHeight
        Region { x: panelWindow.leftBounds.x; width: panelWindow.barShown ? panelWindow.leftBounds.width : panelWindow.width; height: panelWindow.barShown ? panelWindow.height : Theme.barRevealEdgeHeight; bottomRightRadius: panelWindow.barShown ? Theme.tooltipRadius : 0 }
        Region { x: panelWindow.centerBounds.x; width: panelWindow.barShown ? panelWindow.centerBounds.width : 0; height: panelWindow.height; bottomLeftRadius: Theme.tooltipRadius; bottomRightRadius: Theme.tooltipRadius }
        Region { x: panelWindow.rightBounds.x; width: panelWindow.barShown ? panelWindow.rightBounds.width : 0; height: panelWindow.height; bottomLeftRadius: Theme.tooltipRadius }
      }
      HoverHandler {
        id: barHover
        target: null
      }
      // Keep bar-attached overlays visually joined above fullscreen applications.
      WlrLayershell.layer: layerState.layer
      anchors {
        top: true
        left: true
        right: true
      }
      implicitHeight: Theme.barHeight

      Item {
        id: barBody
        width: parent.width
        height: parent.height
        y: panelWindow.barShown ? 0 : -height
        Behavior on y {
          enabled: UI.MotionPolicy.enabled
          NumberAnimation { duration: panelWindow.barShown ? Theme.barShowDuration : Theme.barHideDuration; easing.type: Easing.OutCubic }
        }
        Loader {
          active: Config.adaptiveBarEnabled
          sourceComponent: AdaptiveBarState { screen: panelWindow.screen; foregroundRoot: barBody }
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
