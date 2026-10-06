pragma Singleton

import Quickshell
import QtQml
import "../"

Singleton {
  id: root
  property bool showSeconds: PreferencesRepository.showSeconds
  onShowSecondsChanged: {
    if (showSeconds !== PreferencesRepository.showSeconds)
      PreferencesRepository.setShowSeconds(showSeconds)
  }

  Connections {
    target: PreferencesRepository
    function onShowSecondsChanged() { root.showSeconds = PreferencesRepository.showSeconds }
  }
  
  readonly property string time: {
    clock.date
  }

  SystemClock {
    id: clock
    precision: root.showSeconds ? SystemClock.Enum.Seconds : SystemClock.Enum.Minutes
  }
}
