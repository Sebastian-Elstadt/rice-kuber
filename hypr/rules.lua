-- Kuber — window & workspace rules.

local c = require("colors")

-- Ignore app-driven maximize requests (tidier tiling).
hl.window_rule({
  name  = "kb-suppress-maximize",
  match = { class = ".*" },
  suppress_event = "maximize",
})

-- --- Hairline shadow: FLOATING windows only; tiled windows stay flat. -------
hl.config({
  decoration = {
    shadow = {
      enabled        = true,
      range          = 8,
      render_power   = 2,
      sharp          = true,            -- a hard-edged drop, not a soft glow
      offset         = { 0, 3 },
      color          = tonumber("0x77" .. c.hex.bg),
      color_inactive = tonumber("0x33" .. c.hex.bg),
    },
  },
})
hl.window_rule({ name = "kb-no-shadow-tiled", match = { float = false }, no_shadow = true })

-- --- Common floating dialogs -------------------------------------------------
hl.window_rule({
  match = { class = "^(pavucontrol|nm-connection-editor|blueman-manager|org.pulseaudio.pavucontrol)$" },
  float = true,
})
hl.window_rule({
  match  = { title = "^(Open File|Open Files|Save File|Save As|Choose Files|Select a File)$" },
  float  = true,
  center = true,
})

-- --- security panel: fixed panel on the LEFT edge, mirror of rofi -----------
-- Same placement contract as Skemos (muscle memory): SUPER+S toggles it.
hl.window_rule({
  name    = "kb-security-panel",
  match   = { class = "^kuber-security$" },
  float   = true,
  pin     = true,
  size    = "960 (monitor_h-46)",
  move    = "12 34",
  animation = "slide left",
})

-- --- special:minimized drawer --------------------------------------------
hl.workspace_rule({ workspace = "special:minimized", gaps_in = 10, gaps_out = 44 })

-- --- rofi launcher / window switcher: slide in from the right edge --------
hl.layer_rule({
  name      = "kb-rofi-slide",
  match     = { namespace = "^rofi$" },
  animation = "slide",
})
