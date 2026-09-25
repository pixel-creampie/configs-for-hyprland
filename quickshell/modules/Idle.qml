import QtQuick
import Quickshell

// Idle view: what the notch shows when it's doing nothing else - not
// expanded into the control panel, not popped up with workspace/
// notification info, not visualising audio. Just the clock.
//
// This module is self-contained: it owns its own SystemClock rather than
// depending on one from shell.qml, so it can be dropped into any island
// slot on its own. shell.qml decides *when* it's idle and passes that in
// as a single "idle" flag - this component doesn't need to know about
// panelOpen, infoShowing, cava, or anything else that feeds into that
// decision.
Item {
    id: root

    required property bool idle

    // Shared design tokens - see modules/Theme.qml.
    Theme { id: theme }

    SystemClock { id: clock }

    Text {
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "h:mm")
        color: theme.textPrimary
        font.pixelSize: 13
        font.weight: Font.DemiBold
        font.family: theme.fontFamily

        opacity: root.idle ? 1 : 0
        scale: root.idle ? 1 : 0.88

        Behavior on opacity { NumberAnimation { duration: theme.durationBase; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: theme.durationBase; easing.type: Easing.OutCubic } }
    }
}
