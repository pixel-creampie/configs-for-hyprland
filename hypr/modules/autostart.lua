--Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
---------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- hl.on("hyprland.start", function ()
--   hl.exec_cmd(terminal)
--   hl.exec_cmd("nm-applet")
--   hl.exec_cmd("waybar & hyprpaper & firefox")
-- end)

hl.on("hyprland.start", function()
--    hl.exec_cmd("hyprpaper")
--    hl.exec_cmd("waybar")
--    hl.exec_cmd("swaync")
    hl.exec_cmd("swww-daemon")
    hl.exec_cmd("quickshell")
    hl.exec_cmd("hypridle")
end)
