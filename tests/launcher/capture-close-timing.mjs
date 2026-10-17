import assert from 'node:assert/strict'
import {milliseconds} from '../../src/services/ui/CaptureCloseTiming.mjs'
const state = {
    enabled:{bool:true}, monitors:[{refreshRate:144}],
    animations:[[
        {name:'global',overridden:true,enabled:true,speed:1,bezier:'default'},
        {name:'layersOut',overridden:false,speed:0},
        {name:'fadeLayersOut',overridden:false,speed:0}
    ],[]]
}
assert.equal(milliseconds(state),107,'inherited layer close plus one compositor frame')
state.animations[0].push({name:'layers',overridden:true,enabled:true,speed:3,bezier:'default'})
assert.equal(milliseconds(state),307,'longer inherited layer motion')
const fade = state.animations[0].find(row => row.name === 'fadeLayersOut')
Object.assign(fade,{overridden:true,enabled:true,speed:5,bezier:'default'})
assert.equal(milliseconds(state),507,'longer fade completion controls readiness')
state.enabled.bool = false
assert.equal(milliseconds(state),7,'disabled animations only wait for display clearing')
state.monitors.push({refreshRate:60})
assert.equal(milliseconds(state),17,'slowest output frame is respected')
assert.throws(()=>milliseconds({}),/enable/)
state.enabled.bool=true; fade.bezier='spring:custom'
assert.throws(()=>milliseconds(state),/Spring/,'unavailable timing must not start capture prematurely')
console.log('PASS: compositor close timing inheritance, enabled state, fade/motion duration and output clearing')
