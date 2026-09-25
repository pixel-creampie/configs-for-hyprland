import QtQuick
import Quickshell

// Notification centre: the persistent list shown when left-clicking the
// notch while no media is playing. Self-contained like the other modules -
// shell.qml just hands it the live NotificationServer.trackedNotifications
// model. Dismissal goes straight through Notification.dismiss() rather
// than round-tripping through a signal back to shell.qml, since dismiss()
// is already the correct, safe way to close one.
Item {
    id: root

    // Shared design tokens - see modules/Theme.qml.
    Theme { id: theme }

    required property var notifications
    required property bool active

    readonly property int count: notifications ? notifications.values.length : 0

    function clearAll() {
        if (!notifications) return
        // Snapshot first: dismissing mutates the live list we'd otherwise
        // be iterating out from under ourselves.
        const items = notifications.values.slice()
        for (let i = 0; i < items.length; i++) items[i].dismiss()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Item {
            width: parent.width
            height: 18
            visible: root.count > 0

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Clear All"
                color: theme.accentSound
                font.pixelSize: 11
                font.weight: Font.Bold
                font.family: theme.fontFamily

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearAll()
                }
            }
        }

        Item {
            width: parent.width
            height: parent.height - (root.count > 0 ? 28 : 0)

            ListView {
                anchors.fill: parent
                clip: true
                spacing: 8
                model: root.notifications
                visible: root.count > 0
                delegate: NotificationRow {
                    width: ListView.view ? ListView.view.width : 0
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.count === 0
                text: "No notifications"
                color: theme.textTertiary
                font.pixelSize: 12
                font.family: theme.fontFamily
            }
        }
    }

    component NotificationRow: Rectangle {
        id: row
        required property var modelData
        height: 58
        radius: 14
        color: theme.surface
        border.color: theme.cardBorder
        border.width: 1
        clip: true

        readonly property string resolvedIcon: {
            if (!modelData) return ""
            if (modelData.image && modelData.image.length > 0) return modelData.image
            if (modelData.appIcon && modelData.appIcon.length > 0) return Quickshell.iconPath(modelData.appIcon)
            return ""
        }

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Rectangle {
                id: icon
                width: 38; height: 38; radius: 10
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                color: theme.surfaceAlt
                Image {
                    anchors.fill: parent
                    source: row.resolvedIcon
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    asynchronous: true
                }
            }

            Column {
                width: parent.width - icon.width - dismiss.width - parent.spacing * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    width: parent.width
                    text: row.modelData ? (row.modelData.summary || row.modelData.appName || "") : ""
                    color: theme.textPrimary
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    font.family: theme.fontFamily
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: row.modelData ? (row.modelData.body || "") : ""
                    color: theme.textSecondary
                    font.pixelSize: 11
                    font.family: theme.fontFamily
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    visible: text !== ""
                }
            }

            Rectangle {
                id: dismiss
                width: 22; height: 22; radius: 11
                anchors.verticalCenter: parent.verticalCenter
                color: dismissArea.containsMouse ? theme.surfaceHover : "transparent"
                Behavior on color { ColorAnimation { duration: theme.durationInstant } }
                Canvas {
                    anchors.centerIn: parent
                    width: 10; height: 10
                    antialiasing: true
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.strokeStyle = theme.textTertiary
                        ctx.lineWidth = 1.6
                        ctx.lineCap = "round"
                        ctx.beginPath(); ctx.moveTo(1, 1); ctx.lineTo(width - 1, height - 1); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(width - 1, 1); ctx.lineTo(1, height - 1); ctx.stroke()
                    }
                }
                MouseArea {
                    id: dismissArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (row.modelData) row.modelData.dismiss()
                }
            }
        }
    }
}
