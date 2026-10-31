-- Kuber — autostart. Everything the desktop needs, nothing else.
-- No browser, no second bar, no tray-spam.

local HOME    = os.getenv("HOME")
local SCRIPTS = HOME .. "/.config/hypr/scripts"

-- Are we in a VM? hyprpaper / hyprlock crash in their aquamarine backend under
-- software GL (VirtualBox VMSVGA), so the wallpaper daemon is skipped there and
-- misc.background_color (look.lua) carries the desktop.
local function in_vm()
  local ok = os.execute("systemd-detect-virt --quiet")
  return ok == true or ok == 0
end
local VM = in_vm()

hl.on("hyprland.start", function()
  hl.exec_cmd(SCRIPTS .. "/lock.sh")

  -- Dark by default (no DE to hold this preference).
  hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
  hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark")

  hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
  hl.exec_cmd("mako")
  hl.exec_cmd("wl-paste --type text  --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")

  if not VM then
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd(SCRIPTS .. "/wallpaper.sh")
  end

  -- waybar reads ~/.config/waybar/config.jsonc as an ARRAY of bar configs —
  -- that's what gives the four corner HUD modules instead of one top strip.
  hl.exec_cmd("waybar")

  hl.exec_cmd(SCRIPTS .. "/drawer-banner.sh")
  hl.exec_cmd("hypridle")
end)

if not VM then
  hl.on("monitor.layout_changed", function()
    hl.exec_cmd(SCRIPTS .. "/wallpaper.sh")
  end)
end
