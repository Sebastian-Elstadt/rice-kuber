-- ============================================================================
--  Kuber — Hyprland entrypoint
--  Black-glass corp terminal, one red accent. Corner-HUD bar, not a top strip.
--  Config language: Lua (hyprlang is deprecated since Hyprland 0.55).
--  Split into modules under ~/.config/hypr/ ; order below matters.
-- ============================================================================

-- GPU pin: same machine as Skemos (saber — NVIDIA RTX 5070 + AMD iGPU). See
-- Skemos's hypr/hyprland.lua for the full writeup of why this is pinned; the
-- short version: the NVIDIA card must be primary or Aquamarine's pick races
-- boot to boot. Verify after a reboot with `hyprctl systeminfo`.
hl.env("AQ_DRM_DEVICES", "/dev/dri/card0:/dev/dri/card1")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

require("colors")     -- palette (no side effects, just data)
require("monitors")   -- outputs — generic, no hardcoded connector
require("look")       -- rounding 0, border 2, lock-on snap motion
require("rules")      -- window/workspace rules (AFTER look)
require("binds")      -- keybindings (pulls in modes + minimize)
require("autostart")  -- waybar (4 corner modules), hyprpaper, mako, hypridle, polkit, cliphist
