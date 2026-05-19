import QtQuick
import "../modules/clock"
import "../modules/media"
import "../modules/updates"

Row {
    // spacing: Theme.moduleSpacing
    spacing: 8
    Updates {}
    Clock {}
    Twitch {}
}