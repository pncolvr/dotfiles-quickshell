import QtQml
import Quickshell

// Use for entry points (including fixtures) that can load background workers.
Scope {
    Component.onDestruction: WorkerLifetime.dispose()
}
