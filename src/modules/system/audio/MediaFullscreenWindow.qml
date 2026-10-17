pragma ComponentBehavior: Bound
import "../../../i18n"
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import "../../../services"
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../config"

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root
    readonly property bool requested: MediaFullscreenService.requested
    property real transitionProgress: 0
    readonly property bool transitioning: transitionAnimation.running || prepareTransition.running
    property bool preparingPlayerSlide: false
    readonly property bool slidingPlayer: playerSlideAnimation.running
    readonly property bool switchingPlayer: preparingPlayerSlide || slidingPlayer
    property int playerSlideDirection: 1
    property real playerSlideProgress: 1
    property var previousCardSnapshot: null
    property int playerSlideGeneration: 0
    property bool animationsEnabled: (UI.MotionPolicy.enabled)
        && Theme.mediaFullscreenAnimationDuration > 0
    readonly property bool hasSnapshot: !!MediaFullscreenService.snapshot?.url
    readonly property var geometryScreen: screen
    readonly property rect sourceRect: MediaFullscreenService.sourceRect.width > 0
        ? Qt.rect(MediaFullscreenService.sourceRect.x - (geometryScreen?.x ?? 0),
            MediaFullscreenService.sourceRect.y - (geometryScreen?.y ?? 0),
            MediaFullscreenService.sourceRect.width, MediaFullscreenService.sourceRect.height)
        : Qt.rect(width * 0.4, height * 0.4, width * 0.2, height * 0.2)
    readonly property rect transitionRect: Qt.rect(sourceRect.x * (1 - transitionProgress),
        sourceRect.y * (1 - transitionProgress), sourceRect.width + (width - sourceRect.width) * transitionProgress,
        sourceRect.height + (height - sourceRect.height) * transitionProgress)
    readonly property MediaFullscreenView card: contentLoader.item as MediaFullscreenView
    function dismiss() { MediaFullscreenService.close(); }
    function cancelPlayerSlide() {
        playerSlideGeneration++;
        playerSlideAnimation.stop();
        preparingPlayerSlide = false;
        playerSlideProgress = 1;
        previousCardSnapshot = null;
    }
    function navigate(direction) {
        if (!requested || transitionProgress !== 1 || switchingPlayer || MediaFullscreenService.players.length < 2) return;
        if (!animationsEnabled || Theme.mediaFullscreenSwitchDuration <= 0 || !card) {
            MediaFullscreenService.navigate(direction);
            return;
        }
        preparingPlayerSlide = true;
        const generation = ++playerSlideGeneration;
        const previousPlayer = MediaFullscreenService.player;
        const captured = snapshot => {
            if (generation !== playerSlideGeneration) return;
            if (!requested || !card || MediaFullscreenService.player !== previousPlayer) {
                preparingPlayerSlide = false;
                return;
            }
            if (!animationsEnabled || !snapshot) {
                preparingPlayerSlide = false;
                MediaFullscreenService.navigate(direction);
                return;
            }
            previousCardSnapshot = snapshot;
            playerSlideDirection = direction > 0 ? 1 : -1;
            playerSlideProgress = 0;
            playerSlideAnimation.start();
            preparingPlayerSlide = false;
            if (!MediaFullscreenService.navigate(direction)) cancelPlayerSlide();
        };
        // Capture once at native resolution; the outgoing view stays sharp without a second live renderer.
        const ratio = card.Screen.devicePixelRatio;
        if (!card.grabToImage(captured, Qt.size(Math.ceil(card.width * ratio), Math.ceil(card.height * ratio)))) captured(null);
    }
    UI.MotionAnimation {
        id: playerSlideAnimation
        objectName: "mediaFullscreenPlayerSlide"
        target: root
        property: "playerSlideProgress"
        from: 0
        to: 1
        animationDuration: Theme.mediaFullscreenSwitchDuration
        easing.type: Easing.OutCubic
        onFinished: root.previousCardSnapshot = null
    }
    function updateTransition() {
        transitionAnimation.stop();
        if (!requested && transitionProgress === 0) {
            MediaFullscreenService.finishClose();
            return;
        }
        if (animationsEnabled) {
            transitionAnimation.to = requested ? 1 : 0;
            transitionAnimation.restart();
        } else transitionProgress = requested ? 1 : 0;
        if (!requested && transitionProgress === 0) MediaFullscreenService.finishClose();
    }
    UI.MotionAnimation {
        id: transitionAnimation
        objectName: "mediaFullscreenTransition"
        target: root
        property: "transitionProgress"
        animationDuration: root.requested ? Theme.mediaFullscreenAnimationDuration : Math.min(300, Theme.mediaFullscreenAnimationDuration)
        easing.type: root.requested ? Easing.OutCubic : Easing.InCubic
    }
    Timer {
        id: prepareTransition
        interval: 16
        onTriggered: root.updateTransition()
    }
    onRequestedChanged: {
        if (!requested) cancelPlayerSlide();
        prepareTransition.stop();
        if (requested && animationsEnabled) prepareTransition.restart();
        else updateTransition();
    }
    onAnimationsEnabledChanged: {
        if (!animationsEnabled) cancelPlayerSlide();
        prepareTransition.stop();
        updateTransition();
    }
    onTransitionProgressChanged: {
        if (!requested && transitionProgress === 0) MediaFullscreenService.finishClose();
    }
    Component.onCompleted: if (requested && animationsEnabled) prepareTransition.restart(); else updateTransition()
    screen: Quickshell.screens.includes(MediaFullscreenService.targetScreen)
        ? MediaFullscreenService.targetScreen : Quickshell.screens[0] ?? null
    visible: MediaFullscreenService.visible
    onVisibleChanged: {
        if (visible) Qt.callLater(() => keys.forceActiveFocus());
        else {
            cancelPlayerSlide();
            transitionAnimation.stop();
            prepareTransition.stop();
            transitionProgress = 0;
            if (MediaFullscreenService.visible) MediaFullscreenService.forceClose();
        }
    }
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: Qt.alpha(Theme.alternateBackground, 1)
    mask: Region { width: root.requested ? root.width : 0; height: root.requested ? root.height : 0 }
    WlrLayershell.namespace: Config.mediaFullscreenNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: requested ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    FocusScope {
        id: keys
        anchors.fill: parent
        z: 10
        focus: true
        Shortcut {
            sequence: "Escape"
            enabled: root.visible
            onActivated: root.dismiss()
        }
        Shortcut {
            sequence: "Alt+F4"
            enabled: root.visible
            onActivated: root.dismiss()
        }
        Shortcut {
            sequence: "Left"
            enabled: root.requested && root.transitionProgress === 1 && MediaFullscreenService.players.length > 1
            onActivated: root.navigate(-1)
        }
        Shortcut {
            sequence: "Right"
            enabled: root.requested && root.transitionProgress === 1 && MediaFullscreenService.players.length > 1
            onActivated: root.navigate(1)
        }
        UI.ActionButton {
            id: closeButton
            objectName: "mediaFullscreenExit"
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: root.height * 0.02
            anchors.rightMargin: root.width * 0.02
            width: Theme.controlHeight
            height: width
            glyph: Theme.cancelIcon
            foreground: hovered || down ? Theme.foregroundOn(Theme.notificationCritical) : Theme.accent
            hint: Translations.text("media.fullscreen.exitHint")
            background: Rectangle {
                radius: width / 2
                antialiasing: true
                color: closeButton.down ? Qt.darker(Theme.notificationCritical, 1.2)
                    : closeButton.hovered ? Theme.notificationCritical : Theme.alternateBackground
                border.width: closeButton.visualFocus ? 1 : 0
                border.color: Theme.accent
            }
            onClicked: root.dismiss()
        }
        Row {
            objectName: "mediaFullscreenNavigation"
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: root.height * 0.02
            spacing: Theme.audioSpacing
            visible: MediaFullscreenService.players.length > 1
            enabled: root.requested && root.transitionProgress === 1 && !root.switchingPlayer
            AudioButton {
                objectName: "mediaFullscreenPreviousPlayer"
                glyph: Theme.chevronLeftIcon
                hint: Translations.text("media.actions.previousPlayerHint")
                onClicked: root.navigate(-1)
            }
            UI.ColumnText {
                anchors.verticalCenter: parent.verticalCenter
                text: (MediaFullscreenService.playerIndex + 1) + " / " + MediaFullscreenService.players.length
            }
            AudioButton {
                objectName: "mediaFullscreenNextPlayer"
                glyph: Theme.chevronRightIcon
                hint: Translations.text("media.actions.nextPlayerHint")
                onClicked: root.navigate(1)
            }
        }
    }
    Item {
        id: camera
        objectName: "mediaFullscreenCamera"
        anchors.fill: parent
        clip: true
        opacity: root.requested ? 1 : Math.min(1, root.transitionProgress * 5)
        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(root.width > 0 ? root.transitionRect.width / root.width : 1, 0, 0, root.transitionRect.x,
                0, root.height > 0 ? root.transitionRect.height / root.height : 1, 0, root.transitionRect.y,
                0, 0, 1, 0, 0, 0, 0, 1)
        }
        UI.ScaledImage {
            anchors.fill: parent
            source: MediaFullscreenService.snapshot?.url ?? ""
            fillMode: Image.Stretch
            opacity: root.requested && root.hasSnapshot ? Math.max(0, 1 - root.transitionProgress * 2) : 0
        }
        Loader {
            id: contentLoader
            objectName: "mediaFullscreenIncoming"
            width: parent.width
            height: parent.height
            x: root.slidingPlayer ? root.playerSlideDirection * width * (1 - root.playerSlideProgress) : 0
            active: root.visible
            opacity: root.requested && root.hasSnapshot ? Math.min(1, root.transitionProgress * 2) : 1
            sourceComponent: MediaFullscreenView {
                objectName: "mediaFullscreenCard"
                player: MediaFullscreenService.player
                audioService: MediaFullscreenService.audioService ?? AudioService
                mediaService: MediaFullscreenService.mediaService ?? MediaService
                enabled: !root.switchingPlayer
                monitorPosition: root.requested && root.transitionProgress === 1 && !root.slidingPlayer
            }
        }
        UI.ScaledImage {
            objectName: "mediaFullscreenOutgoing"
            width: parent.width
            height: parent.height
            x: -root.playerSlideDirection * width * root.playerSlideProgress
            source: root.previousCardSnapshot?.url ?? ""
            visible: !!root.previousCardSnapshot
            fillMode: Image.Stretch
            mipmap: false
        }
    }
}
