pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Flickable {
    id: root
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
        width: root.width
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
            text: "No media players available. Other audio apps are in Apps."
            color: Theme.inactive
            wrapMode: Text.Wrap
        }
    }
    QC.ScrollBar.vertical: UI.ScrollBar {}
}
