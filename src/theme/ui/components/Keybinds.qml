pragma Singleton
import QtQml
import "../../../config"

QtObject {
    function sequence(action) {
        const parts = action.split(".")
        const value = Config.keybinds[parts.length > 1 ? parts[0] : "common"]?.[parts[parts.length - 1]]
        return typeof value === "string" ? value : ""
    }
    function hint(text, action) {
        const key = sequence(action)
        return key && !text.includes(key) ? text + " (" + key + ")" : text
    }
    function describe(action, label) {
        const key = sequence(action)
        return key ? key + ": " + label : ""
    }
    function modifiers(action) {
        return modifierMask(sequence(action).split("+"))
    }
    function modifierMask(parts) {
        const values = {Ctrl:Qt.ControlModifier,Alt:Qt.AltModifier,Shift:Qt.ShiftModifier,Meta:Qt.MetaModifier}
        if (parts.some(part => values[part] === undefined)) return -1
        return parts.reduce((value, part) => value | values[part],0)
    }
    function matches(event, action) {
        const sequence = root.sequence(action)
        if (!sequence) return false
        const parts = sequence.split("+")
        let name = parts.pop()
        if (!name && parts[parts.length - 1] === "") { parts.pop(); name = "+" }
        const keys = {Escape:Qt.Key_Escape,Esc:Qt.Key_Escape,Return:Qt.Key_Return,Enter:Qt.Key_Enter,
            Delete:Qt.Key_Delete,Del:Qt.Key_Delete,Tab:Qt.Key_Tab,Backtab:Qt.Key_Backtab,
            Left:Qt.Key_Left,Right:Qt.Key_Right,Up:Qt.Key_Up,Down:Qt.Key_Down,Space:Qt.Key_Space}
        const key = keys[name] ?? Qt["Key_" + name] ?? (name.length === 1 ? name.toUpperCase().charCodeAt(0)
            : /^F\d+$/.test(name) ? Qt.Key_F1 + Number(name.slice(1)) - 1 : -1)
        const modifiers = modifierMask(parts)
        return event.key === key && (event.modifiers & ~Qt.KeypadModifier) === modifiers
    }
    id: root
}
