-- Kuber — look and feel.
-- Black glass + corp red. rounding 0, border 2. Motion is a hard snap — a
-- targeting reticle locking on, not a fade. No screen shader for now (the
-- animated-shader cost lesson from Skemos: a `time` uniform forces damage
-- tracking off everywhere — if a shader is added later here, keep it static).

local c = require("colors")

hl.config({
  general = {
    border_size      = 2,
    gaps_in          = 4,
    gaps_out         = 10,
    gaps_workspaces  = 0,
    layout           = "dwindle",
    resize_on_border = true,
    hover_icon_on_border = false,
    allow_tearing    = false,

    col = {
      active_border          = c.rgba.accent,    -- focused = corp red
      inactive_border        = c.rgba.rule,
      nogroup_border         = c.rgba.rule,
      nogroup_border_active  = c.rgba.accent,
    },

    snap = { enabled = true },
  },

  decoration = {
    rounding          = 0,
    rounding_power    = 2,
    active_opacity    = 1.0,
    inactive_opacity  = 0.96,   -- unfocused windows recede a hair — focus reads as "locked on"
    fullscreen_opacity = 1.0,
    dim_inactive      = false,
    dim_around        = 0.0,
    dim_special       = 0.45,

    blur   = { enabled = false },
    shadow = { enabled = false },
    glow        = { enabled = false },
    motion_blur = { enabled = false },
  },

  dwindle = {
    preserve_split = true,
    smart_split    = false,
    smart_resizing = true,
    default_split_ratio = 1.0,
  },

  misc = {
    disable_hyprland_logo     = true,
    disable_splash_rendering  = true,
    force_default_wallpaper   = 0,
    background_color          = "rgb(" .. c.hex.bg .. ")",
    focus_on_activate         = false,
    middle_click_paste        = false,
    enable_swallow            = false,
    key_press_enables_dpms    = true,
    mouse_move_enables_dpms   = true,
  },

  input = {
    kb_layout    = "us",
    follow_mouse = 1,
    sensitivity  = 0,
    accel_profile = "flat",
    numlock_by_default = true,
    repeat_delay = 300,
    repeat_rate  = 40,
    touchpad = {
      natural_scroll       = true,
      disable_while_typing = true,
      tap_to_click         = true,
      clickfinger_behavior = true,
    },
  },

  gestures = { workspace_swipe_distance = 300 },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- ---- Motion: lock-on snap, not a dissolve -----------------------------
-- Faster and harder than Skemos's "fast mechanical": near-zero ease-in, an
-- abrupt stop, like a UI element snapping to a grid point under servo
-- control. No slide anywhere except the panel/launcher edge-ins (rules.lua),
-- which get a slightly longer, deliberate travel — a panel sliding into a
-- rail, not a window animating.
hl.config({ animations = { enabled = true } })

hl.curve("kbLinear", { type = "bezier", points = { { 0.0, 0.0 }, { 1.0, 1.0 } } })
hl.curve("kbSnap",   { type = "bezier", points = { { 0.1, 0.0 }, { 0.0, 1.0 } } })  -- near-instant, no overshoot
hl.curve("kbGone",   { type = "bezier", points = { { 0.0, 0.85 }, { 0.1, 1.0 } } }) -- front-loaded cut
hl.curve("kbRail",   { type = "bezier", points = { { 0.16, 1.0 }, { 0.3, 1.0 } } }) -- panel travel, hard stop

hl.animation({ leaf = "global", enabled = true, speed = 8, bezier = "kbSnap" })

hl.animation({ leaf = "windows",     enabled = true, speed = 7,  bezier = "kbSnap", style = "popin 98%" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 7,  bezier = "kbSnap", style = "popin 98%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 16, bezier = "kbGone", style = "popin 99%" })
hl.animation({ leaf = "windowsMove", enabled = false })

hl.animation({ leaf = "fade",   enabled = true, speed = 7,  bezier = "kbLinear" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 7,  bezier = "kbLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 16, bezier = "kbGone" })

-- border: colour change on focus is instant; a thin red glow would be ideal
-- here but Hyprland's border is a flat colour, not a real glow — decoration
-- stays flat and lets the colour jump do the work.
hl.animation({ leaf = "border",      enabled = false })
hl.animation({ leaf = "borderangle", enabled = false })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 7,  bezier = "kbSnap", style = "slidefade 8%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 8,  bezier = "kbSnap", style = "slidevert" })
hl.animation({ leaf = "layers",           enabled = true, speed = 10, bezier = "kbRail", style = "slidefade 6%" })
