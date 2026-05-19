pragma ComponentBehavior: Bound

import QtQuick
import "../../theme"
import "../../services"

Grid {
    id: content
    columns: 3
    spacing: Theme.twitchTooltipSpacing
    verticalItemAlignment: Grid.AlignVCenter
    Repeater {
         model: {
            const users = [...TwitchService.allUsers]
            return users.sort((a, b) => {
                if (a.online === b.online) return a.login.localeCompare(b.login)
                return a.online ? -1 : 1
            })
        }
        delegate: TwitchUserRow {
            required property var modelData
            user: modelData
        }
    }

    // Component.onCompleted: console.warn("allUsers:", JSON.stringify(TwitchService.allUsers))
}