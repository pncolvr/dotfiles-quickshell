## Main features

- Clock with month and year view tooltips
- Hyprland window list with focus, next/prev navigation
- System stats: CPU and memory with tooltips, temperature, and network speeds with graph tooltip
    - Network tooltip shows connected networks with per-interface speeds and top 10 processes by bandwidth
    - Process bandwidth requires `bandwhich`
- Volume and audio device info via PipeWire
- Screencast/screenshare status with sound notifications
- Package update indicator
- Easily follow Twitch streamers
    - edit config/twitch-users with your prefered streamers
- Submap window for Hyprland keybind hints
- Alert window
- IPC commands for reloading and toggling modules
 
## IPC

Quickshell supports calling functions through IPC, I used this to integrate hypr on some edge cases.

```sh
qs ipc call notifications reload # used to manually reload notification status
qs ipc call notifications toggle # used to toggle notification status
qs ipc call status reload # custom script i have to change working mode of my pc
qs ipc call windows next # go to next window
qs ipc call windows prev # go to previous windodw
qs ipc call windows reload # manually reload window list
qs ipc call windows focus [0-9] #index of the grouped window to move to
qs ipc call twitch reload # reload twitch
```
