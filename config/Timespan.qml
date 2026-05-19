pragma Singleton

import QtQuick

QtObject {
    function fromMilliseconds(n) { return n }
    function fromSeconds(n) { return n * 1000 }
    function fromMinutes(n) { return n * 60 * 1000 }
    function fromHours(n) { return n * 60 * 60 * 1000 }
}
