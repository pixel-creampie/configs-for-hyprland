import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

// System control panel, laid out in the Material 3 Expressive idiom:
// large square tiles on a 3-column grid, generous corner radii, tonal
// accent-tinted containers, and a trailing tile that stretches to fill
// its row rather than leaving a ragged gap.
//
// Self-contained like the other modules: metrics arrive as plain
// properties from shell.qml, and the two interactive controls report
// back through signals rather than touching brightnessctl/wpctl.
Item {
    id: root

    // Primary System Metrics (driven from shell.qml's poller)
    property int cpuUsage: 0
    property int cpuTemp: 0

    property int gpuUsage: 0
    property int gpuTemp: 0
    // GPU reporting is hardware/driver specific, so the tile only appears
    // once shell.qml has actually read a value from nvidia-smi or the
    // amdgpu sysfs node. Otherwise it'd sit at a permanent, misleading 0%.
    property bool gpuAvailable: false

    property int ramUsage: 0
    property real ramUsedGb: 0.0

    property int diskUsage: 0
    property string diskLabel: ""

    property int brightness: 0
    property int volume: 0
    property bool muted: false
    property int micVolume: 0
    property bool micMuted: false

    signal setBrightnessRequested(int value)
    signal setVolumeRequested(int value)
    signal setMicVolumeRequested(int value)

    // Dynamic Battery Hardware Status
    readonly property bool hasBattery: UPower.displayDevice !== null && UPower.displayDevice.isPresent
    readonly property int batteryPercent: hasBattery ? Math.round(UPower.displayDevice.percentage * (UPower.displayDevice.percentage <= 1.0 ? 100 : 1)) : 0
    readonly property bool isCharging: hasBattery && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)
    // Reports the real state rather than falling back to a hardcoded
    // string, so PendingCharge/Empty/Unknown don't masquerade as "100%".
    readonly property string batteryStatusText: {
        if (!hasBattery) return ""
        const s = UPower.displayDevice.state
        if (s === UPowerDeviceState.FullyCharged) return "FULL"
        if (s === UPowerDeviceState.Charging) return "AC"
        if (s === UPowerDeviceState.Discharging) return "BAT"
        if (s === UPowerDeviceState.PendingCharge) return "WAIT"
        if (s === UPowerDeviceState.PendingDischarge) return "WAIT"
        if (s === UPowerDeviceState.Empty) return "LOW"
        return ""
    }

    // Shared design tokens - see modules/Theme.qml. Replaces what used to
    // be a private copy of the same palette declared right here (this file
    // is originally where these token names came from) - now every module
    // pulls from one definition instead of five near-identical ones.
    Theme { id: theme }

    // ---- Expressive grid geometry -------------------------------------
    readonly property int columns: 3
    readonly property int gridSpacing: 10
    readonly property int outerMargin: 16

    readonly property int tileCount: 3 + (gpuAvailable ? 1 : 0) + (hasBattery ? 1 : 0)
    // The final tile stretches across whatever columns are left over, so a
    // 4- or 5-tile grid ends flush instead of with a hole in it.
    readonly property int trailingSpan: {
        const rem = tileCount % columns
        return rem === 0 ? 1 : columns - rem + 1
    }

    readonly property real cellSize: Math.max(72,
        (width - outerMargin * 2 - gridSpacing * (columns - 1)) / columns)

    implicitWidth: 434
    implicitHeight: outerMargin * 2
        + cellSize * Math.ceil(tileCount / columns)
        + gridSpacing * (Math.ceil(tileCount / columns) - 1)
        + gridSpacing + 46 + gridSpacing + 46 + gridSpacing + 46

    Rectangle {
        anchors.fill: parent
        color: theme.bgAmoled
        radius: theme.radiusPanel
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.outerMargin
            spacing: root.gridSpacing

            // ==========================================
            // HARDWARE TILES
            // ==========================================
            GridLayout {
                Layout.fillWidth: true
                columns: root.columns
                columnSpacing: root.gridSpacing
                rowSpacing: root.gridSpacing

                ExpressiveTile {
                    title: "CPU"
                    valueText: root.cpuUsage + "%"
                    badgeText: root.cpuTemp > 0 ? root.cpuTemp + "°" : ""
                    progress: root.cpuUsage / 100
                    accentColor: theme.accentCpu
                }

                ExpressiveTile {
                    visible: root.gpuAvailable
                    title: "GPU"
                    valueText: root.gpuUsage + "%"
                    badgeText: root.gpuTemp > 0 ? root.gpuTemp + "°" : ""
                    progress: root.gpuUsage / 100
                    accentColor: theme.accentGpu
                }

                ExpressiveTile {
                    title: "RAM"
                    valueText: root.ramUsage + "%"
                    badgeText: root.ramUsedGb > 0 ? root.ramUsedGb.toFixed(1) + "G" : ""
                    progress: root.ramUsage / 100
                    accentColor: theme.accentRam
                }

                ExpressiveTile {
                    title: "DISK"
                    valueText: root.diskUsage + "%"
                    badgeText: root.diskLabel
                    progress: root.diskUsage / 100
                    accentColor: theme.accentDisk
                    // Only the last tile stretches; DISK is last when
                    // there's no battery to follow it.
                    Layout.columnSpan: root.hasBattery ? 1 : root.trailingSpan
                }

                ExpressiveTile {
                    visible: root.hasBattery
                    title: "BAT"
                    valueText: root.batteryPercent + "%"
                    badgeText: root.batteryStatusText
                    progress: root.batteryPercent / 100
                    accentColor: root.batteryPercent <= 20 && !root.isCharging ? theme.accentError : theme.accentBattery
                    pulsing: root.isCharging
                    Layout.columnSpan: root.trailingSpan
                }
            }

            // ==========================================
            // DISPLAY / SOUND
            // ==========================================
            ControlSlider {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                label: "Display"
                value: root.brightness
                accentColor: theme.accentDisplay
                iconKind: "sun"
                onMoved: v => root.setBrightnessRequested(v)
            }

            ControlSlider {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                label: "Sound"
                value: root.volume
                muted: root.muted
                accentColor: theme.accentSound
                iconKind: "speaker"
                onMoved: v => root.setVolumeRequested(v)
            }

            ControlSlider {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                label: "Microphone"
                value: root.micVolume
                muted: root.micMuted
                accentColor: theme.accentMic
                iconKind: "mic"
                onMoved: v => root.setMicVolumeRequested(v)
            }
        }
    }

    // Large square Material 3 Expressive tile.
    component ExpressiveTile: Rectangle {
        id: card

        property string title: ""
        property string valueText: ""
        property string badgeText: ""
        property real progress: 0.0
        property color accentColor: theme.accentCpu
        // Subtle breathing glow, used to signal "charging" without adding
        // another glyph that may not have a font behind it.
        property bool pulsing: false

        Layout.fillWidth: true
        Layout.preferredWidth: root.cellSize
        Layout.preferredHeight: root.cellSize

        // Tonal container: a whisper of the tile's own accent rather than
        // one flat grey for everything.
        // Pure AMOLED - no tonal wash. Only the border, badge, ring,
        // and value text carry the accent; the fill itself stays black.
        color: theme.bgAmoled
        radius: 26
        border.color: card.pulsing ? theme.tint(accentColor, 0.5) : theme.tint(accentColor, 0.16)
        border.width: 1
        clip: true

        Behavior on border.color { ColorAnimation { duration: 240 } }

        SequentialAnimation on opacity {
            running: card.pulsing
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.8; duration: 1100; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) card.opacity = 1
        }

        // Header: label + badge pill
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 13
            height: 18

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: card.title
                color: theme.textTertiary
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 0.8
                font.family: theme.fontFamily
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: card.badgeText !== ""
                height: 18
                width: Math.min(parent.width * 0.6, badgeTextItem.implicitWidth + 14)
                radius: 9
                color: theme.tint(card.accentColor, 0.18)

                Text {
                    id: badgeTextItem
                    anchors.centerIn: parent
                    text: card.badgeText
                    color: card.accentColor
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.family: theme.fontFamily
                    elide: Text.ElideRight
                }
            }
        }

        // Big ring gauge filling the square
        Item {
            id: ringContainer
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            anchors.topMargin: 2

            readonly property real side: Math.max(28, Math.min(width, height))

            Canvas {
                id: ringCanvas
                width: ringContainer.side
                height: ringContainer.side
                anchors.centerIn: parent
                antialiasing: true

                // Canvas doesn't repaint on its own when the data behind it
                // changes - only on resize. Mirroring the inputs as local
                // properties gives us change signals to hook requestPaint()
                // onto, so the arc tracks live values instead of freezing.
                property real pct: Math.max(0, Math.min(1, card.progress))
                property color accent: card.accentColor
                Behavior on pct { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }

                onPctChanged: requestPaint()
                onAccentChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    const cx = width / 2
                    const cy = height / 2
                    const strokeWidth = Math.max(5, width * 0.105)
                    const radius = (width / 2) - strokeWidth

                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    ctx.lineCap = "round"
                    ctx.lineWidth = strokeWidth

                    // Track arc
                    ctx.strokeStyle = theme.tint(accent, 0.12)
                    ctx.beginPath()
                    ctx.arc(cx, cy, radius, Math.PI * 0.75, Math.PI * 2.25)
                    ctx.stroke()

                    // Active progress arc
                    const clampedPct = Math.max(0.001, Math.min(1.0, pct))
                    ctx.strokeStyle = accent
                    ctx.beginPath()
                    ctx.arc(cx, cy, radius, Math.PI * 0.75, Math.PI * 0.75 + (Math.PI * 1.5 * clampedPct))
                    ctx.stroke()
                }
            }

            Text {
                anchors.centerIn: ringCanvas
                text: card.valueText
                color: theme.textPrimary
                font.pixelSize: Math.max(14, Math.round(ringContainer.side * 0.26))
                font.weight: Font.Bold
                font.family: theme.fontFamily
            }
        }
    }

    // Full-width control row: a single draggable pill, no label or
    // percentage text - just the fill level and an icon. Icons are drawn
    // as vector shapes rather than glyphs so they don't depend on any
    // particular icon font being installed.
    component ControlSlider: Rectangle {
        id: slider

        property string label: ""
        property int value: 0
        property bool muted: false
        property color accentColor: theme.accentDisplay
        property string iconKind: "sun"

        signal moved(int v)

        function applyFromX(x) {
            const pct = Math.max(0, Math.min(1, x / Math.max(1, track.width)))
            slider.moved(Math.round(pct * 100))
        }

        color: theme.bgAmoled
        radius: height / 2
        border.color: dragArea.containsMouse || dragArea.pressed
            ? theme.tint(slider.accentColor, 0.4) : theme.tint(slider.accentColor, 0.14)
        border.width: 1
        clip: true
        Behavior on border.color { ColorAnimation { duration: 160 } }

        Rectangle {
            id: track
            anchors.fill: parent
            anchors.margins: 4
            radius: height / 2
            color: theme.track

            Rectangle {
                id: fill
                height: parent.height
                radius: parent.radius
                width: parent.width * Math.max(0, Math.min(1, slider.muted ? 0 : slider.value / 100))
                // Skip the animation while dragging so the fill tracks the
                // pointer exactly instead of lagging it.
                Behavior on width {
                    enabled: !dragArea.pressed
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: theme.tint(slider.accentColor, 0.55) }
                    GradientStop { position: 1.0; color: slider.accentColor }
                }
            }

            // Icon sits pinned at the left of the track, tinted to stay
            // legible whether or not the fill has reached it.
            Canvas {
                id: iconCanvas
                width: 15; height: 15
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                antialiasing: true

                property bool covered: fill.width > (x + width + 2)
                property bool isMuted: slider.muted
                onCoveredChanged: requestPaint()
                onIsMutedChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    const c = covered ? theme.iconOnLight : theme.textTertiary
                    const w = width, h = height
                    const cx = w / 2, cy = h / 2
                    ctx.reset()
                    ctx.clearRect(0, 0, w, h)
                    ctx.fillStyle = c
                    ctx.strokeStyle = c
                    ctx.lineWidth = Math.max(1, w * 0.1)
                    ctx.lineCap = "round"

                    if (slider.iconKind === "sun") {
                        ctx.beginPath()
                        ctx.arc(cx, cy, w * 0.22, 0, Math.PI * 2)
                        ctx.fill()
                        for (let i = 0; i < 8; i++) {
                            const a = (Math.PI / 4) * i
                            ctx.beginPath()
                            ctx.moveTo(cx + Math.cos(a) * w * 0.34, cy + Math.sin(a) * w * 0.34)
                            ctx.lineTo(cx + Math.cos(a) * w * 0.46, cy + Math.sin(a) * w * 0.46)
                            ctx.stroke()
                        }
                    } else if (slider.iconKind === "speaker") {
                        // Speaker body + cone
                        ctx.beginPath()
                        ctx.moveTo(w * 0.12, h * 0.36)
                        ctx.lineTo(w * 0.30, h * 0.36)
                        ctx.lineTo(w * 0.52, h * 0.16)
                        ctx.lineTo(w * 0.52, h * 0.84)
                        ctx.lineTo(w * 0.30, h * 0.64)
                        ctx.lineTo(w * 0.12, h * 0.64)
                        ctx.closePath()
                        ctx.fill()
                        if (isMuted) {
                            ctx.beginPath()
                            ctx.moveTo(w * 0.62, h * 0.32)
                            ctx.lineTo(w * 0.92, h * 0.68)
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.moveTo(w * 0.92, h * 0.32)
                            ctx.lineTo(w * 0.62, h * 0.68)
                            ctx.stroke()
                        } else {
                            ctx.beginPath()
                            ctx.arc(w * 0.54, cy, w * 0.20, -Math.PI / 3, Math.PI / 3)
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.arc(w * 0.54, cy, w * 0.34, -Math.PI / 3, Math.PI / 3)
                            ctx.stroke()
                        }
                    } else {
                        // Mic: a capsule head (two filled circles joined by
                        // a rect) on a U-shaped stand, with a stem and base
                        // - built from arcs and lines rather than a font
                        // glyph.
                        const r2 = w * 0.15
                        const topY = h * 0.10 + r2
                        const botY = h * 0.50
                        ctx.beginPath(); ctx.arc(cx, topY, r2, 0, Math.PI * 2); ctx.fill()
                        ctx.beginPath(); ctx.arc(cx, botY, r2, 0, Math.PI * 2); ctx.fill()
                        ctx.fillRect(cx - r2, topY, r2 * 2, botY - topY)

                        ctx.beginPath()
                        ctx.arc(cx, botY - r2 * 0.2, w * 0.30, 0.15, Math.PI - 0.15, false)
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.moveTo(cx, botY + w * 0.14)
                        ctx.lineTo(cx, h * 0.86)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(w * 0.30, h * 0.86)
                        ctx.lineTo(w * 0.70, h * 0.86)
                        ctx.stroke()

                        if (isMuted) {
                            ctx.beginPath()
                            ctx.moveTo(w * 0.14, h * 0.14)
                            ctx.lineTo(w * 0.86, h * 0.86)
                            ctx.stroke()
                        }
                    }
                }
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: track
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => slider.applyFromX(mouse.x)
            onPositionChanged: mouse => { if (pressed) slider.applyFromX(mouse.x) }
        }
    }
}
