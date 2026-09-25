import QtQuick

// Shared design tokens - colors, corner radii, spacing, and timing used
// across every module. Every module instantiates its own local copy
// (Theme { id: theme }) rather than reaching for a singleton: everything
// in here is a static constant, so a separate instance per module is
// functionally identical to a shared one, and it means this stays a
// plain type usable through the same directory-relative import every
// other module already relies on - no qmldir/pragma Singleton needed.
//
// The corner radii in particular exist to close a real bug: shell.qml's
// notchShape paints a specific corner radius per island state, and any
// module rendered inside that state has to match it exactly or the
// rounded backdrop shows a seam against the notch shape underneath.
// Before this file existed, that value was hardcoded separately in both
// places (shell.qml's Canvas and MusicPlayer.qml's own cornerRadius
// property) with nothing keeping them in sync.
QtObject {
    id: theme

    // ---- Palette ------------------------------------------------------
    readonly property color bgAmoled: "#000000"
    readonly property color surface: "#0c0c0f"
    readonly property color surfaceAlt: "#18181b"
    readonly property color surfaceHover: "#232326"
    readonly property color cardBorder: "#1c1c22"
    readonly property color track: "#27272b"

    readonly property color textPrimary: "#f5f5f7"
    readonly property color textSecondary: "#a8a8ad"
    readonly property color textTertiary: "#8e8e93"
    readonly property color textFaint: "#5a5a5f"
    readonly property color textDisabled: "#4c4c4f"
    // Icon tint for glyphs drawn on top of a light-colored fill (e.g. the
    // play button, or a slider's icon once the fill has passed under it).
    readonly property color iconOnLight: "#050505"

    // Catppuccin-Mocha-inspired accents, shared by every module that
    // needs a fixed (non-extracted) accent color for a specific meaning.
    readonly property color accentCpu: "#cba6f7"
    readonly property color accentGpu: "#89b4fa"
    readonly property color accentRam: "#f5c2e7"
    readonly property color accentDisk: "#94e2d5"
    readonly property color accentBattery: "#a6e3a1"
    readonly property color accentError: "#f38ba8"
    readonly property color accentDisplay: "#f9e2af"
    readonly property color accentSound: "#89dceb"
    readonly property color accentMic: "#fab387"
    // MusicPlayer's fallback when there's no album art to sample a color
    // from (or before it loads) - reuses accentCpu's mauve so the card
    // still has a coherent, deliberate mood rather than defaulting to grey.
    readonly property color accentMusicFallback: accentCpu

    readonly property string fontFamily: "Inter, SF Pro Text, Roboto, sans-serif"

    // ---- Corner radii, one per island state ----------------------------
    // Must stay in sync with shell.qml's notchShape corner-radius logic.
    readonly property int radiusIdle: 15
    readonly property int radiusOsd: 18
    readonly property int radiusPlayer: 20
    readonly property int radiusPanel: 26

    // ---- Spacing scale (4px base unit) ---------------------------------
    readonly property int spacingXs: 4
    readonly property int spacingSm: 8
    readonly property int spacingMd: 12
    readonly property int spacingLg: 16
    readonly property int spacingXl: 24

    // ---- Animation timing ------------------------------------------------
    readonly property int durationInstant: 110
    readonly property int durationFast: 150
    readonly property int durationBase: 180
    readonly property int durationSlow: 300
    readonly property int durationReveal: 420

    // Restyles just the alpha channel of an existing color - QML has no
    // built-in for this (Qt.alpha() doesn't exist).
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
