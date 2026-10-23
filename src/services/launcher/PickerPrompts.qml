pragma Singleton
import QtQml
import "../../config"
import "../../i18n"

// Keep prompt configuration and translation lookup at the presentation boundary.
QtObject {
    function text(key, fallback, args = []) {
        const configured = Config.pickerPrompts[key]
        return Translations.text(typeof configured === "string" ? configured : fallback, args)
    }
}
