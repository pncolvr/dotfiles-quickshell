import QtQuick
import ".."

ColumnText {
    id: root
    // Styled-text elision can leave spare width after the rendered text.
    transform: Translate { x: root.width - root.contentWidth }
}
