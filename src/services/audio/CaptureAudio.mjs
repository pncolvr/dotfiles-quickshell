// Classify local audio routes only; they do not prove what an app transmits.
export function captureStatus(captures, links, activeState) {
    let microphone = false, desktop = false;
    const active = links.filter(link => link.state === activeState);
    function visit(node, seen) {
        if (!node || seen.has(node) || node.audio?.muted === true) return;
        seen.add(node);
        const props = node.properties ?? {};
        const kind = props['media.class'];
        if (kind === 'Audio/Sink' || kind === 'Stream/Output/Audio') {
            desktop = true;
            return;
        }
        // A virtual source may mix microphone and desktop audio. Follow its
        // visible inputs rather than assuming every capture source is a mic.
        if (kind === 'Audio/Source' && ['alsa', 'bluez5', 'bluez'].includes(props['device.api'])) {
            microphone = true;
            return;
        }
        for (const link of active) if (link.target === node) visit(link.source, seen);
    }
    for (const capture of captures) {
        if (capture.audio?.muted === true) continue;
        visit(capture, new Set());
    }
    return microphone && desktop ? 'both' : desktop ? 'desktop' : microphone ? 'microphone' : 'unknown';
}
