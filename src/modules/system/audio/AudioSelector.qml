import "../../../theme"
import "../../../ui" as UI

// Audio dropdowns share the project-wide selector, preserving their existing dimensions.
UI.ComboSelector {
    controlHeight: Theme.audioButtonHeight
    contentPadding: Theme.audioButtonPadding
    optionRowHeight: compact ? Theme.audioAppOptionRowHeight : Theme.audioProfileRowHeight
    maxVisibleRows: Theme.audioProfileMaxVisibleRows
    spacing: Theme.audioSpacing
}
