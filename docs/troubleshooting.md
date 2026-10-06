# Troubleshooting

## Notification replacement timeout

Quickshell 0.3.1 exposes notification replacements through property changes.
An identical-content replacement produces no QML change event, so it cannot
restart the timeout through this API. See the upstream
[notification receipt implementation](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/services/notifications/server.cpp).

## Desktop portal startup

Qt's platform services register with the portal after `qt6ct` has already used
that D-Bus connection. A scoped `QT_NO_XDG_DESKTOP_PORTAL=1` default in `shell.qml`
skips that late registration and the unused native color-picker probe. This
startup setting takes effect after restarting Quickshell. See Qt's
[platform service initialization](https://github.com/qt/qtbase/blob/v6.11.2/src/gui/platform/unix/qdesktopunixservices.cpp).

## Discord tray warnings

Discord's tray item omits `IconName` and rejects Quickshell's refresh requests,
so the repeated warning comes from Quickshell's native tray implementation.
It requires an upstream fix; this QML configuration cannot change its polling.

## Notification outlines

Outline trimming uses Qt 6.10 or newer's
[ShapePath trim](https://doc.qt.io/qt-6/qml-qtquick-shapes-shapepath.html#trim-prop).

## No notifications

Check ownership with `busctl --user status org.freedesktop.Notifications` and
send a sample with `notify-send`. See [setup](setup.md#notification-ownership)
when switching from SwayNC.

[Documentation](README.md)
