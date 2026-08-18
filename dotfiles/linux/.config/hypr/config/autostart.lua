-- Auto-start config
-- if you dont use UWSM add your auto start programs here, otherwise use XDG autostart https://wiki.archlinux.org/title/XDG_Autostart

local home = os.getenv("HOME") or ""
local noctalia_bin = home .. "/.local/bin/noctalia"
local hdmi_audio_bin = home .. "/.local/bin/eva-hdmi-audio"

hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("env LC_TIME=C " .. noctalia_bin)
    hl.exec_cmd(hdmi_audio_bin)
    hl.exec_cmd("xhost +SI:localuser:root")
end)
