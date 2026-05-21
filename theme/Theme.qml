pragma Singleton

import QtQuick
import "../config"

Item {
  // colors
  // readonly property color background:Qt.rgba(0,0,0,0.9)
  readonly property color background:"#000000"
  readonly property color text:"#d8dadc"

  // readonly property color background:Qt.rgba(0,0,0,0.9)
  // readonly property color background:"#000000"
  readonly property color tooltipBackground: background
  readonly property color accent: "#6272a4"
  readonly property color urgent: "#B80F0A"
  readonly property color ok: "#3E8E5A"
  readonly property color active: "#5C9E7E"
  readonly property color warning: "#FE8D59"
  readonly property color inactive: "#999999"
  readonly property color empty: "#8080804d"
  // pulsing text
  readonly property color pulsingTextBaseColor: text
  readonly property color pulsingTextPulseColor: urgent
  readonly property color screencastPulseColor: active
  readonly property int pulsingTextDuration: Timespan.fromSeconds(2)
  readonly property int calendarDayTooltipDelay: Timespan.fromSeconds(2)
  property real pulsePhase: 0

  SequentialAnimation on pulsePhase {
    loops: Animation.Infinite
    running: true
    NumberAnimation { from: 0; to: 1; duration: Theme.pulsingTextDuration / 2; easing.type: Easing.InOutSine }
    NumberAnimation { from: 1; to: 0; duration: Theme.pulsingTextDuration / 2; easing.type: Easing.InOutSine }
  }
  // typography
  readonly property string fontFamily: "Noto Sans Mono"
  // readonly property string fontFamily: "Noto Sans"
  // readonly property string fontFamily: "JetBrains Mono"
  // readonly property string fontFamily: "DejaVu Sans"
  // readonly property string fontFamily: "Cantarell"
  readonly property string fontFamilyIcons: "Font Awesome 7 Free Solid"
  readonly property string fontStyle: "ExtraBold"
  readonly property int fontSize: 12
  readonly property int fontSizeWorkspaces: 13
  readonly property bool fontBold: true
  readonly property int fontWeight: Font.Bold
  // style
  // readonly property int barHeight: 25
  readonly property int barHeight: 30

  readonly property int tooltipBridgeHeight: 10
  readonly property int tooltipRadius: 12
  readonly property int tooltipPaddingWidth: 20
  readonly property int tooltipPaddingHeight: 10
  readonly property int tooltipMinWidth: 80

  readonly property var calendarMonthNames: ["january","february","march","april","may","june","july","august","september","october","november","december"]
  readonly property var calendarDayNames: ["mo","tu","we","th","fr","sa","su"]
  readonly property int calendarWidth: 225
  readonly property int calendarCellWidth: 26
  readonly property int calendarCellHeight: 26
  readonly property int calendarCellRadius: 13
  readonly property int calendarSpacing: 2

  readonly property color calendarTodayBackground: accent
  readonly property color calendarTodayText: text
  readonly property color calendarDayText: text
  readonly property color calendarHeaderText: inactive
  readonly property color calendarWeekNumberText: empty
  readonly property color calendarWeekendText: calendarDayText

  readonly property string updatesIcon: ""
  readonly property int updatesTooltipWidth: 250

  readonly property string twitchIcon: ""
  readonly property color twitchColor: "#A970FF"

  readonly property int twitchInfoWidth: 200
  readonly property int twitchAvatarSize: 40
  readonly property int twitchTooltipSpacing: 6

  readonly property int cpuTooltipLabelWidth: 60
  readonly property int cpuTooltipValueWidth: 40
  
  readonly property int memoryTooltipWidth: 200
  readonly property var memoryTooltipMemColors: [ok, warning, urgent]
  readonly property var memoryTooltipSwapColors: [urgent]
  readonly property color memoryTooltipMemFreeColor: empty
  readonly property color memoryTooltipSwapFreeColor: empty
  // modules
  readonly property int moduleSpacing: 5
  readonly property int iconButtonWidth: 18
  readonly property int iconButtonHeight: 22
  readonly property int iconButtonRadius: 3
  // workspaces
  readonly property int workspaceSpacing: 3
  readonly property var workspaceIcons: ["", "", "", "", "", "", "", "#", "", ""]
  readonly property string workspaceUnknownIcon: "#"
  
  // submap
  readonly property int submapWindowMaxWidth: 250
  readonly property int statusBadgeRadius: 5
  readonly property int statusBadgePaddingWidth: 24
  readonly property int statusBadgePaddingHeight: 4

  // screencast
  readonly property string screencastIcon: ""

  // audio
  readonly property string micIcon: ""
  readonly property string micMutedIcon: ""
  // readonly property var volumeIcons: ["", "", "", ""]
  readonly property var volumeIcons: ["", "", ""]
  // readonly property string volumeMutedIcon: ""
  readonly property string volumeMutedIcon: ""
  
  // stats
  readonly property string statsToggleIcon: ""
  readonly property var powerProfileIcons: ["", "", ""]

  // network tooltip
  readonly property string networkIcon: ""
  readonly property int networkTooltipWidth: 220
  readonly property int networkGraphHeight: 40
  readonly property int networkTooltipLabelWidth: 120
  readonly property color networkDownColor: active
  readonly property color networkUpColor: warning
  
  // status
  readonly property string statusWorkingIcon:""
  readonly property string statusPersonalIcon:""
  readonly property string statusUnknownIcon:""
  // tray
  readonly property string trayOpenIcon: ""
  readonly property string trayClosedIcon: ""
  readonly property int trayItemWidth: 16
  readonly property int trayItemHeight: 16
  readonly property color trayBackground: empty
  readonly property int trayBackgroundRadius: 4
  readonly property int trayBackgroundPaddingH: 6
  readonly property int trayBackgroundPaddingV: 3

  // notifications
  readonly property string notificationsDndEnabledIcon: ""
  readonly property string notificationsDndDisabledIcon: ""
}