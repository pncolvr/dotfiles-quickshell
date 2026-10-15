pragma Singleton

import QtQml
import Quickshell

Singleton {
    ElapsedTimer { id: clock; Component.onCompleted: restart() }

    function offset(duration) {
        return (clock.elapsed() * 1000 % duration) / duration
    }
}
