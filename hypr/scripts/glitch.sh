#!/usr/bin/env bash
# Kuber — glitch burst: flashes two broken-signal shaders for ~90ms, then
# restores the base shader and hands off to whatever command was given.
# Punctuates a HUD element opening (rofi, window switcher, security panel)
# — bound only to those, not to everyday actions, same "reserve the
# flourish" philosophy as hypr/look.lua's kbPop curve.
#
# All three shaders involved are static (no `time` uniform) — the flicker
# is from swapping WHICH shader is bound across a few discrete steps, not
# from anything animated within one, so damage tracking stays on and the
# cost is a handful of one-off full redraws, not a sustained per-frame one.
#
# Usage: glitch.sh [cmd args...]   — runs the burst, then execs cmd if given.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../shaders" && pwd)"
BASE="$DIR/kuber.frag"
A="$DIR/glitch_a.frag"
B="$DIR/glitch_b.frag"

# This config is loaded via the Lua `hl` API, not hyprlang — `hyprctl
# keyword` only works against the legacy keyword parser ("keyword can't
# work with non-legacy parsers. Use eval." — confirmed live) and silently
# fails here. `hyprctl eval` runs a Lua string against the same hl.config()
# call look.lua uses to set the shader at startup.
flash() { hyprctl eval "hl.config({decoration={screen_shader=\"$1\"}})" >/dev/null 2>&1 || true; }

flash "$A"; sleep 0.03
flash "$B"; sleep 0.03
flash "$A"; sleep 0.03
flash "$BASE"

if [[ $# -gt 0 ]]; then exec "$@"; fi
