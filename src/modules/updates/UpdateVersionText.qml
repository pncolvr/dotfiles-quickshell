import QtQuick
import "../../ui" as UI
import "../../theme"

UI.RightAlignedTooltipText {
    id: root
    required property string version
    required property string sharedPrefix
    required property color changeColor

    textFormat: Text.StyledText
    elide: Text.ElideMiddle
    color: Theme.updatesUnchangedColor
    cursorShape: Qt.PointingHandCursor
    text: '<font color="' + Theme.updatesUnchangedColor + '">' + escapeHtml(sharedPrefix) + '</font>'
        + '<font color="' + changeColor + '">' + escapeHtml(version.slice(sharedPrefix.length)) + '</font>'

    function escapeHtml(value) {
        return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }
}
