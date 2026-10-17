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
