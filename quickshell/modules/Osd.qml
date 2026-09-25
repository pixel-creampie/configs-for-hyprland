import QtQuick

// On-screen display: the transient popup the notch morphs into when
// brightness or volume changes from outside the panel - i.e. the hardware
// keys on your keyboard. shell.qml detects the change and drives "kind"
// and "value"; this module only renders.
Item {
    id: root

    // Shared design tokens - see modules/Theme.qml.
    Theme { id: theme }

    // "brightness" | "volume" | ""
    required property string kind
    required property int value
    property bool muted: false
    required property bool shown

    readonly property color accent: kind === "brightness" ? theme.accentDisplay : theme.accentSound

    Row {
        anchors.centerIn: parent
        width: parent.width - 44
        spacing: 14

        Canvas {
            id: icon
            width: 20; height: 20
            anchors.verticalCenter: parent.verticalCenter
            antialiasing: true

            property string kind: root.kind
            property bool muted: root.muted
            property color tint: root.accent
            onKindChanged: requestPaint()
            onMutedChanged: requestPaint()
            onTintChanged: requestPaint()
            onWidthChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                const w = width, h = height
                const cx = w / 2, cy = h / 2
                ctx.reset()
                ctx.clearRect(0, 0, w, h)
                ctx.fillStyle = tint
                ctx.strokeStyle = tint
                ctx.lineWidth = Math.max(1.4, w * 0.09)
                ctx.lineCap = "round"

                if (kind === "brightness") {
                    ctx.beginPath()
                    ctx.arc(cx, cy, w * 0.20, 0, Math.PI * 2)
                    ctx.fill()
                    for (let i = 0; i < 8; i++) {
                        const a = (Math.PI / 4) * i
                        ctx.beginPath()
                        ctx.moveTo(cx + Math.cos(a) * w * 0.32, cy + Math.sin(a) * w * 0.32)
                        ctx.lineTo(cx + Math.cos(a) * w * 0.45, cy + Math.sin(a) * w * 0.45)
                        ctx.stroke()
                    }
                } else {
                    ctx.beginPath()
                    ctx.moveTo(w * 0.10, h * 0.36)
                    ctx.lineTo(w * 0.28, h * 0.36)
                    ctx.lineTo(w * 0.50, h * 0.14)
                    ctx.lineTo(w * 0.50, h * 0.86)
                    ctx.lineTo(w * 0.28, h * 0.64)
                    ctx.lineTo(w * 0.10, h * 0.64)
                    ctx.closePath()
                    ctx.fill()

                    if (muted) {
                        // Slash through the speaker instead of the waves.
                        ctx.beginPath()
                        ctx.moveTo(w * 0.60, h * 0.30)
                        ctx.lineTo(w * 0.90, h * 0.70)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(w * 0.90, h * 0.30)
                        ctx.lineTo(w * 0.60, h * 0.70)
                        ctx.stroke()
                    } else {
                        ctx.beginPath()
                        ctx.arc(w * 0.52, cy, w * 0.20, -Math.PI / 3, Math.PI / 3)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.arc(w * 0.52, cy, w * 0.33, -Math.PI / 3, Math.PI / 3)
                        ctx.stroke()
                    }
                }
            }
        }

        Rectangle {
            id: track
            width: parent.width - icon.width - 44 - parent.spacing * 2
            height: 6
            radius: 3
            color: theme.track
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                height: parent.height
                radius: parent.radius
                width: parent.width * Math.max(0, Math.min(1, root.muted ? 0 : root.value / 100))
                color: root.accent
                Behavior on width { NumberAnimation { duration: theme.durationFast; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            width: 38
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: root.muted ? "—" : root.value + "%"
            color: theme.textPrimary
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.family: theme.fontFamily
        }
    }

    opacity: root.shown ? 1 : 0
    scale: root.shown ? 1 : 0.9
    Behavior on opacity { NumberAnimation { duration: theme.durationBase; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: theme.durationBase; easing.type: Easing.OutCubic } }
}
