# Dynamic Island Notch — Quickshell config for Hyprland

Dynamic island for Hyprland, built on [Quickshell](https://quickshell.org).

**Features:** idle clock · MPRIS music player with album-art color extraction and a
blurred ambient backdrop · Material 3 Expressive system control centre (CPU, GPU, RAM,
disk, battery) · brightness/volume/mic sliders · hardware-key OSD popups · notification
toasts and a persistent notification panel · CAVA audio visualizer · click-outside-to-close.

This only runs on **Hyprland** — a few pieces (`Quickshell.Hyprland`, workspace detection,
`HyprlandFocusGrab`) are Hyprland-specific and won't work on other compositors.

---

## 1. Requirements

### Core (the shell won't start without these)

| Package | What it's for |
|---|---|
| `hyprland` | The compositor. This config uses Hyprland's IPC directly. |
| `quickshell` | The shell framework itself. |

### System integration (each feature degrades gracefully without its piece — see [Feature → dependency map](#3-feature--dependency-map) — but install all of these for everything to work)

| Package | What it's for |
|---|---|
| `wireplumber` | Volume + mic sliders and OSD (`wpctl`). |
| `pipewire-pulse` (Arch) / `pipewire-pulseaudio` (Fedora) | Fallback mic reading (`pactl`) on setups where WirePlumber hasn't resolved a default source. |
| `brightnessctl` | Brightness slider and OSD. |
| `upower` | Battery tile in the control centre. |
| `cava` | The audio-visualizer bars shown in the idle notch while audio plays. |
| `procps-ng` | `top`/`free`, used for CPU and RAM stats. Virtually always already installed. |
| `coreutils` | `df`, used for disk stats. Always already installed. |

### Optional

| Package | What it's for |
|---|---|
| NVIDIA driver (e.g. `nvidia-utils` / `akmod-nvidia`) | GPU tile, via `nvidia-smi`. AMD GPUs work automatically through the kernel's `amdgpu` sysfs node — no package needed. Without either, the GPU tile just doesn't appear (it's hidden, not broken). |
| An MPRIS-capable media player (Spotify, a browser, `mpv` with an MPRIS plugin, etc.) | Needed for the music player to show anything. Nothing to install for the shell itself. |
| `inter-font` (Arch) / `rsms-inter-fonts` (Fedora) | The UI's font. Falls back to your system sans-serif if missing — this is cosmetic, not required. |
| `qt6-svg` (Arch) / `qt6-qtsvg` (Fedora) | Needed for notification/app icons that come from SVG icon themes (most modern icon themes, e.g. Papirus, Adwaita) to render. |

`qt6-declarative` (Arch) / `qt6-qtdeclarative` (Fedora) provides `QtQuick.Layouts` and
`QtQuick.Effects` (used for the blur/glow effects in the music player). You shouldn't need
to install this yourself — it comes in as a dependency of the `quickshell` package — it's
listed here only so you know what it is if something ever comes up looking for it.

---

## 2. Install

### Arch Linux

```sh
# Hyprland + Quickshell
sudo pacman -S hyprland quickshell
# (for unreleased/master Quickshell instead: yay -S quickshell-git)

# System integration
sudo pacman -S wireplumber pipewire-pulse brightnessctl upower cava procps-ng coreutils

# Optional
sudo pacman -S qt6-svg
yay -S inter-font          # or any font — this is just the default font name in the config
```

### Fedora

Hyprland and Quickshell both need a COPR on Fedora — neither is in the official repos yet.

```sh
# Hyprland
sudo dnf copr enable solopasha/hyprland
sudo dnf install hyprland

# Quickshell
sudo dnf copr enable errornointernet/quickshell
sudo dnf install quickshell

# System integration
sudo dnf install wireplumber pipewire-pulseaudio brightnessctl upower cava procps-ng coreutils

# Optional
sudo dnf install qt6-qtsvg rsms-inter-fonts
```

---

## 3. Feature → dependency map

If something doesn't work, this is where to look. Every one of these fails *gracefully* —
a missing piece just means that one feature is inactive, not a crash.

| Feature | Needs | If missing |
|---|---|---|
| CPU / RAM / disk tiles | `procps-ng`, `coreutils` | These are on virtually every system already |
| CPU temperature badge | a `/sys/class/thermal/thermal_zone*` node reporting `x86_pkg_temp`/`coretemp`/`k10temp` | Badge just stays empty |
| GPU tile | `nvidia-smi` (NVIDIA) or the kernel's `amdgpu` driver (AMD) | Tile is hidden entirely, not shown broken |
| Battery tile | `upower` running (`systemctl status upower`) | Tile is hidden entirely |
| Brightness slider/OSD | `brightnessctl`, and a backlight your hardware actually exposes | Slider is inert |
| Volume slider/OSD | `wireplumber` | Slider is inert |
| Mic slider | `wireplumber`, falls back to `pipewire-pulse`/`pipewire-pulseaudio` | Reads 0% |
| Audio-visualizer bars | `cava` + a config at `~/.config/cava/config_notch` (see below) | Bars process fails silently; idle clock shows instead |
| Music player | any running MPRIS player | Shows "No media playing" |
| Notifications | nothing extra — but see the warning below | — |
| Click-outside-to-close | Hyprland specifically (`HyprlandFocusGrab`) | Won't work on other compositors |

---

## 4. Setup

### Place the files

Quickshell looks for `~/.config/quickshell/shell.qml` by default:

```sh
mkdir -p ~/.config/quickshell
cp shell.qml ~/.config/quickshell/
cp -r modules ~/.config/quickshell/
```

You should end up with:

```
~/.config/quickshell/
├── shell.qml
└── modules/
    ├── Theme.qml
    ├── Idle.qml
    ├── MusicPlayer.qml
    ├── SystemMenu.qml
    ├── Osd.qml
    ├── NotificationToast.qml
    └── NotificationPanel.qml
```

### CAVA config

The shell runs `cava -p ~/.config/cava/config_notch` — that file doesn't exist by default,
you need to create it. It must use raw/ASCII output with `;` as the delimiter (ASCII code
59) for the bars to parse correctly:

```sh
mkdir -p ~/.config/cava
cat > ~/.config/cava/config_notch << 'EOF'
[general]
bars = 8

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
EOF
```

### Autostart with Hyprland

Add this to `~/.config/hypr/hyprland.conf`:

```
exec-once = qs
```

(`qs` is Quickshell's CLI entrypoint; some packagings instead install it as `quickshell` —
if `qs` isn't found after installing, use `exec-once = quickshell` instead.)

### Disable any other notification daemon

This shell claims the `org.freedesktop.Notifications` D-Bus name itself (that's how the
toast/panel features work) — if you already run **mako**, **dunst**, **swaync**, or
anything similar, remove its `exec-once` line from `hyprland.conf` (or `systemctl --user
disable/stop` it) first. Two daemons fighting over that name means one of them silently
gets no notifications at all.

---

## 5. Reloading after changes

Quickshell hot-reloads on file save in most setups. If a change doesn't seem to apply, or
after editing `shell.qml` directly, restart it:

```sh
pkill quickshell; qs &
```

## 6. Troubleshooting

- **"Type Modules.X unavailable" / "Invalid property assignment: int expected"** — this
  usually means a numeric property is being given a fractional value (e.g. `font.pixelSize`
  is an `int` in QML; something like `9.5` will fail to load, not just look wrong). Check
  the error's line number against the file it names.
- **Notifications never arrive** — see the daemon-conflict warning above.
- **Nothing MPRIS-related shows up** — the player has to actually be running and exposing
  MPRIS; not all apps do this by default (some browsers only expose it while a tab is
  actively playing media).
- **GPU tile never appears** — expected if you're on an AMD/Intel iGPU without `nvidia-smi`
  and your kernel's `amdgpu` sysfs node isn't reporting `gpu_busy_percent` (varies by GPU
  generation). This tile is opt-in-by-detection, not guaranteed on every system.
