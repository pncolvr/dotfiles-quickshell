#!/usr/bin/env bash

WORKSPACE=$(echo "${BASH_SOURCE[0]:-0}" | xargs realpath | xargs dirname | xargs dirname)/_common
source "$WORKSPACE"/utils.sh

# on the env file:
# {
#     "prompt": "",
#     "action": "default",
#     "allowTyped": false,
#     "allowMultipleSelection": false,
#     "sort": true,
#     "items": <result of the js below>
# }

# const items = document.querySelectorAll('#content > div > div > main > div > div > div._body_mbox7_130 > div > div > div._listItems_5203n_183 > div > div > div')
# const allItems = []
# const baseUrl = `http://${window.location.host}/workflow`

# items.forEach(item => {
# const name = item.dataset.resourcename
# const id = item.dataset.resourceid

# if (name && id) {
#     allItems.push({title:`${name}_${id}`, result:`${baseUrl}/${id}`})
# }
# });

# const toCopy = JSON.stringify(allItems, null, 2)
# copy(toCopy)

links=$(realpath $(get_env_file ${BASH_SOURCE[0]:-0}))

"$WORKSPACE"/handle.sh "$links"
