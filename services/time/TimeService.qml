pragma Singleton

import Quickshell
import QtQuick

Singleton {
  id: root
  property bool showSeconds:false
  
  readonly property string time: {
    clock.date
  }

  SystemClock {
    id: clock
    precision: root.showSeconds ? SystemClock.Enum.Seconds : SystemClock.Enum.Minutes
  }
}