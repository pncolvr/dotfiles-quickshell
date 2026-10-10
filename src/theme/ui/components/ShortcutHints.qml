import QtQuick
import "../../"
import "../" as UI

UI.Text {
    property string hints: ""
    centerVertical: false
    font.pixelSize: Theme.fontSize - 1
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    color: Theme.inactive
    // Wrap between actions, keeping each shortcut and its description together.
    text: hints.split("\n").map(line => line.split(" · ")
        .map(action => action.replace(/ /g,"\u00a0")).join(" · ")).join("\n")
}
