import QtQml

QtObject {
    property var nodes: []
    property var links: []
    readonly property var streams: collectStreams(nodes, links)

    function collectStreams(nodes, links) {
        return nodes.filter(node => node.properties?.["media.class"] === "Stream/Input/Video")
            .map(node => {
                const sources = links.filter(link => link.target === node).map(link => link.source)
                const camera = sources.some(source => source?.properties?.["media.role"] === "Camera"
                    || ["v4l2", "libcamera"].includes(source?.properties?.["device.api"]))
                if (camera) return null
                const props = node.properties ?? {}
                const source = sources[0]
                return {id: node.id,
                    description: source?.description || props["media.name"] || props["application.name"]
                        || props["application.process.binary"] || node.description || "Video capture"}
            }).filter(stream => stream !== null).sort((a, b) => a.description.localeCompare(b.description) || a.id - b.id)
    }
}
