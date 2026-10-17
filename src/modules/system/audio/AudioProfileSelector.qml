pragma ComponentBehavior: Bound

import "../../../i18n"
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
    placeholder: Translations.text("audio.profile.choose")
    label: Translations.text("browser.profile.label", [selectedDescription])
    hint: Translations.text("audio.profile.hint")
    hintDelay: 700
    toggleObjectName: "profileToggle"
    choicesObjectName: "profileChoices"
    enabled: !audioService.profileBusy
    onSelected: name => audioService.setProfile(card, name)
}
