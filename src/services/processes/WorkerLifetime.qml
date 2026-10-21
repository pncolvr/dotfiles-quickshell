pragma Singleton
import QtQml

// Qt destroys the shared script engine before singleton-owned WorkerScripts.
// WorkerScope releases registered owners while their engine is still alive.
QtObject {
    property var owners: []
    function register(owner) { owners = owners.concat([owner]) }
    function dispose() {
        const previous = owners; owners = []
        for (const owner of previous) if (Qt.isQtObject(owner)) owner.disposeWorker()
    }
}
