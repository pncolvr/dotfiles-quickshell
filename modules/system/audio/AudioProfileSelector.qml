pragma ComponentBehavior: Bound

import QtQuick
import "../../../services"

AudioSelector {
    id: root
    property var card: null
    property var audioService: AudioService
    readonly property var profiles: card?.profiles ?? []
    readonly property string activeDescription: selectedDescription
    options: profiles
    selectedName: card?.activeProfile ?? ""
    placeholder: "Choose a profile"
    labelPrefix: "Profile: "
    hint: "Profiles affect both playback and microphone availability."
    hintDelay: 700
    toggleObjectName: "profileToggle"
    choicesObjectName: "profileChoices"
    enabled: !audioService.profileBusy
    onSelected: name => audioService.setProfile(card, name)
}
