pragma ComponentBehavior: Bound
import "../../../i18n"
import QtQuick
import QtQuick.Controls as QC
import "../../../theme"
import "../../../ui" as UI
import "../../../services"

Flickable {
    id: root
    property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: root }
    property var mediaService: MediaService
    property var audioService: AudioService
    property real maximumHeight: 600
    readonly property var players: mediaService.players.filter(player => MediaService.showPlayer(player))
    implicitHeight: Math.min(contentHeight,maximumHeight)
    height: implicitHeight
    contentWidth: width
    contentHeight: contents.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    Column {
        id: contents
        width: Math.max(0, root.width - Theme.scrollbarGutter)
        spacing: Theme.audioSpacing
        Repeater {
            objectName: "mediaPlayers"
            model: root.players
            delegate: MediaPlayerCard {
                id: card
                required property var modelData
                objectName: "mediaPlayer_" + modelData.dbusName
                width: contents.width
                player: modelData
                audioService: root.audioService
                mediaService: root.mediaService
                monitorPosition: root.visible && card.y + card.height > root.contentY && card.y < root.contentY + root.height
            }
        }
        UI.ColumnText {
            width: parent.width
            visible: root.players.length === 0
            text: Translations.text("media.empty.players")
            color: Theme.inactive
            wrapMode: Text.Wrap
        }
    }
    QC.ScrollBar.vertical: UI.ScrollBar {}
}
