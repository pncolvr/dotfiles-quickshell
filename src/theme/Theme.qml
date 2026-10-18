pragma Singleton

import QtQuick
import "../services/time"

QtObject {
    id: root
    readonly property bool darkMode: true
    readonly property ThemePalette palette: ThemePalette { darkMode: root.darkMode }
    function foregroundOn(surface) { return palette.foregroundOn(surface, background, text) }

    // Colors
    readonly property color background: palette.colors.background
    readonly property color text: palette.colors.text
    readonly property color tooltipBackground: background
    readonly property color alternateBackground: palette.colors.alternateBackground
    readonly property color accent: palette.colors.accent
    readonly property color urgent: palette.colors.urgent
    readonly property color ok: palette.colors.ok
    readonly property color active: palette.colors.active
    readonly property color warning: palette.colors.warning
    readonly property color inactive: palette.colors.inactive
    readonly property color empty: palette.colors.empty

    // Typography
    readonly property string fontFamily: "Noto Sans Mono"
    readonly property string fontFamilyIcons: "Font Awesome 7 Free Solid"
    readonly property string fontStyle: "ExtraBold"
    readonly property int fontSize: 12
    readonly property int fontSizeWorkspaces: 13
    readonly property bool fontBold: true
    readonly property int fontWeight: Font.Bold
    readonly property int textRenderType: Text.NativeRendering
    readonly property int fontHintingPreference: Font.PreferFullHinting

    // Bar and shared controls
    readonly property int barHeight: 30
    readonly property int controlHeight: 34
    readonly property int actionButtonWidth: 30
    readonly property int controlSpacing: 6
    readonly property int controlFieldPadding: 8
    readonly property int moduleSpacing: 6 // Visible gap between bar modules, workspace glyphs and window labels.
    readonly property int groupedModuleSpacing: 10
    readonly property int iconButtonWidth: 18
    readonly property int iconButtonHeight: 22
    readonly property int iconButtonRadius: 3

    // Shared actions
    readonly property string downloadIcon: "" // download: install updates
    readonly property string notesIcon: "" // file-lines: update notes
    readonly property string addIcon: "" // plus
    readonly property string cancelIcon: "" // xmark
    readonly property string selectVisibleIcon: "" // square-check: select visible entries
    readonly property string openLinksIcon: "" // arrow-up-right-from-square: open links
    readonly property string checkIcon: "" // check: saved or selected
    readonly property string deleteIcon: "" // trash-can
    readonly property string upIcon: "" // arrow-up
    readonly property string downIcon: "" // arrow-down
    readonly property string rightIcon: "" // arrow-right
    readonly property string copyIcon: "" // copy
    readonly property string pasteIcon: "" // paste
    readonly property string imageIcon: "" // image
    readonly property string searchIcon: "" // magnifying-glass
    readonly property string filterIcon: "" // filter
    readonly property string disconnectIcon: "" // plug-circle-xmark: disconnect
    readonly property string clearIcon: "" // broom
    readonly property string editIcon: "" // pen
    readonly property string eyeIcon: "" // eye: reveal a secret
    readonly property string eyeSlashIcon: "" // eye-slash: mask a secret
    readonly property string folderOpenIcon: "" // folder-open: browse for a folder
    readonly property string lockIcon: "" // lock: lock the vault
    readonly property string refreshIcon: "" // arrows-rotate: refresh / sync
    readonly property string rotateIcon: refreshIcon
    readonly property string retryIcon: rotateIcon // arrows-rotate
    readonly property string chevronRightIcon: "" // chevron-right: collapsed
    readonly property string chevronLeftIcon: "" // chevron-left
    readonly property string chevronDownIcon: "" // chevron-down: expanded
    readonly property string playIcon: "" // play
    readonly property string pauseIcon: "" // pause
    readonly property string defaultIcon: "" // star
    readonly property string todayIcon: "" // calendar-day

    // Tooltips
    readonly property int panelOpenDuration: 150
    readonly property int panelCloseDuration: 100
    readonly property int panelResizeDuration: 160
    readonly property int tooltipWidth: 420
    readonly property real tooltipMaxHeightRatio: 0.6
    readonly property real tooltipCompactMaxHeightRatio: 0.5
    readonly property int tooltipHoverPaddingWidth: 1
    readonly property int tooltipHoverTolerance: 2
    readonly property int tooltipRadius: 12
    readonly property bool tooltipShadowEnabled: true
    readonly property color tooltipShadowColor: palette.colors.tooltipShadowColor
    readonly property real tooltipShadowOpacity: 0.5 // 0–1
    readonly property int tooltipShadowBlurRadius: 18 // Pixels, clamped to 2–64.
    readonly property real tooltipShadowHorizontalOffset: 0
    readonly property real tooltipShadowVerticalOffset: 6
    readonly property int tooltipPaddingWidth: 20
    readonly property int tooltipPaddingHeight: 10

    readonly property color selectionText: foregroundOn(accent)

    // Selection and scrollbars
    readonly property color selectionBackground: palette.colors.selectionBackground
    readonly property color selectionHoverBackground: palette.colors.selectionHoverBackground
    readonly property color selectionSelectedBackground: palette.colors.selectionSelectedBackground
    readonly property color selectionBorder: palette.colors.selectionBorder
    readonly property int selectionPopupPadding: 4
    readonly property int selectionAnimationDuration: 120
    readonly property int scrollbarWidth: 6
    readonly property int scrollbarHideDelay: 450
    readonly property int scrollbarFadeDuration: 200

    // Pulse appearance
    readonly property color pulsingTextBaseColor: text
    readonly property color pulsingTextPulseColor: urgent
    readonly property color screencastPulseColor: active
    readonly property color recordingPulseColor: urgent
    readonly property int pulsingTextDuration: Timespan.fromSeconds(2)

    // Launcher, QR and clipboard previews
    readonly property int pickerWidth: 560
    readonly property int pickerPreviewWidth: 1600
    readonly property real pickerPreviewListHeightRatio: 0.32
    readonly property int pickerPreviewGap: controlSpacing * 2
    readonly property int manageWidth: 780
    readonly property int manageHeight: 760
    readonly property FontMetrics manageRowFontMetrics: FontMetrics {
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        font.bold: root.fontBold
        font.styleName: root.fontStyle
        font.weight: root.fontWeight
    }
    readonly property int manageRowHeight: Math.ceil(manageRowFontMetrics.height) * 2 + pickerRowPadding * 2
    readonly property int qrPreviewSize: 360
    readonly property int imagePreviewFadeDuration: 140
    readonly property real pickerBackgroundOpacity: 0.85 // 0–1; text and controls stay opaque.
    readonly property int pickerRowHeight: 36
    readonly property int clipboardRowHeight: 52
    readonly property int clipboardImagePreviewHeight: 200
    readonly property int pickerRowPadding: 4
    readonly property int clipboardLayoutDuration: panelResizeDuration
    readonly property int pickerGridHeight: 52

    // Power menu
    readonly property string powerRebootIcon: rotateIcon
    readonly property string powerLockIcon: lockIcon
    readonly property string powerLogoutIcon: "" // sign-out
    readonly property string powerShutdownIcon: "" // power-off
    readonly property string powerBiosIcon: "" // shield: firmware setup

    // Project management
    readonly property int projectManagePadding: controlFieldPadding
    readonly property int projectManageSectionSpacing: controlSpacing * 2
    readonly property int projectOptionButtonWidth: 160

    // Window overview
    readonly property int exposeWorkspaceWidth: 156
    readonly property int exposeWorkspaceHeight: 100
    readonly property int exposeWorkspacePreviewHeight: 76
    readonly property int exposeWorkspaceIconSize: 44
    readonly property int exposeWorkspaceTopPadding: 12
    readonly property int exposeSearchWidth: 300
    readonly property int exposeDragWidth: 220
    readonly property int exposeDragAnimationDuration: 160
    readonly property int exposeRearrangeAnimationDuration: 250
    readonly property int exposeAnimationDuration: 300
    readonly property int exposeCardMinWidth: 280
    readonly property int exposeSpacing: 16
    readonly property real exposeBackdropOpacity: 0.45
    readonly property string exposeIcon: "" // Exposé: window grid

    // Workspaces and submaps
    readonly property int workspaceIconSize: 13
    readonly property var workspaceIcons: [
        "", // 1: globe — qutebrowser
        "", // 2: film — video / TV
        "", // 3: comment-dots — communication
        "", // 4: laptop-code — development
        "", // 5: gamepad — games
        "", // 6: screwdriver-wrench — tools
        "", // 7: book-open — reading
        "", // 8: cubes — game development
        "", // 9: compass — Vivaldi
        ""  // 10: desktop — remote desktop
    ]
    readonly property string workspaceUnknownIcon: "" // table-cells-large
    readonly property int submapWindowMaxWidth: 250

    // Calendar
    readonly property int calendarDayTooltipDelay: Timespan.fromSeconds(1)
    readonly property int calendarWidth: 225
    readonly property int calendarCellWidth: 26
    readonly property int calendarCellHeight: calendarCellWidth
    readonly property int calendarCellRadius: 3
    readonly property int calendarSpacing: 2
    readonly property color calendarTodayBackground: accent
    readonly property color calendarClockChangeEveBackground: warning
    readonly property color calendarHolidayBackground: active
    readonly property color calendarTodayText: foregroundOn(calendarTodayBackground)
    readonly property color calendarHolidayText: foregroundOn(calendarHolidayBackground)
    readonly property color calendarClockChangeEveText: foregroundOn(calendarClockChangeEveBackground)
    readonly property color calendarDayText: text
    readonly property color calendarHeaderText: inactive
    readonly property color calendarWeekNumberText: empty
    readonly property color calendarWeekendText: calendarDayText

    // Timers
    readonly property string timersIcon: ""
    readonly property int timersTooltipWidth: tooltipWidth
    readonly property real timersMaxHeightRatio: tooltipCompactMaxHeightRatio

    // Package updates
    readonly property string updatesIcon: ""
    readonly property int updatesTooltipWidth: 320
    readonly property real updatesTooltipMaxHeightRatio: tooltipCompactMaxHeightRatio
    readonly property color updatesUnchangedColor: palette.colors.updatesUnchangedColor

    // TOTP
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
    readonly property int totpExpiryWarning: 5
    readonly property color totpDeleteBackground: urgent
    readonly property color totpRowHoverBackground: alternateBackground

    // Batteries
    readonly property string batteryIcon: "" // battery-full: horizontal battery
    readonly property string batteryPlugIcon: "" // plug: connected to external power
    readonly property int batteryTooltipWidth: 340
    readonly property real batteryTooltipMaxHeightRatio: tooltipMaxHeightRatio // Fraction of the current screen height.
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
    readonly property color batteryEmptyColor: palette.colors.batteryEmptyColor
    readonly property color batteryBorderColor: inactive

    // Twitch
    readonly property string twitchIcon: ""
    readonly property color twitchColor: palette.colors.twitchColor
    readonly property int twitchInfoWidth: 200
    readonly property int twitchAvatarSize: 40
    readonly property int twitchTooltipSpacing: controlSpacing
    readonly property int twitchUserSpacing: 8
    readonly property int twitchEditorHeight: controlHeight
    readonly property int twitchEditorButtonWidth: actionButtonWidth
    readonly property int twitchSuggestionMinWidth: 200
    readonly property int twitchSuggestionMaxRows: 3
    readonly property real twitchTooltipMaxHeightRatio: tooltipCompactMaxHeightRatio

    // Audio devices and levels
    readonly property string micIcon: "" // microphone
    readonly property string micMutedIcon: "" // microphone-slash
    readonly property var volumeIcons: ["", "", ""] // volume-low, volume, volume-high
    readonly property string volumeMutedIcon: "" // volume-xmark: visibly muted even without a pulse
    readonly property string audioDefaultIcon: defaultIcon
    readonly property string audioRecordingIcon: "" // circle-dot: mic activity status
    readonly property int audioTooltipWidth: 520
    readonly property real audioTooltipMaxHeightRatio: tooltipMaxHeightRatio // Fraction of the current screen height.
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

    // Media
    readonly property string mediaPreviousIcon: "" // backward-step
    readonly property string mediaNextIcon: "" // forward-step
    readonly property string mediaStopIcon: "" // stop
    readonly property string mediaIcon: "" // music
    readonly property string mediaFlipIcon: rotateIcon // arrows-rotate
    readonly property string mediaExpandIcon: "" // expand
    readonly property int mediaFullscreenEffectListHeight: 520
    readonly property int mediaFullscreenAnimationDuration: exposeAnimationDuration
    readonly property int mediaFullscreenSwitchDuration: 240
    readonly property int mediaFullscreenCacheWidth: 960
    readonly property int mediaFullscreenCacheHeight: 540
    readonly property int mediaFlipDuration: 480
    readonly property int mediaVisualizerPoints: 64
    readonly property int mediaVisualizerInterval: 33
    readonly property real mediaVisualizerFrontOpacity: 0.45
    readonly property real mediaVisualizerBackOpacity: 0.9
    readonly property int mediaFallbackIconSize: 32
    readonly property int mediaArtworkBlurRadius: 64
    readonly property real mediaArtworkBackgroundTint: 0.5
    readonly property real mediaArtworkBackgroundOpacity: 0.65

    // Screencasting
    readonly property string screencastIcon: ""
    readonly property int screencastTooltipWidth: 380
    readonly property string recordingIcon: ""
    readonly property int recordingTooltipWidth: screencastTooltipWidth

    // System statistics and network
    readonly property string statsIcon: ""
    readonly property int statsTooltipWidth: tooltipWidth
    readonly property real statsTooltipMaxHeightRatio: tooltipMaxHeightRatio
    readonly property int statsPidWidth: 100
    readonly property int statsValueWidth: 80
    readonly property int statsTrafficWidth: 78
    readonly property int statsProcessRowHeight: 32
    readonly property int statsChildRowHeight: 28
    readonly property int statsProcessRowSpacing: 2
    readonly property var powerProfileIcons: ["", "", ""]
    readonly property string networkDownIcon: "" // arrow-down: download
    readonly property string networkUpIcon: upIcon // arrow-up: upload
    readonly property int networkGraphHeight: 40
    readonly property color networkDownColor: active
    readonly property color networkUpColor: warning

    // Status
    readonly property int statusBadgeRadius: 5
    readonly property int statusBadgePaddingWidth: 24
    readonly property int statusBadgePaddingHeight: 4
    readonly property string statusWorkingIcon:""
    readonly property string statusPersonalIcon:""
    readonly property string statusUnknownIcon:""
    readonly property int statusSessionRowHeight: 15
    readonly property int statusSessionRowSpacing: 2
    readonly property int statusTooltipWidth: tooltipWidth
    readonly property real statusTooltipMaxHeightRatio: tooltipMaxHeightRatio

    // Tray
    readonly property string trayIcon: "" // ellipsis: tray apps
    readonly property int trayItemWidth: 16
    readonly property int trayItemHeight: trayItemWidth
    readonly property color expandedBackground: alternateBackground
    readonly property int expandedBackgroundRadius: 4
    readonly property int expandedBackgroundPaddingWidth: 6
    readonly property int expandedBackgroundPaddingHeight: 3

    // Recent files
    readonly property string recentFilesIcon: "" // file-lines
    readonly property string filePinIcon: "" // thumbtack
    readonly property int recentFilesTooltipWidth: 440
    readonly property int recentFilesRowHeight: 58
    readonly property real recentFilesMaxHeightRatio: tooltipCompactMaxHeightRatio

    // Notifications
    readonly property string notificationsDndEnabledIcon: ""
    readonly property string notificationsDndDisabledIcon: ""
    readonly property string notificationsHistoryIcon: "" // clock-rotate-left: saved notification history
    readonly property string notificationsBlockedIcon: "" // ban: notification history disabled
    readonly property int notificationWidth: 500
    readonly property int notificationManagerWidth: 560
    readonly property int notificationRadius: 16
    readonly property int notificationStackMaxCards: 3
    readonly property int notificationStackPeekHeight: 6
    readonly property int notificationStackInset: 4
    readonly property int notificationSpacing: 12
    readonly property int notificationEnterDuration: 320
    readonly property int notificationExitDuration: 220
    readonly property int notificationMoveDuration: 220
    readonly property color notificationBackground: palette.colors.notificationBackground
    readonly property color notificationBorder: palette.colors.notificationBorder
    readonly property color notificationCritical: palette.colors.notificationCritical
    readonly property string notificationFont: fontFamily
}
