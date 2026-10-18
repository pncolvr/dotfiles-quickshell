pragma ComponentBehavior: Bound
import QtQuick
import "../../config"
import "../../i18n"
import "../../theme"
import ".." as UI

UI.ActionButton {
    id: root
    // The operation calls completed(true) once the clipboard write succeeds.
    property var copyAction: null
    property var copyContext: null
    property bool externallyConfirmed: false
    property string copyHint: Translations.text("common.actions.copy")
    property string copyGlyph: Theme.copyIcon
    property color normalForeground: Theme.foregroundOn(fillColor)
    property int feedbackDuration: Config.copyFeedbackDuration
    readonly property bool copied: externallyConfirmed || feedback.running
    property int generation: 0
    glyph: copied ? Theme.checkIcon : copyGlyph
    foreground: copied ? Theme.active : normalForeground
    hint: copied ? Translations.text("common.status.copied") : copyHint

    function resetFeedback() { generation++; feedback?.stop() }
    onCopyContextChanged: resetFeedback()
    onVisibleChanged: if (!visible) resetFeedback()
    onClicked: {
        resetFeedback()
        if (!copyAction) return
        const epoch = generation
        copyAction(success => {
            if (Qt.isQtObject(root) && root.visible && epoch === root.generation && success === true)
                feedback.restart()
        })
    }
    Timer { id: feedback; interval: Math.max(1, root.feedbackDuration) }
}
