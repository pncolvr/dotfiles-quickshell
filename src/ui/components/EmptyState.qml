import QtQuick
import "../../theme"

ColumnText {
    width: parent ? parent.width : implicitWidth
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
    color: Theme.inactive
}
