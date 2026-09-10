import Quickshell
import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.UPower

// Dynamic notch for Hyprland.
PanelWindow {
    id: notchWindow

    property int closedWidth: 118
    property int closedHeight: 34
    property int infoWidth: 250
    property int infoHeight: 68
    property int panelWidth: 420
    property int panelHeight: 540
    property int animationDuration: 340
    property bool panelOpen: false
    property bool notificationsOpen: false
    property int cpuUsage: 0
    property int ramUsage: 0
    property int diskUsage: 0
    property int brightness: 0
    property int volume: 0
    property bool infoShowing: workspaceTimer.running || notificationTimer.running

    function notificationLabel() {
        const count = notificationServer.trackedNotifications.count
        return count === 0 ? "No notifications" : count === 1 ? "1 notification" : count + " notifications"
    }

    function setBrightness(value) {
        brightness = Math.max(0, Math.min(100, Math.round(value)))
        if (brightnessRunner.running) brightnessRunner.running = false
        brightnessRunner.command = ["brightnessctl", "set", brightness + "%"]
        brightnessRunner.running = true
    }

    function setVolume(value) {
        volume = Math.max(0, Math.min(100, Math.round(value)))
        if (volumeRunner.running) volumeRunner.running = false
        volumeRunner.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (volume / 100).toFixed(2)]
        volumeRunner.running = true
    }

    anchors { top: true; left: false; right: false }
    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"

    // Just felt COOL
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: closedHeight

    mask: Region { item: island }

    SystemClock { id: clock }

    Timer { id: workspaceTimer; interval: 1400; repeat: false }
    Timer { id: notificationTimer; interval: 2200; repeat: false }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { workspaceTimer.restart() }
    }

    NotificationServer {
        id: notificationServer
        keepOnReload: true
        onNotification: notification => {
            notification.tracked = true
            notificationTimer.restart()
        }
    }

    // CPU, memory, root-disk, backlight, and output volume poller
    Process {
        id: metricsPoller
        command: ["sh", "-c", "LC_ALL=C top -bn1 | awk '/Cpu/ {for(i=1;i<=NF;i++) if($i ~ /id/) print \"cpu=\" int(100-$(i-1))}'; free -m | awk '/Mem:/ {print \"ram=\" int($3*100/$2)}'; df -P / | awk 'NR==2 {gsub(/%/, \"\", $5); print \"disk=\" $5}'; brightnessctl -m 2>/dev/null | awk -F, 'NR==1 {gsub(/%/, \"\", $4); print \"brightness=\" $4}'; wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print \"volume=\" int($2*100)}'"]
        stdout: SplitParser {
            onRead: data => {
                const pair = data.trim().split("=")
                if (pair.length !== 2) return
                
                const value = Number(pair[1])
                if (isNaN(value)) return

                if (pair[0] === "cpu") notchWindow.cpuUsage = value
                else if (pair[0] === "ram") notchWindow.ramUsage = value
                else if (pair[0] === "disk") notchWindow.diskUsage = value
                else if (pair[0] === "brightness") notchWindow.brightness = value
                else if (pair[0] === "volume") notchWindow.volume = value
            }
        }
    }

    Process { id: brightnessRunner }
    Process { id: volumeRunner }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!metricsPoller.running) metricsPoller.running = true
        }
    }

    Item {
        id: island
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: notchWindow.panelOpen ? notchWindow.panelWidth
              : notchWindow.infoShowing ? notchWindow.infoWidth : notchWindow.closedWidth
        height: notchWindow.panelOpen ? notchWindow.panelHeight
               : notchWindow.infoShowing ? notchWindow.infoHeight : notchWindow.closedHeight
        clip: true

        Canvas {
            id: notchShape
            anchors.fill: parent
            antialiasing: true
            onPaint: {
                const ctx = getContext("2d")
                const corner = Math.min(panelOpen ? 22 : 15, height / 2)
                ctx.reset()
                ctx.fillStyle = "#ff050505"
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(width, 0)
                ctx.lineTo(width, height - corner)
                ctx.quadraticCurveTo(width, height, width - corner, height)
                ctx.lineTo(corner, height)
                ctx.quadraticCurveTo(0, height, 0, height - corner)
                ctx.closePath()
                ctx.fill()
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        // One restrained motion curve across every island state keeps the
        // transition calm and intentional instead of bouncy or abrupt.
        Behavior on width { NumberAnimation { duration: notchWindow.animationDuration; easing.type: Easing.OutQuint } }
        Behavior on height { NumberAnimation { duration: notchWindow.animationDuration; easing.type: Easing.OutQuint } }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) notchWindow.panelOpen = !notchWindow.panelOpen
            }
        }

        Text {
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "h:mm")
            color: "#f5f5f7"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            opacity: !notchWindow.panelOpen && !notchWindow.infoShowing ? 1 : 0
            scale: !notchWindow.panelOpen && !notchWindow.infoShowing ? 1 : 0.88
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        Text {
            anchors.centerIn: parent
            text: notificationTimer.running ? notchWindow.notificationLabel()
                  : Hyprland.focusedWorkspace ? "Workspace " + Hyprland.focusedWorkspace.id : "Workspace"
            color: "#f5f5f7"
            font.pixelSize: 18
            font.weight: Font.DemiBold
            opacity: !notchWindow.panelOpen && notchWindow.infoShowing ? 1 : 0
            scale: !notchWindow.panelOpen && notchWindow.infoShowing ? 1 : 0.9
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
        
        Item {
            id: panelContent
            anchors.top: parent.top
            anchors.topMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            width: notchWindow.panelWidth - 36
            height: notchWindow.panelHeight - 36
            clip: true
            visible: opacity > 0.01
            opacity: notchWindow.panelOpen ? 1 : 0
            scale: notchWindow.panelOpen ? 1 : 0.975
            transformOrigin: Item.Top
            Behavior on opacity { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }

            Column {
                id: content
                width: panelContent.width
                spacing: 16

                Row {
                    width: parent.width
                    Text { text: "System controls"; color: "#f5f5f7"; font.pixelSize: 18; font.weight: Font.DemiBold }
                    Item { width: parent.width - 235; height: 1 }
                    Text { text: "Right-click to close"; color: "#8e8e93"; font.pixelSize: 11 }
                }

                Row {
                    width: parent.width
                    spacing: 18
                    Repeater {
                        model: [
                            { label: "CPU", value: notchWindow.cpuUsage },
                            { label: "RAM", value: notchWindow.ramUsage },
                            { label: "DISK", value: notchWindow.diskUsage }
                        ]
                        delegate: Column {
                            required property var modelData
                            width: (content.width - 36) / 3
                            spacing: 7
                            Text { text: modelData.label; color: "#a8a8ad"; font.pixelSize: 10; font.weight: Font.DemiBold }
                            Rectangle {
                                width: parent.width; height: 64; radius: 8; color: "#1b1b1e"
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: parent.height * Math.max(0.04, Math.min(1, modelData.value / 100))
                                    radius: 8
                                    color: "#e8e8ed"
                                    Behavior on height { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.value + "%"
                                    color: modelData.value > 55 ? "#050505" : "#f5f5f7"
                                    font.pixelSize: 13; font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 13
                    Text { text: "Brightness  " + notchWindow.brightness + "%"; color: "#d1d1d6"; font.pixelSize: 12 }
                    Rectangle {
                        id: brightnessTrack
                        width: parent.width; height: 9; radius: 5; color: "#27272b"
                        Rectangle {
                            width: parent.width * notchWindow.brightness / 100; height: parent.height
                            radius: parent.radius; color: "#f5f5f7"
                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onPressed: mouse => notchWindow.setBrightness(mouse.x / width * 100)
                            onPositionChanged: mouse => { if (pressed) notchWindow.setBrightness(mouse.x / width * 100) }
                        }
                    }
                    Text { text: "Volume  " + notchWindow.volume + "%"; color: "#d1d1d6"; font.pixelSize: 12 }
                    Rectangle {
                        id: volumeTrack
                        width: parent.width; height: 9; radius: 5; color: "#27272b"
                        Rectangle {
                            width: parent.width * notchWindow.volume / 100; height: parent.height
                            radius: parent.radius; color: "#f5f5f7"
                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onPressed: mouse => notchWindow.setVolume(mouse.x / width * 100)
                            onPositionChanged: mouse => { if (pressed) notchWindow.setVolume(mouse.x / width * 100) }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 16
                    Item {
                        id: batteryStatus
                        width: 100; height: 100
                        property real percentage: {
                            if (!UPower.displayDevice) return 0
                            const p = UPower.displayDevice.percentage
                            return p <= 1.0 ? p * 100 : p
                        }
                        Canvas {
                            id: batteryRing
                            anchors.fill: parent
                            onPaint: {
                                const ctx = getContext("2d")
                                const centre = width / 2
                                ctx.reset()
                                ctx.lineWidth = 8
                                ctx.strokeStyle = "#29292d"
                                ctx.beginPath(); ctx.arc(centre, centre, 40, 0, Math.PI * 2); ctx.stroke()
                                ctx.strokeStyle = UPower.onBattery ? "#f5f5f7" : "#78d490"
                                ctx.beginPath(); ctx.arc(centre, centre, 40, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (batteryStatus.percentage / 100)); ctx.stroke()
                            }
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                        }
                        onPercentageChanged: batteryRing.requestPaint()
                        Text { anchors.centerIn: parent; text: Math.round(batteryStatus.percentage) + "%"; color: "#f5f5f7"; font.pixelSize: 16; font.weight: Font.Bold }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Text { text: "Battery"; color: "#f5f5f7"; font.pixelSize: 15; font.weight: Font.DemiBold }
                        Text { text: UPower.onBattery ? "On battery" : "Charging / plugged in"; color: "#a8a8ad"; font.pixelSize: 12 }
                    }
                }

                Rectangle {
                    id: notificationsSection
                    width: parent.width
                    height: notificationColumn.implicitHeight + 20
                    radius: 12
                    color: "#17171a"
                    Column {
                        id: notificationColumn
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 10
                        Row {
                            width: parent.width
                            Text { text: notchWindow.notificationLabel(); color: "#f5f5f7"; font.pixelSize: 14; font.weight: Font.DemiBold }
                            Item { width: parent.width - clearButton.width - 135; height: 1 }
                            Text {
                                id: clearButton
                                text: notificationServer.trackedNotifications.count > 0 ? "Clear all" : ""
                                color: "#a8a8ad"; font.pixelSize: 12
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: notificationServer.trackedNotifications.count > 0
                                    onClicked: {
                                        for (let i = notificationServer.trackedNotifications.count - 1; i >= 0; --i)
                                            notificationServer.trackedNotifications.get(i).dismiss()
                                    }
                                }
                            }
                        }
                        MouseArea {
                            width: parent.width; height: 24
                            onClicked: notchWindow.notificationsOpen = !notchWindow.notificationsOpen
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: notchWindow.notificationsOpen ? "Hide notifications" : "Show notifications"
                                color: "#a8a8ad"; font.pixelSize: 12
                            }
                        }
                        Repeater {
                            model: notchWindow.notificationsOpen ? notificationServer.trackedNotifications : null
                            delegate: Rectangle {
                                required property var modelData
                                width: notificationColumn.width
                                height: notificationText.implicitHeight + 20
                                radius: 8; color: "#242428"
                                Column {
                                    id: notificationText
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                    anchors.margins: 10
                                    spacing: 3
                                    Text { text: modelData.appName || "Notification"; color: "#a8a8ad"; font.pixelSize: 11 }
                                    Text { text: modelData.summary; color: "#f5f5f7"; font.pixelSize: 13; font.weight: Font.DemiBold; width: parent.width; wrapMode: Text.Wrap }
                                    Text { visible: modelData.body.length > 0; text: modelData.body; color: "#c7c7cc"; font.pixelSize: 12; width: parent.width; wrapMode: Text.Wrap; textFormat: Text.PlainText }
                                }
                                MouseArea { anchors.fill: parent; onClicked: modelData.dismiss() }
                            }
                        }
                    }
                }
            }
        }
    }
}
