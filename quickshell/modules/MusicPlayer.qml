import QtQuick
import Quickshell.Services.Mpris

// Music player: shows the active MPRIS player's track info, progress, and
// transport controls. Self-contained, like Idle.qml - shell.qml only tells
// it whether it's the currently active island view via "active"; everything
// else (which player is "the" player, position ticking, formatting) lives
// here.
Item {
    id: root

    required property bool active

    // Prefer whichever player is actually playing. If nothing is playing,
    // fall back to the first available player so a paused track still
    // shows something instead of an empty pill.
    readonly property var _players: Mpris.players.values
    readonly property var player: {
        for (let i = 0; i < _players.length; i++) {
            if (_players[i].isPlaying) return _players[i]
        }
        return _players.length > 0 ? _players[0] : null
    }
    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: hasPlayer && player.isPlaying

    // MPRIS position doesn't update on its own (per the Quickshell docs) -
    // nudge it once a second while actually playing and visible, so the
    // progress bar and elapsed time move without polling when nobody's
    // looking.
    Timer {
        interval: 1000
        repeat: true
        running: root.active && root.isPlaying
        onTriggered: root.player.positionChanged()
    }

    function formatTime(seconds) {
        const total = Math.max(0, Math.round(seconds || 0))
        const m = Math.floor(total / 60)
        const s = total % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        visible: root.hasPlayer

        Row {
            width: parent.width
            spacing: 10

            Rectangle {
                width: 46; height: 46; radius: 9
                color: "#242428"
                clip: true
                Image {
                    anchors.fill: parent
                    source: root.hasPlayer ? (root.player.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: source !== ""
                    asynchronous: true
                }
            }

            Column {
                width: parent.width - 46 - 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    width: parent.width
                    text: root.hasPlayer ? (root.player.trackTitle || "Unknown title") : ""
                    color: "#f5f5f7"; font.pixelSize: 14; font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.hasPlayer ? (root.player.trackArtist || "Unknown artist") : ""
                    color: "#a8a8ad"; font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }

        Column {
            width: parent.width
            spacing: 5

            Rectangle {
                width: parent.width; height: 4; radius: 2; color: "#27272b"
                Rectangle {
                    height: parent.height; radius: parent.radius; color: "#f5f5f7"
                    width: root.hasPlayer && root.player.length > 0
                        ? parent.width * Math.max(0, Math.min(1, root.player.position / root.player.length))
                        : 0
                }
            }
            Row {
                width: parent.width
                Text { text: root.hasPlayer ? root.formatTime(root.player.position) : "0:00"; color: "#8e8e93"; font.pixelSize: 10 }
                Item { width: parent.width - 70; height: 1 }
                Text { text: root.hasPlayer ? root.formatTime(root.player.length) : "0:00"; color: "#8e8e93"; font.pixelSize: 10 }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 26

            Text {
                text: "\uf048"
                font.family: "FontAwesome"; font.pixelSize: 14
                color: root.hasPlayer && root.player.canGoPrevious ? "#f5f5f7" : "#4c4c4f"
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    enabled: root.hasPlayer && root.player.canGoPrevious
                    onClicked: root.player.previous()
                }
            }
            Text {
                text: root.isPlaying ? "\uf04c" : "\uf04b"
                font.family: "FontAwesome"; font.pixelSize: 16
                color: root.hasPlayer && root.player.canTogglePlaying ? "#f5f5f7" : "#4c4c4f"
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    enabled: root.hasPlayer && root.player.canTogglePlaying
                    onClicked: root.player.togglePlaying()
                }
            }
            Text {
                text: "\uf051"
                font.family: "FontAwesome"; font.pixelSize: 14
                color: root.hasPlayer && root.player.canGoNext ? "#f5f5f7" : "#4c4c4f"
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    enabled: root.hasPlayer && root.player.canGoNext
                    onClicked: root.player.next()
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !root.hasPlayer
        text: "No media playing"
        color: "#8e8e93"
        font.pixelSize: 12
    }
}
