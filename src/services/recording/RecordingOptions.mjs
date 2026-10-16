// Recording-specific data shaping; execution and lifecycle stay in the worker.
export function deviceRows(devices, cards, defaultName) {
    if (!Array.isArray(devices) || !Array.isArray(cards) || !defaultName) throw new Error("Could not read audio devices")
    const disabled = cards.filter(card => card.active_profile === "off")
        .reduce((ids, card) => ids.concat([card.index, card.properties?.["object.id"]]), []).filter(id => id !== null && id !== undefined).map(String)
    return devices.filter(device => typeof device.name === "string" && device.name.length > 0
        && !disabled.includes(String(device.card ?? device.properties?.["device.id"] ?? ""))
        && device.properties?.["device.profile.name"] !== "off")
        .sort((a,b) => Number(b.name === defaultName) - Number(a.name === defaultName))
        .map(device => ({title: (device.description ?? device.name) + (device.name === defaultName ? " (default)" : ""),
            result: device.name, monitorSource: device.monitor_source ?? ""}))
}
export function prepared(options, directory, encoderArguments, date = new Date()) {
    if (!directory || ![60,30,15].includes(Number(options.fps))) throw new Error("Invalid recording options")
    if (!Array.isArray(encoderArguments) || !encoderArguments.every(argument => typeof argument === "string"))
        throw new Error("Invalid recording encoder arguments")
    const command = ["wf-recorder", "--no-damage"]
    switch (options.capture) {
      case "output":
        if (!options.output) throw new Error("Choose an output")
        command.push("--output", options.output)
        break
      case "region":
        if (!/^-?[0-9]+,-?[0-9]+ [1-9][0-9]*x[1-9][0-9]*$/.test(options.geometry)) throw new Error("Invalid recording region")
        command.push("--geometry", options.geometry)
        break
      default: throw new Error("Invalid capture mode")
    }
    let audio = ""
    let loopback = []
    switch (options.audio) {
      case "none": break
      case "desktop":
      case "both":
        if (!options.outputDevice || !options.monitorSource) throw new Error("Audio output has no monitor source")
        audio = options.monitorSource
        if (options.audio === "both") {
            if (!options.microphone) throw new Error("Choose a microphone")
            loopback = ["module-loopback", "source=" + options.microphone, "sink=" + options.outputDevice]
        }
        break
      case "mic":
        if (!options.microphone) throw new Error("Choose a microphone")
        audio = options.microphone
        break
      default: throw new Error("Invalid audio mode")
    }
    const pad = number => String(number).padStart(2,"0")
    const filename = directory.replace(/\/$/, "") + "/Recording " + date.getFullYear() + "-" + pad(date.getMonth()+1) + "-" + pad(date.getDate())
        + " at " + pad(date.getHours()) + "h" + pad(date.getMinutes()) + "m" + pad(date.getSeconds()) + "s.mp4"
    command.push(...encoderArguments, "--framerate", String(options.fps))
    if (audio) command.push("--audio=" + audio)
    command.push("-f", filename)
    return {filename, command, loopback}
}
