pragma Singleton
pragma ComponentBehavior: Bound

import QtQml
import QtQml.WorkerScript

QtObject {
    id: root
    readonly property int maximumEntries: 64
    property var entries: ({})
    property var order: []
    property var queue: []
    property var pending: ({})
    property var active: null
    property int computations: 0
    property int sequence: 0
    property WorkerScript worker: null
    signal computed(string key, var result)
    signal retry(string key)

    function lookup(key) {
        const result = entries[key]
        if (result) order = order.filter(value => value !== key).concat([key])
        return result ?? null
    }
    function request(key, owner) {
        if (!key || entries[key] || pending[key]) return
        pending[key] = owner
        queue = queue.concat([{key, owner}])
        if (!active && !dispatch.running) dispatch.start()
    }
    function cancel(key, owner) {
        if (pending[key] !== owner) return
        delete pending[key]
        queue = queue.filter(job => job.key !== key || job.owner !== owner)
        if (active?.key === key && active.owner === owner) active = null
        if (!active && queue.length) dispatch.restart()
        Qt.callLater(() => root.retry(key))
    }
    function finish(key, owner, result) {
        if (pending[key] !== owner) return
        delete pending[key]
        entries[key] = result
        order = order.filter(value => value !== key).concat([key])
        while (order.length > maximumEntries) delete entries[order.shift()]
        computations++
        active = null
        computed(key, result)
        if (queue.length) dispatch.restart()
    }
    function submit(key, owner, pixels, width, height, started) {
        if (active?.key !== key || active.owner !== owner) return
        if (!worker) worker = workerFactory.createObject(root)
        worker.sendMessage({serial: active.serial, pixels, aspect: height > 0 ? width / height : 1, width, height})
        active.samplingMilliseconds = Date.now() - started
    }
    property Component workerFactory: Component {
        WorkerScript {
            source: "ImageCropWorker.mjs"
            onMessage: message => {
                if (root.active?.serial !== message.serial) return
                message.result.samplingMilliseconds = root.active.samplingMilliseconds
                root.finish(root.active.key, root.active.owner, message.result)
            }
        }
    }
    property Timer dispatch: Timer {
        // Spread a burst of avatar loads across frames; there is no idle timer.
        interval: 16
        onTriggered: {
            if (root.active) return
            while (root.queue.length) {
                const job = root.queue[0]
                root.queue = root.queue.slice(1)
                if (!Qt.isQtObject(job.owner) || typeof job.owner.analyzeImage !== "function") {
                    if (root.pending[job.key] === job.owner) delete root.pending[job.key]
                    Qt.callLater(() => root.retry(job.key))
                    continue
                }
                if (root.pending[job.key] !== job.owner) continue
                job.serial = ++root.sequence
                root.active = job
                job.owner.analyzeImage(job.key)
                return
            }
        }
    }
}
