// Recording-specific data shaping; execution and lifecycle stay in the worker.
export function deviceRows(devices, cards, defaultName, defaultLabel = name => name) {
    if (!Array.isArray(devices) || !Array.isArray(cards) || !defaultName) throw new Error("recording.errors.readDevices")
    const disabled = cards.filter(card => card.active_profile === "off")
        .reduce((ids, card) => ids.concat([card.index, card.properties?.["object.id"]]), []).filter(id => id !== null && id !== undefined).map(String)
    return devices.filter(device => typeof device.name === "string" && device.name.length > 0
        && !disabled.includes(String(device.card ?? device.properties?.["device.id"] ?? ""))
        && device.properties?.["device.profile.name"] !== "off")
        .sort((a,b) => Number(b.name === defaultName) - Number(a.name === defaultName))
        .map(device => ({title: device.name === defaultName ? defaultLabel(device.description ?? device.name) : device.description ?? device.name,
            result: device.name, monitorSource: device.monitor_source ?? ""}))
}
// Hyprland client coordinates are logical; monitor dimensions need scale/rotation.
export function windowRegions(clients, monitors) {
    if (!Array.isArray(clients) || !Array.isArray(monitors) || !monitors.length)
        throw new Error("recording.errors.windows")
    const visible = new Set(monitors.reduce((ids,monitor) => ids.concat([monitor.activeWorkspace?.id, monitor.specialWorkspace?.id]), [])
        .filter(id => Number.isInteger(id) && id !== 0))
    const bounds = monitors.map(monitor => {
        const scale = monitor.scale ?? 1, transform = monitor.transform ?? 0
        if (![monitor.x,monitor.y,monitor.width,monitor.height,scale].every(Number.isFinite)
            || monitor.width <= 0 || monitor.height <= 0 || scale <= 0 || !Number.isInteger(transform))
            throw new Error("recording.errors.windows")
        return {x:monitor.x,y:monitor.y,
            w:Math.round((transform % 2 ? monitor.height : monitor.width) / scale),
            h:Math.round((transform % 2 ? monitor.width : monitor.height) / scale)}
    })
    return clients.filter(client => client.mapped !== false && client.hidden !== true
        && visible.has(client.workspace?.id) && Array.isArray(client.at) && Array.isArray(client.size)
        && client.at.length === 2 && client.size.length === 2 && [...client.at,...client.size].every(Number.isInteger)
        && client.size[0] > 0 && client.size[1] > 0).map(client => {
        const [x,y] = client.at, [w,h] = client.size
        const parts = bounds.map(monitor => ({left:Math.max(x,monitor.x),top:Math.max(y,monitor.y),
            right:Math.min(x+w,monitor.x+monitor.w),bottom:Math.min(y+h,monitor.y+monitor.h)}))
            .filter(part => part.right > part.left && part.bottom > part.top)
        if (!parts.length) return ""
        const left=Math.floor(Math.min(...parts.map(part => part.left))), top=Math.floor(Math.min(...parts.map(part => part.top)))
        const right=Math.ceil(Math.max(...parts.map(part => part.right))), bottom=Math.ceil(Math.max(...parts.map(part => part.bottom)))
        return `${left},${top} ${right-left}x${bottom-top}`
    }).filter(Boolean)
}
export function prepared(options, directory, encoderArguments, date = new Date()) {
    if (!directory || ![60,30,15].includes(Number(options.fps))) throw new Error("recording.errors.options")
    if (!Array.isArray(encoderArguments) || !encoderArguments.every(argument => typeof argument === "string"))
        throw new Error("recording.errors.encoderArguments")
    const command = ["wf-recorder", "--no-damage"]
    switch (options.capture) {
      case "output":
        if (!options.output) throw new Error("recording.errors.outputRequired")
        command.push("--output", options.output)
        break
      case "region":
      case "window":
        if (!/^-?[0-9]+,-?[0-9]+ [1-9][0-9]*x[1-9][0-9]*$/.test(options.geometry)) throw new Error("recording.errors.region")
        command.push("--geometry", options.geometry)
        break
      default: throw new Error("recording.errors.captureMode")
    }
    let audio = ""
    let loopback = []
    switch (options.audio) {
      case "none": break
      case "desktop":
      case "both":
        if (!options.outputDevice || !options.monitorSource) throw new Error("recording.errors.monitorSource")
        audio = options.monitorSource
        if (options.audio === "both") {
            if (!options.microphone) throw new Error("recording.errors.microphoneRequired")
            loopback = ["module-loopback", "source=" + options.microphone, "sink=" + options.outputDevice]
        }
        break
      case "mic":
        if (!options.microphone) throw new Error("recording.errors.microphoneRequired")
        audio = options.microphone
        break
      default: throw new Error("recording.errors.audioMode")
    }
    const pad = number => String(number).padStart(2,"0")
    const filename = directory.replace(/\/$/, "") + "/Recording " + date.getFullYear() + "-" + pad(date.getMonth()+1) + "-" + pad(date.getDate())
        + " at " + pad(date.getHours()) + "h" + pad(date.getMinutes()) + "m" + pad(date.getSeconds()) + "s.mp4"
    command.push(...encoderArguments, "--framerate", String(options.fps))
    if (audio) command.push("--audio=" + audio)
    command.push("-f", filename)
    return {filename, command, loopback}
}
