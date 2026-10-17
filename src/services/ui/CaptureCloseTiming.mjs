// hyprutils CBaseAnimatedVariable::getPercent uses speed * 100 milliseconds.
// https://github.com/hyprwm/hyprutils/blob/main/src/animation/AnimatedVariable.cpp
// Resolve inherited values: hyprctl reports unoverridden nodes with speed zero.
export function milliseconds(state) {
    const enabled = state.enabled?.bool ?? state.enabled?.int
    if (![true, false, 0, 1].includes(enabled)) throw new Error('Missing animation enable state')
    if (!Array.isArray(state.monitors) || !state.monitors.length) throw new Error('Missing monitor timing')
    const periods = state.monitors.map(monitor => {
        const refresh = Number(monitor.refreshRate)
        if (!Number.isFinite(refresh) || refresh <= 0) throw new Error('Invalid monitor timing')
        return 1000 / refresh
    })
    const frame = Math.ceil(Math.max(...periods))
    if (!enabled) return frame
    const animations = state.animations?.[0]
    if (!Array.isArray(animations)) throw new Error('Missing animation configuration')
    function duration(chain) {
        const animation = chain.map(name => animations.find(row => row.name === name)).find(row => row?.overridden)
        if (!animation) throw new Error('Missing inherited animation configuration')
        if (!animation.enabled) return 0
        const speed = Number(animation.speed)
        if (!Number.isFinite(speed) || speed <= 0) throw new Error('Invalid animation duration')
        if (animation.bezier?.startsWith('spring:')) throw new Error('Spring close timing unavailable')
        return Math.ceil(speed * 100)
    }
    return Math.max(duration(['layersOut','layers','global']), duration(['fadeLayersOut','fadeLayers','fade','global'])) + frame
}
