import assert from 'node:assert/strict';
import {calibrate, composite, contrast} from '../../src/ui/components/ButtonColors.mjs';
const rgb = (hex, a = 1) => ({r:parseInt(hex.slice(1,3),16)/255, g:parseInt(hex.slice(3,5),16)/255, b:parseInt(hex.slice(5,7),16)/255, a});
for (const [background, hover, text] of [['#000000','#30343a','#d8dadc'], ['#fafbfc','#eceff3','#101418']]) {
    const base = rgb(background), reference = rgb(hover), foreground = rgb(text);
    assert.deepEqual(calibrate(base, base, reference, foreground), reference, 'default palette remains exact');
    for (const color of ['#07101a','#223348','#596052','#999999','#e6e1d8']) {
        const surface = rgb(color), value = calibrate(surface, base, reference);
        assert.ok(Math.abs(contrast(value, surface) - contrast(reference, base)) < 0.0001, 'active palette contrast follows the surface');
        assert.ok([value.r,value.g,value.b].every(channel => channel >= 0 && channel <= 1), 'channels stay within gamut');
        const readable = calibrate(surface, base, reference, foreground);
        assert.ok(contrast(readable,foreground) + 0.0001 >= Math.min(4.5,contrast(reference,foreground)), 'matching fill contrast never sacrifices readable text');
    }
    const clear = rgb('#000000', 0);
    assert.deepEqual(calibrate(rgb('#223348'), base, clear, foreground), clear, 'idle transparent buttons remain transparent');
    const translucent = rgb(hover, 0.6), surface = rgb('#4f5963');
    const value = calibrate(surface, base, translucent);
    assert.ok(Math.abs(contrast(value, surface) - contrast(composite(translucent, base), base)) < 0.0001, 'alpha is measured after compositing');
}
console.log('PASS: button colors retain active dark/light palette contrast, alpha compositing, transparent idle states and bounded channels');
