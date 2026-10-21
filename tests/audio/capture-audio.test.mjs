import assert from 'node:assert/strict';
import test from 'node:test';
import {captureStatus} from '../../src/services/audio/CaptureAudio.mjs';

const active = 6;
const node = (kind, props = {}, muted = false) => ({properties:{'media.class':kind,...props},audio:{muted}});
const link = (source, target, state = active) => ({source,target,state});

test('microphone capture requires an active, unmuted hardware-input route', () => {
    const mic = node('Audio/Source', {'device.api':'alsa'}), capture = node('Stream/Input/Audio');
    assert.equal(captureStatus([capture],[link(mic,capture)],active),'microphone');
    assert.equal(captureStatus([capture],[link(mic,capture,5)],active),'unknown');
    capture.audio.muted = true;
    assert.equal(captureStatus([capture],[link(mic,capture)],active),'unknown');
    capture.audio.muted = false; mic.audio.muted = true;
    assert.equal(captureStatus([capture],[link(mic,capture)],active),'unknown');
});
test('output-monitor and direct application-audio capture are desktop audio', () => {
    const capture = node('Stream/Input/Audio');
    for (const kind of ['Audio/Sink','Stream/Output/Audio'])
        assert.equal(captureStatus([capture],[link(node(kind),capture)],active),'desktop');
});
test('independent microphone and desktop routes report both', () => {
    const mic = node('Audio/Source', {'device.api':'bluez5'}), desktop = node('Audio/Sink');
    const first = node('Stream/Input/Audio'), second = node('Stream/Input/Audio');
    assert.equal(captureStatus([first,second],[link(mic,first),link(desktop,second)],active),'both');
    assert.equal(captureStatus([first,second],[link(mic,first)],active),'microphone');
});
test('virtual sources follow visible upstream routes and cycles terminate', () => {
    const mic = node('Audio/Source', {'device.api':'alsa'}), mix = node('Audio/Source');
    const capture = node('Stream/Input/Audio');
    assert.equal(captureStatus([capture],[link(mix,capture)],active),'unknown');
    assert.equal(captureStatus([capture],[link(mic,mix),link(mix,capture)],active),'microphone');
    assert.equal(captureStatus([capture],[link(mix,capture),link(capture,mix)],active),'unknown');
    assert.equal(captureStatus([],[],active),'unknown');
});
