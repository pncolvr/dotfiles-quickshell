pragma Singleton

import QtQuick
import "../config"
import "../services"

Item {
  // colors
  readonly property color background:Qt.rgba(0,0,0,1)
  // readonly property color background:'#222225'
  readonly property color text:"#d8dadc"

  // readonly property color background:Qt.rgba(0,0,0,0.9)
  // readonly property color background:"#000000"
  readonly property color tooltipBackground: background
  readonly property color alternateBackground: "#be1b1a1a"
  readonly property color accent: "#6B8FB3"
  readonly property color urgent: "#B80F0A"
  readonly property color ok: "#3E8E5A"
  readonly property color active: "#5C9E7E"
  readonly property color warning: "#fd6d37"
  readonly property color inactive: "#b0b3b8"
  readonly property color empty: "#8080804d"
  // pulsing text
  readonly property color pulsingTextBaseColor: text
  readonly property color pulsingTextPulseColor: urgent
  readonly property color screencastPulseColor: active
  readonly property int pulsingTextDuration: Timespan.fromSeconds(2)
  readonly property int calendarDayTooltipDelay: Timespan.fromSeconds(1)
  property real pulsePhase: 0

  SequentialAnimation on pulsePhase {
    loops: Animation.Infinite
    running: AudioService.muted || AudioService.micMuted || AudioService.screencastActive
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

  readonly property int tooltipHoverPaddingWidth: 1
  readonly property int tooltipHoverTolerance: 2
  readonly property int tooltipBridgeHeight: 10
  readonly property int tooltipRadius: 12
  readonly property bool tooltipShadowEnabled: true
  readonly property color tooltipShadowColor: "black"
  readonly property real tooltipShadowOpacity: 0.5 // 0–1
  readonly property int tooltipShadowBlurRadius: 18 // Pixels, clamped to 2–64.
  readonly property real tooltipShadowHorizontalOffset: 0
  readonly property real tooltipShadowVerticalOffset: 6
  readonly property int tooltipPaddingWidth: 20
  readonly property int tooltipPaddingHeight: 10
  readonly property int tooltipMinWidth: 80

  // Shared actions (Font Awesome).
  readonly property string addIcon: "" // plus
  readonly property string cancelIcon: "" // xmark
  readonly property string checkIcon: "" // check: saved or selected
  readonly property string deleteIcon: "" // trash-can
  readonly property string upIcon: "" // arrow-up
  readonly property string rightIcon: "" // arrow-right
  readonly property string copyIcon: "" // copy
  readonly property string editIcon: "" // pen
  readonly property string refreshIcon: "" // refresh
  readonly property string retryIcon: "" // arrows-rotate
  readonly property string chevronRightIcon: "\uf054" // chevron-right: collapsed
  readonly property string chevronDownIcon: "" // chevron-down: choices
  readonly property string playIcon: "" // play
  readonly property string pauseIcon: "\uf04c" // pause

  // Countdowns and elapsed timers (Font Awesome stopwatch).
  readonly property string timersIcon: "\uf2f2"
  readonly property int timersTooltipWidth: 420
  readonly property real timersMaxHeightRatio: 0.5

  readonly property int controlHeight: 34
  readonly property int actionButtonWidth: 30
  readonly property int controlSpacing: 6
  readonly property int controlFieldPadding: 8
  readonly property int pickerWidth: 560
  readonly property real pickerBackgroundOpacity: 0.7 // 0–1; text and controls stay opaque.
  readonly property int pickerRowHeight: 36
  readonly property int clipboardRowHeight: 52
  readonly property int clipboardImagePreviewHeight: 200
  readonly property int pickerRowPadding: 4
  readonly property int pickerGridHeight: 52
  readonly property int scrollbarWidth: 6
  readonly property int scrollbarHideDelay: 450
  readonly property int scrollbarFadeDuration: 200

  readonly property var calendarMonthNames: ["january","february","march","april","may","june","july","august","september","october","november","december"]
  readonly property var calendarDayNames: ["mo","tu","we","th","fr","sa","su"]
  readonly property int calendarWidth: 225
  readonly property int calendarCellWidth: 26
  readonly property int calendarCellHeight: 26
  readonly property int calendarCellRadius: 3
  readonly property int calendarSpacing: 2

  readonly property color calendarTodayBackground: accent
  readonly property color calendarTodayText: text
  readonly property color calendarDayText: text
  readonly property color calendarHeaderText: inactive
  readonly property color calendarWeekNumberText: empty
  readonly property color calendarWeekendText: calendarDayText

  readonly property string updatesIcon: ""
  readonly property int updatesTooltipWidth: 320
  readonly property real updatesTooltipMaxHeightRatio: 0.5
  readonly property color updatesUnchangedColor: "#62666b"

  // TOTP (Font Awesome icons)
  readonly property string totpIcon: ""
  readonly property int totpTooltipWidth: 380
  readonly property int totpRowHeight: controlHeight
  readonly property int totpSpacing: controlSpacing
  readonly property int totpFooterMargin: 8
  readonly property int totpButtonWidth: actionButtonWidth
  readonly property int totpCodeWidth: 126
  readonly property int totpCodeSpinDuration: 1000
  readonly property int totpCountdownHeight: 20
  readonly property int totpCountdownTextWidth: 20
  readonly property int totpCountdownStrokeWidth: 4
  readonly property int totpCountdownListMargin: 12
  readonly property int totpFieldPadding: controlFieldPadding
  readonly property int totpExpiryWarning: 5
  readonly property color totpDeleteBackground: urgent
  readonly property color totpRowHoverBackground: alternateBackground

  // Batteries (Font Awesome: glyphs kept visible, with their icon names)
  readonly property string batteryIcon: "" // battery-full: horizontal battery
  readonly property string batteryPlugIcon: "" // plug: connected to external power
  readonly property int batteryTooltipWidth: 340
  readonly property real batteryTooltipMaxHeightRatio: 0.6 // Fraction of the current screen height.
  readonly property int batteryRowHeight: 66
  readonly property int batterySpacing: 8
  readonly property int batteryTextSpacing: 4
  readonly property int batteryPadding: 8
  readonly property int batteryRadius: 6
  readonly property int batteryTerminalWidth: 6
  readonly property int batteryTerminalHeight: 14
  readonly property int batteryPercentageFontSize: 16
  readonly property var batteryLevelColors: ({ "normal": ok, "low": warning, "critical": urgent })
  readonly property real batteryFillOpacity: 0.5
  readonly property color batteryEmptyColor: "#232323"
  readonly property color batteryBorderColor: inactive

  readonly property string twitchIcon: ""
  readonly property color twitchColor: "#A970FF"

  readonly property int twitchInfoWidth: 200
  readonly property int twitchAvatarSize: 40
  readonly property int twitchTooltipSpacing: controlSpacing
  readonly property int twitchUserSpacing: 8
  readonly property int twitchRemoveButtonSize: 24
  readonly property int twitchEditorHeight: controlHeight
  readonly property int twitchEditorButtonWidth: actionButtonWidth
  readonly property int twitchSuggestionMinWidth: 200
  readonly property int twitchSuggestionMaxRows: 3
  readonly property real twitchTooltipMaxHeightRatio: 0.5

  
  // modules
  readonly property int moduleSpacing: 5
  readonly property int groupedModuleSpacing: 16
  readonly property int iconButtonWidth: 18
  readonly property int iconButtonHeight: 22
  readonly property int iconButtonRadius: 3
  // workspaces
  readonly property int workspaceSpacing: 3
  readonly property var workspaceIcons: ["", playIcon, "", "", "", "", "", "#", "", ""]
  readonly property string workspaceUnknownIcon: "#"
  
  // submap
  readonly property int submapWindowMaxWidth: 250
  readonly property int statusBadgeRadius: 5
  readonly property int statusBadgePaddingWidth: 24
  readonly property int statusBadgePaddingHeight: 4

  // screencast
  readonly property string screencastIcon: ""

  // Audio (Font Awesome: visible glyphs with readable icon names)
  readonly property string micIcon: "" // microphone
  readonly property string micMutedIcon: "" // microphone-slash
  readonly property var volumeIcons: ["", "", ""] // volume-low, volume, volume-high
  readonly property string volumeMutedIcon: "" // volume-off
  readonly property string defaultIcon: "" // star
  readonly property string audioDefaultIcon: defaultIcon
  readonly property string audioRecordingIcon: "" // circle-dot: mic activity status
  readonly property int audioTooltipWidth: 520
  readonly property real audioTooltipMaxHeightRatio: 0.6 // Fraction of the current screen height.
  readonly property int audioSpacing: 8
  readonly property int audioDevicePadding: 12
  readonly property int audioDeviceRadius: 8
  readonly property int audioButtonHeight: 30
  readonly property int audioButtonPadding: 10
  readonly property int audioSliderTrackHeight: 4
  readonly property int audioSliderHandleSize: 14
  readonly property int audioPercentageWidth: 46
  readonly property int audioProfileRowHeight: 44
  readonly property int audioProfileMaxVisibleRows: 5
  readonly property int audioAppSelectorWidth: 320
  readonly property int audioAppOptionRowHeight: 36
  
  // stats
  readonly property string statsIcon: ""
  readonly property int statsTooltipWidth: 420
  readonly property real statsTooltipMaxHeightRatio: 0.6
  readonly property int statsPidWidth: 100
  readonly property int statsValueWidth: 80
  readonly property int statsTrafficWidth: 78
  readonly property int statsProcessRowHeight: 32
  readonly property int statsChildRowHeight: 28
  readonly property int statsProcessRowSpacing: 2
  readonly property var powerProfileIcons: ["", "", ""]

  // network tooltip
  readonly property string networkIcon: ""
  readonly property int networkGraphHeight: 40
  readonly property color networkDownColor: active
  readonly property color networkUpColor: warning
  
  // status
  readonly property string statusWorkingIcon:""
  readonly property string statusPersonalIcon:""
  readonly property string statusUnknownIcon:""
  readonly property int statusTooltipWidth: 420
  readonly property real statusTooltipMaxHeightRatio: 0.6
  // tray
  readonly property string trayOpenIcon: ""
  readonly property string trayClosedIcon: ""
  readonly property int trayItemWidth: 16
  readonly property int trayItemHeight: 16
  readonly property color expandedBackground: alternateBackground
  readonly property int expandedBackgroundRadius: 4
  readonly property int expandedBackgroundPaddingWidth: 6
  readonly property int expandedBackgroundPaddingHeight: 3

  // recent files
  readonly property string recentFilesIcon: "" // file-lines
  readonly property string filePinIcon: "" // thumbtack
  readonly property int recentFilesTooltipWidth: 440
  readonly property int recentFilesRowHeight: 58
  readonly property real recentFilesMaxHeightRatio: 0.5

  // notifications
  readonly property string notificationsDndEnabledIcon: ""
  readonly property string notificationsDndDisabledIcon: ""
  readonly property int notificationWidth: 500
  readonly property int notificationManagerWidth: 560
  readonly property int notificationRadius: 16
  readonly property int notificationStackMaxCards: 3
  readonly property int notificationStackPeekHeight: 6
  readonly property int notificationStackInset: 4
  readonly property int notificationSpacing: 12
  readonly property color notificationBackground: Qt.rgba(33 / 255, 34 / 255, 44 / 255, 0.95)
  readonly property color notificationBorder: "#2a2d38"
  readonly property color notificationCritical: "#d32f2f"
  readonly property string notificationFont: "JetBrains Mono"
}
