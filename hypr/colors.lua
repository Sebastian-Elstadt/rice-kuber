-- Kuber — palette (single source of truth for the Hyprland side).
--
-- Direction: corporate-futurist, not industrial — a black-glass terminal
-- with one hard red accent (Arasaka/CP2077 corp-HUD, not rainbow neon).
-- Red is load-bearing: it means "focused / active / brand", never used for
-- more than one thing at a time per surface. A single cold cyan exists only
-- for live telemetry ticks (clock seconds, sensor values) so a vitals
-- readout doesn't have to borrow the brand colour.
--
-- Other components carry their own copy in their own syntax:
--   waybar/style.css, foot/foot.ini, kitty/kuber.conf,
--   rofi/kuber.rasi, mako/config, hyprlock.conf, scripts/wallpaper.sh.
--   Keep them in sync.

local M = {}

-- bare hex (no #)
M.hex = {
  bg        = "0a0a0d", -- near-black, cold (not warm like Skemos's paper)
  raised    = "121216", -- panels / notification cards / HUD modules
  ink       = "e8e8ec", -- primary "white" — cold, high contrast
  ink_dim   = "7d7d87", -- secondary text
  ink_faint = "35353d", -- grid lines, disabled, hairlines
  rule      = "232329", -- borders / separators
  accent    = "c81e2c", -- corp red — SPARSE (focus, brand, alerts)
  data      = "3dd6ff", -- cold cyan — telemetry ticks ONLY, never alerts/brand
}

local function rgba(h, a) return ("rgba(%s%s)"):format(h, a or "ff") end
M.rgba = {}
for k, v in pairs(M.hex) do M.rgba[k] = rgba(v) end

M.rgba_fn = rgba
return M
