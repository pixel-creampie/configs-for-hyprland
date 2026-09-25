import QtQuick
import Quickshell

// Transient popup shown when a new notification arrives: icon, app name,
// summary, and body, then auto-dismisses. shell.qml owns the timer and
// just tells this module what to show and whether it's currently up.
Item {
    id: root

    // Shared design tokens - see modules/Theme.qml.
    Theme { id: theme }

    // The Notification object from NotificationServer, or null between
    // toasts. Notification is "Retainable" per Quickshell's docs - it
    // stays safely readable even if the underlying notification closes
    // while this is still showing it.
    required property var notification
    required property bool shown

    signal dismissRequested()

    readonly property string resolvedIcon: {
        if (!notification) return ""
        if (notification.image && notification.image.length > 0) return notification.image
        if (notification.appIcon && notification.appIcon.length > 0) return Quickshell.iconPath(notification.appIcon)
        return ""
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissRequested()
    }

    Row {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Rectangle {
            id: iconFrame
            width: 46; height: 46; radius: 12
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2c2c30" }
                GradientStop { position: 1.0; color: theme.surfaceAlt }
            }

            // Bell placeholder, drawn as a vector shape rather than an
            // icon-font glyph, shown behind the real icon so a missing or
            // unresolved appIcon never leaves a blank square.
            Canvas {
                anchors.centerIn: parent
                width: 20; height: 20
                antialiasing: true
                onPaint: {
                    const ctx = getContext("2d")
                    const w = width, h = height, cx = w / 2
                    ctx.reset()
                    ctx.fillStyle = theme.textFaint
                    ctx.beginPath()
                    ctx.arc(cx, h * 0.42, w * 0.30, Math.PI, 0, false)
                    ctx.lineTo(w * 0.80, h * 0.68)
                    ctx.lineTo(w * 0.20, h * 0.68)
                    ctx.closePath()
                    ctx.fill()
                    ctx.fillRect(w * 0.14, h * 0.68, w * 0.72, h * 0.08)
                    ctx.beginPath()
                    ctx.arc(cx, h * 0.86, w * 0.08, 0, Math.PI * 2)
                    ctx.fill()
                }
            }

            Image {
                anchors.fill: parent
                source: root.resolvedIcon
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                asynchronous: true
            }
        }

        Column {
            width: parent.width - iconFrame.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: root.notification ? (root.notification.appName || "") : ""
                color: theme.textTertiary
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 0.4
                font.family: theme.fontFamily
                elide: Text.ElideRight
                visible: text !== ""
            }
            Text {
                width: parent.width
                text: root.notification ? (root.notification.summary || "") : ""
                color: theme.textPrimary
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.family: theme.fontFamily
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.notification ? (root.notification.body || "") : ""
                color: theme.textSecondary
                font.pixelSize: 11
                font.family: theme.fontFamily
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                visible: text !== ""
            }
        }
    }

    opacity: root.shown ? 1 : 0
    scale: root.shown ? 1 : 0.92
    Behavior on opacity { NumberAnimation { duration: theme.durationBase; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: theme.durationBase; easing.type: Easing.OutCubic } }
}
