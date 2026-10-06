pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme"

Item {
    id: root
    required property string code
    property color color: Theme.text
    property bool animationsEnabled: true
    property font font: Qt.font({family: Theme.fontFamily, pixelSize: Theme.fontSize, bold: Theme.fontBold})
    readonly property bool spinning: spin.running
    property bool initialized: false
    property string previousCode: ""
    property string fromCode: ""
    property real progress: 1
    implicitWidth: code.length * digitMetrics.advanceWidth
        + Math.floor(Math.max(0, code.length - 1) / 3) * spaceMetrics.advanceWidth
    implicitHeight: digitMetrics.height

    function settle() {
        spin.stop()
        progress = 1
    }

    onCodeChanged: {
        if (!initialized) return
        const previous = previousCode
        previousCode = code
        settle()
        if (!animationsEnabled || !visible || previous === code || previous.length !== code.length
            || !/^\d{6,8}$/.test(previous) || !/^\d{6,8}$/.test(code)) return
        fromCode = previous
        progress = 0
        spin.start()
    }
    onAnimationsEnabledChanged: if (initialized && !animationsEnabled) settle()
    onVisibleChanged: if (initialized && !visible) settle()
    Component.onCompleted: {
        previousCode = code
        initialized = true
    }

    TextMetrics { id: digitMetrics; font: root.font; text: "0" }
    TextMetrics { id: spaceMetrics; font: root.font; text: " " }

    NumberAnimation {
        id: spin
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Theme.totpCodeSpinDuration
        easing.type: Easing.OutQuad
    }

    Row {
        anchors.fill: parent
        Repeater {
            model: root.code.length
            Item {
                id: reel
                required property int index
                readonly property real gap: index > 0 && index % 3 === 0 ? spaceMetrics.advanceWidth : 0
                readonly property int startDigit: Number(root.fromCode.charAt(index))
                readonly property int steps: (Number(root.code.charAt(index)) - startDigit + 10) % 10
                readonly property real position: root.spinning ? steps * root.progress : 0
                readonly property int offset: Math.floor(position)
                width: digitMetrics.advanceWidth + gap
                height: root.height
                clip: true

                Text {
                    id: currentDigit
                    objectName: "totpDigit_" + reel.index
                    x: reel.gap
                    y: -(reel.position - reel.offset) * reel.height
                    width: digitMetrics.advanceWidth
                    height: reel.height
                    text: root.spinning ? String((reel.startDigit + reel.offset) % 10) : root.code.charAt(reel.index)
                    textFormat: Text.PlainText
                    verticalAlignment: Text.AlignVCenter
                    font: root.font
                    color: root.color
                }
                Text {
                    x: reel.gap
                    y: currentDigit.y + reel.height
                    width: digitMetrics.advanceWidth
                    height: reel.height
                    visible: root.spinning
                    text: String((reel.startDigit + reel.offset + 1) % 10)
                    textFormat: Text.PlainText
                    verticalAlignment: Text.AlignVCenter
                    font: root.font
                    color: root.color
                }
            }
        }
    }
}
