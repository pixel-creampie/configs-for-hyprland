import Quickshell
import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import "modules" as Modules

// MacBook-style dynamic notch for Hyprland.
PanelWindow {
    id: notchWindow

    property int closedWidth: 118
    property int closedHeight: 34
    property int infoWidth: 250
    property int infoHeight: 68
    property int playerWidth: 300
    property int playerHeight: 92
    property int panelWidth: 420
    property int panelHeight: 210
    property int animationDuration: 340
    property bool panelOpen: false
    property bool playerOpen: false
    property int cpuUsage: 0
    property int ramUsage: 0
    property int diskUsage: 0
    property int brightness: 0
    property int volume: 0
    property bool infoShowing: workspaceTimer.running

    // Audio Visualizer Properties
    property var cavaBars: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property bool isAudioPlaying: false

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

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: closedHeight

    mask: Region { item: island }

    Timer { id: workspaceTimer; interval: 1400; repeat: false }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { workspaceTimer.restart() }
    }

    // Process to run CAVA and read stdout output stream
    Process {
        id: cavaRunner
        command: ["sh", "-c", "cava -p ~/.config/cava/config_notch"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const values = data.trim().split(";").map(v => parseInt(v, 10)).filter(n => !isNaN(n))
                if (values.length > 0) {
                    notchWindow.cavaBars = values
                    const totalVolume = values.reduce((acc, curr) => acc + curr, 0)
                    notchWindow.isAudioPlaying = totalVolume > 0
                }
            }
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
        : notchWindow.playerOpen ? notchWindow.playerWidth
        : notchWindow.infoShowing ? notchWindow.infoWidth : notchWindow.closedWidth
        height: notchWindow.panelOpen ? notchWindow.panelHeight
        : notchWindow.playerOpen ? notchWindow.playerHeight
        : notchWindow.infoShowing ? notchWindow.infoHeight : notchWindow.closedHeight
        clip: true

        Canvas {
            id: notchShape
            anchors.fill: parent
            antialiasing: true
            onPaint: {
                const ctx = getContext("2d")
                const corner = Math.min(panelOpen ? 22 : playerOpen ? 20 : 15, height / 2)
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

        Behavior on width { NumberAnimation { duration: notchWindow.animationDuration; easing.type: Easing.OutQuint } }
        Behavior on height { NumberAnimation { duration: notchWindow.animationDuration; easing.type: Easing.OutQuint } }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    notchWindow.panelOpen = !notchWindow.panelOpen
                    if (notchWindow.panelOpen) notchWindow.playerOpen = false
                } else if (mouse.button === Qt.LeftButton) {
                    notchWindow.playerOpen = !notchWindow.playerOpen
                    if (notchWindow.playerOpen) notchWindow.panelOpen = false
                }
            }
        }

        // Idle Clock Display (Hidden when audio plays, workspace info pops up, or the player's open)
        Modules.Idle {
            anchors.fill: parent
            idle: !notchWindow.panelOpen && !notchWindow.playerOpen && !notchWindow.infoShowing && !notchWindow.isAudioPlaying
        }

        // Audio Visualizer Display (Active during audio playback)
        Row {
            anchors.centerIn: parent
            spacing: 3
            opacity: !notchWindow.panelOpen && !notchWindow.playerOpen && !notchWindow.infoShowing && notchWindow.isAudioPlaying ? 1 : 0
            scale: !notchWindow.panelOpen && !notchWindow.playerOpen && !notchWindow.infoShowing && notchWindow.isAudioPlaying ? 1 : 0.88
            visible: opacity > 0.01

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Repeater {
                model: notchWindow.cavaBars

                delegate: Rectangle {
                    required property int modelData
                    width: 3
                    height: Math.max(3, Math.min(18, Math.round((modelData / 100) * 18)))
                    radius: 1.5
                    color: "#f5f5f7"
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on height {
                        NumberAnimation { duration: 50; easing.type: Easing.OutQuad }
                    }
                }
            }
        }

        // Workspace Indicator Popup
        Text {
            anchors.centerIn: parent
            text: Hyprland.focusedWorkspace ? "Workspace " + Hyprland.focusedWorkspace.id : "Workspace"
            color: "#f5f5f7"
            font.pixelSize: 18
            font.weight: Font.DemiBold
            opacity: !notchWindow.panelOpen && !notchWindow.playerOpen && notchWindow.infoShowing ? 1 : 0
            scale: !notchWindow.panelOpen && !notchWindow.playerOpen && notchWindow.infoShowing ? 1 : 0.9
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        // Music Player: fixed to its own final size (not anchors.fill:
        // parent) for the same reason panelContent is below - "parent" here
        // is island, which is still animating for the whole time it's
        // opening, and a moving width would make the progress bar chase a
        // moving target. island's clip: true still reveals it progressively.
        Modules.MusicPlayer {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: notchWindow.playerWidth
            height: notchWindow.playerHeight
            visible: opacity > 0.01
            opacity: notchWindow.playerOpen ? 1 : 0
            scale: notchWindow.playerOpen ? 1 : 0.975
            transformOrigin: Item.Top
            active: notchWindow.playerOpen
            Behavior on opacity { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
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
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 18

                Row {
                    width: parent.width
                    Text { text: "System controls"; color: "#f5f5f7"; font.pixelSize: 18; font.weight: Font.DemiBold }
                    Item { width: parent.width - 235; height: 1 }
                    Text { text: "Right-click to close"; color: "#8e8e93"; font.pixelSize: 11 }
                }

                // 4 Circular Metric Gauges (RAM, CPU, DISK, BATTERY)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    Repeater {
                        model: [
                            { label: "RAM", value: notchWindow.ramUsage },
                            { label: "CPU", value: notchWindow.cpuUsage },
                            { label: "DISK", value: notchWindow.diskUsage },
                            { label: "BAT", value: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) : 100 }
                        ]

                        delegate: Rectangle {
                            width: 72; height: 72
                            radius: 36
                            color: "#ffffff"

                            Canvas {
                                id: gaugeRing
                                anchors.fill: parent
                                contextType: "2d"
                                onPaint: {
                                    const ctx = context
                                    const cx = width / 2
                                    const cy = height / 2
                                    const radius = (width / 2) - 4
                                    const startAngle = -Math.PI / 2
                                    const endAngle = startAngle + (2 * Math.PI * (modelData.value / 100))

                                    ctx.reset()
                                    ctx.lineWidth = 4
                                    ctx.strokeStyle = "#e5e5ea"
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, radius, 0, 2 * Math.PI)
                                    ctx.stroke()

                                    ctx.lineWidth = 4
                                    ctx.strokeStyle = modelData.value > 85 ? "#ff3b30" : "#007aff"
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, radius, startAngle, endAngle)
                                    ctx.stroke()
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label
                                    color: "#1c1c1e"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Math.round(modelData.value) + "%"
                                    color: "#1c1c1e"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }

                // Dual Slider Layout with Flanking Circular Action Buttons
                Row {
                    width: parent.width
                    spacing: 8

                    // Left Circle Button (Brightness Toggle)
                    Rectangle {
                        width: 24; height: 24
                        radius: 12
                        color: "#545458"
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: "#ffffff"
                            font.family: "FontAwesome"
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: notchWindow.setBrightness(notchWindow.brightness > 50 ? 20 : 100)
                        }
                    }

                    // Brightness Slider Pill
                    Rectangle {
                        width: (parent.width - 24 * 2 - 8 * 3) / 2
                        height: 24
                        radius: 12
                        color: "#3a3a3c"

                        Rectangle {
                            width: parent.width * notchWindow.brightness / 100
                            height: parent.height
                            radius: parent.radius
                            color: "#8e8e93"
                            Behavior on width { NumberAnimation { duration: 120 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: mouse => notchWindow.setBrightness(mouse.x / width * 100)
                            onPositionChanged: mouse => { if (pressed) notchWindow.setBrightness(mouse.x / width * 100) }
                        }
                    }

                    // Volume Slider Pill
                    Rectangle {
                        width: (parent.width - 24 * 2 - 8 * 3) / 2
                        height: 24
                        radius: 12
                        color: "#3a3a3c"

                        Rectangle {
                            width: parent.width * notchWindow.volume / 100
                            height: parent.height
                            radius: parent.radius
                            color: "#8e8e93"
                            Behavior on width { NumberAnimation { duration: 120 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: mouse => notchWindow.setVolume(mouse.x / width * 100)
                            onPositionChanged: mouse => { if (pressed) notchWindow.setVolume(mouse.x / width * 100) }
                        }
                    }

                    // Right Circle Button (Volume Mute Toggle)
                    Rectangle {
                        width: 24; height: 24
                        radius: 12
                        color: "#545458"
                        Text {
                            anchors.centerIn: parent
                            text: notchWindow.volume > 0 ? "" : ""
                            color: "#ffffff"
                            font.family: "FontAwesome"
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: notchWindow.setVolume(notchWindow.volume > 0 ? 0 : 50)
                        }
                    }
                }
            }
        }
    }
}
