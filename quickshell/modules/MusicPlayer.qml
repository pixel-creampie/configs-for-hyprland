import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris

// Music player: an "ambient" now-playing card. The whole card takes its
// mood from the current track - a dominant color sampled from the album
// art drives the progress bar, the play-button glow, and the border, and
// a blurred copy of the art fills the backdrop behind everything, the
// same way Spotify/Apple Music's expanded now-playing views work.
Item {
    id: root

    required property bool active

    // Shared design tokens - see modules/Theme.qml.
    Theme { id: theme }

    // Prefer whichever player is playing; fall back to the first available.
    readonly property var _players: Mpris.players.values
    readonly property var player: {
        for (let i = 0; i < _players.length; i++) {
            if (_players[i].isPlaying) return _players[i]
        }
        return _players.length > 0 ? _players[0] : null
    }
    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: hasPlayer && player.isPlaying
    readonly property bool canSeek: hasPlayer && player.canSeek && player.length > 0
    readonly property real progress: hasPlayer && player.length > 0
        ? Math.max(0, Math.min(1, player.position / player.length)) : 0
    readonly property string artUrl: hasPlayer ? (player.trackArtUrl || "") : ""

    // Fed from shell.qml (theme.radiusPlayer) rather than hardcoded here,
    // so the blurred backdrop's rounded corners always match whatever
    // corner radius shell.qml's notchShape actually paints for this
    // state. Still defaults to the theme's own value, so this module
    // degrades gracefully even if a caller forgets to set it explicitly.
    property int cornerRadius: theme.radiusPlayer

    // Dominant color sampled from the album art (see colorSampler below).
    // Falls back to the theme's default whenever there's no art to sample
    // - before it loads, or when nothing is playing at all - so the card
    // always has a coherent accent rather than defaulting to grey.
    property color accent: theme.accentMusicFallback

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    function formatTime(seconds) {
        const total = Math.max(0, Math.round(seconds || 0))
        const m = Math.floor(total / 60)
        const s = total % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    // Standard HSL round-trip, used to push whatever color comes out of
    // the raw pixel average into a range that reliably reads as "a color"
    // against black - covers with low-contrast or very dark artwork would
    // otherwise average out to a muddy, near-invisible grey.
    function rgbToHsl(r, g, b) {
        r /= 255; g /= 255; b /= 255
        const max = Math.max(r, g, b), min = Math.min(r, g, b)
        const l = (max + min) / 2
        let h = 0, s = 0
        const d = max - min
        if (d !== 0) {
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
            if (max === r) h = ((g - b) / d + (g < b ? 6 : 0))
            else if (max === g) h = (b - r) / d + 2
            else h = (r - g) / d + 4
            h /= 6
        }
        return [h, s, l]
    }
    function hslToRgb(h, s, l) {
        function hue2rgb(p, q, t) {
            if (t < 0) t += 1
            if (t > 1) t -= 1
            if (t < 1 / 6) return p + (q - p) * 6 * t
            if (t < 1 / 2) return q
            if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
            return p
        }
        let r, g, b
        if (s === 0) { r = g = b = l }
        else {
            const q = l < 0.5 ? l * (1 + s) : l + s - l * s
            const p = 2 * l - q
            r = hue2rgb(p, q, h + 1 / 3)
            g = hue2rgb(p, q, h)
            b = hue2rgb(p, q, h - 1 / 3)
        }
        return [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)]
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active && root.isPlaying
        onTriggered: if (root.player) root.player.positionChanged()
    }

    // Hidden probe used purely to sample a dominant color from the current
    // album art - never shown itself, only read from by colorSampler.
    Image {
        id: artProbe
        source: root.artUrl
        asynchronous: true
        visible: false
        onStatusChanged: if (status === Image.Ready) colorSampler.requestPaint()
    }

    // Drawing the art down to 8x8 before sampling keeps getImageData()'s
    // loop tiny regardless of the source image's real resolution - a
    // known slow point if you sample a full-size image directly.
    Canvas {
        id: colorSampler
        width: 8; height: 8
        visible: false
        onPaint: {
            if (artProbe.status !== Image.Ready) return
            const ctx = getContext("2d")
            try {
                ctx.reset()
                ctx.drawImage(artProbe, 0, 0, width, height)
                const data = ctx.getImageData(0, 0, width, height).data
                let r = 0, g = 0, b = 0, n = 0
                for (let i = 0; i < data.length; i += 4) {
                    r += data[i]; g += data[i + 1]; b += data[i + 2]; n++
                }
                if (n === 0) return
                const hsl = root.rgbToHsl(r / n, g / n, b / n)
                const s = Math.max(0.5, Math.min(1, hsl[1] * 1.3))
                const l = Math.max(0.55, Math.min(0.72, hsl[2]))
                const rgb = root.hslToRgb(hsl[0], s, l)
                root.accent = Qt.rgba(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1)
            } catch (e) {
                // Drawing an exotic image source (unusual URL scheme, a
                // load that raced the status change, etc.) can throw here
                // - fall back to the fixed accent rather than leaving a
                // half-updated color or crashing the card.
                root.accent = theme.accentMusicFallback
            }
        }
    }

    // ---- Backdrop: blurred art + scrim, clipped to the notch's rounding
    Rectangle {
        id: backdrop
        anchors.fill: parent
        radius: root.cornerRadius
        clip: true
        color: theme.bgAmoled
        border.width: 1
        border.color: root.tint(root.accent, 0.28)
        Behavior on border.color { ColorAnimation { duration: 420 } }

        // Ambient wash - always present, even with no art, so the card
        // never falls back to flat black.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: root.tint(root.accent, 0.22) }
                GradientStop { position: 1.0; color: theme.bgAmoled }
            }
        }

        Image {
            id: bgArt
            anchors.fill: parent
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: bgArt
            source: bgArt
            visible: bgArt.status === Image.Ready
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: 0.15
            brightness: -0.12
        }

        // Dark scrim over the blurred art so text stays legible no matter
        // how bright the source artwork is.
        Rectangle {
            anchors.fill: parent
            visible: bgArt.status === Image.Ready
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.30) }
                GradientStop { position: 0.55; color: Qt.rgba(0.01, 0.01, 0.02, 0.72) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.90) }
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12
        visible: root.hasPlayer

        Row {
            width: parent.width
            spacing: 14

            // Circular art, slowly spinning while playing - pauses in
            // place (not reset) whenever playback pauses.
            Item {
                id: artFrame
                width: 64; height: 64
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: artClip
                    anchors.fill: parent
                    radius: width / 2
                    clip: true
                    color: theme.surfaceAlt
                    border.width: 1.5
                    border.color: root.tint(root.accent, 0.55)
                    Behavior on border.color { ColorAnimation { duration: 420 } }

                    Text {
                        anchors.centerIn: parent
                        text: "♫"
                        color: theme.textFaint
                        font.pixelSize: 22
                        visible: fgArt.status !== Image.Ready
                    }

                    Image {
                        id: fgArt
                        anchors.fill: parent
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready

                        RotationAnimation on rotation {
                            running: root.isPlaying
                            from: 0; to: 360
                            duration: 12000
                            loops: Animation.Infinite
                        }
                    }
                }
            }

            Column {
                width: parent.width - artFrame.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: root.hasPlayer ? (root.player.trackTitle || "Unknown title") : ""
                    color: theme.textPrimary; font.pixelSize: 15; font.weight: Font.Bold; font.family: theme.fontFamily
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.hasPlayer ? (root.player.trackArtist || "Unknown artist") : ""
                    color: theme.textSecondary; font.pixelSize: 12; font.family: theme.fontFamily
                    elide: Text.ElideRight
                }
            }
        }

        Column {
            width: parent.width
            spacing: 5

            // Taller than the visible track so it's easy to grab, without
            // the extra height throwing off the mouse.x / width fraction.
            Item {
                id: scrubZone
                width: parent.width
                height: 16

                Rectangle {
                    id: progressTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: scrubArea.containsMouse || scrubArea.pressed ? 6 : 4
                    radius: height / 2
                    color: theme.track
                    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Rectangle {
                        id: progressFill
                        height: parent.height; radius: parent.radius
                        width: parent.width * root.progress
                        Behavior on width { enabled: !scrubArea.pressed; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: root.tint(root.accent, 0.65) }
                            GradientStop { position: 1.0; color: root.accent }
                        }
                    }

                    Rectangle {
                        width: 10; height: 10; radius: 5; color: theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.min(parent.width - width, Math.max(0, progressFill.width - width / 2))
                        opacity: root.canSeek && (scrubArea.containsMouse || scrubArea.pressed) ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }

                MouseArea {
                    id: scrubArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: mouse => root.player.position = Math.max(0, Math.min(1, mouse.x / width)) * root.player.length
                    onPositionChanged: mouse => { if (pressed) root.player.position = Math.max(0, Math.min(1, mouse.x / width)) * root.player.length }
                }
            }

            Row {
                width: parent.width
                Text { text: root.hasPlayer ? root.formatTime(root.player.position) : "0:00"; color: theme.textTertiary; font.pixelSize: 10; font.family: theme.fontFamily }
                Item { width: parent.width - 70; height: 1 }
                Text { text: root.hasPlayer ? root.formatTime(root.player.length) : "0:00"; color: theme.textTertiary; font.pixelSize: 10; font.family: theme.fontFamily }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 22

            // Previous
            Rectangle {
                width: 32; height: 32; radius: 16
                anchors.verticalCenter: parent.verticalCenter
                color: prevArea.containsMouse ? theme.surfaceHover : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Canvas {
                    width: 15; height: 15
                    anchors.centerIn: parent
                    property color tint: root.hasPlayer && root.player.canGoPrevious ? theme.textPrimary : theme.textDisabled
                    onTintChanged: requestPaint()
                    onPaint: root.paintTransportIcon(getContext("2d"), "previous", width, height, tint)
                }
                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.hasPlayer && root.player.canGoPrevious
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.player.previous()
                }
            }

            // Play / pause - the primary action: solid fill plus a soft
            // glow in the track's own accent color behind it.
            Item {
                width: 40; height: 40
                anchors.verticalCenter: parent.verticalCenter

                MultiEffect {
                    anchors.fill: playButton
                    source: playButton
                    shadowEnabled: true
                    shadowColor: root.accent
                    shadowBlur: 0.7
                    shadowOpacity: root.hasPlayer ? 0.75 : 0
                    blurEnabled: false
                    Behavior on shadowOpacity { NumberAnimation { duration: 300 } }
                }

                Rectangle {
                    id: playButton
                    anchors.fill: parent
                    radius: width / 2
                    color: !root.hasPlayer || !root.player.canTogglePlaying ? "#3a3a3c"
                         : playArea.pressed ? root.tint(root.accent, 0.85) : theme.textPrimary
                    Behavior on color { ColorAnimation { duration: 120 } }
                    scale: playArea.pressed ? 0.94 : 1
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                    Canvas {
                        width: 16; height: 16
                        anchors.centerIn: parent
                        property string kind: root.isPlaying ? "pause" : "play"
                        property color tint: !root.hasPlayer || !root.player.canTogglePlaying ? "#7d7d80" : theme.iconOnLight
                        onKindChanged: requestPaint()
                        onTintChanged: requestPaint()
                        onPaint: root.paintTransportIcon(getContext("2d"), kind, width, height, tint)
                    }

                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.hasPlayer && root.player.canTogglePlaying
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.player.togglePlaying()
                    }
                }
            }

            // Next
            Rectangle {
                width: 32; height: 32; radius: 16
                anchors.verticalCenter: parent.verticalCenter
                color: nextArea.containsMouse ? theme.surfaceHover : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Canvas {
                    width: 15; height: 15
                    anchors.centerIn: parent
                    property color tint: root.hasPlayer && root.player.canGoNext ? theme.textPrimary : theme.textDisabled
                    onTintChanged: requestPaint()
                    onPaint: root.paintTransportIcon(getContext("2d"), "next", width, height, tint)
                }
                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.hasPlayer && root.player.canGoNext
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.player.next()
                }
            }
        }
    }

    // Every transport icon is drawn here instead of pulled from an icon
    // font, so it renders identically whether or not any particular font
    // happens to be installed. kind is one of "play"/"pause"/"previous"/"next".
    function paintTransportIcon(ctx, kind, w, h, color) {
        const cx = w / 2, cy = h / 2
        const r = Math.min(w, h) / 2
        ctx.reset()
        ctx.fillStyle = color

        if (kind === "play") {
            ctx.beginPath()
            ctx.moveTo(cx - r * 0.42, cy - r * 0.62)
            ctx.lineTo(cx - r * 0.42, cy + r * 0.62)
            ctx.lineTo(cx + r * 0.68, cy)
            ctx.closePath()
            ctx.fill()
            return
        }
        if (kind === "pause") {
            ctx.fillRect(cx - r * 0.5, cy - r * 0.6, r * 0.38, r * 1.2)
            ctx.fillRect(cx + r * 0.12, cy - r * 0.6, r * 0.38, r * 1.2)
            return
        }

        // previous / next: two triangles plus a bar, mirrored by direction
        const sign = kind === "next" ? 1 : -1
        const seg = t => cx + sign * t * r

        ctx.beginPath()
        ctx.moveTo(seg(0), cy - r * 0.5)
        ctx.lineTo(seg(0), cy + r * 0.5)
        ctx.lineTo(seg(0.32), cy)
        ctx.closePath()
        ctx.fill()

        ctx.beginPath()
        ctx.moveTo(seg(0.32), cy - r * 0.5)
        ctx.lineTo(seg(0.32), cy + r * 0.5)
        ctx.lineTo(seg(0.64), cy)
        ctx.closePath()
        ctx.fill()

        const barX0 = seg(0.74), barX1 = seg(0.88)
        ctx.fillRect(Math.min(barX0, barX1), cy - r * 0.5, Math.max(1, Math.abs(barX1 - barX0)), r * 1.0)
    }

    // Empty state, over the same ambient backdrop (using the fallback
    // accent) rather than falling back to plain text on flat black.
    Column {
        anchors.centerIn: parent
        visible: !root.hasPlayer
        spacing: 8

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44; height: 44; radius: 22
            color: root.tint(root.accent, 0.12)
            border.width: 1
            border.color: root.tint(root.accent, 0.3)
            Text {
                anchors.centerIn: parent
                text: "♫"
                color: root.tint(root.accent, 0.9)
                font.pixelSize: 18
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No media playing"
            color: theme.textTertiary
            font.pixelSize: 12
            font.family: theme.fontFamily
        }
    }
}
