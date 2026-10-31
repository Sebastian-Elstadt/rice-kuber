#!/usr/bin/env bash
# Kuber — wallpaper generator + applier.
# Near-black field, a soft radial vignette for depth, one large faint
# off-center diamond mark, and a quiet red rule + wordmark in the corner.
# No grid, no brackets — that was too close to Skemos's drafting-sheet
# language. One image per resolution, cached. Portable: reads the real
# monitor list from hyprctl.
#
# Usage:
#   wallpaper.sh                 generate (if missing) + apply to every monitor
#   wallpaper.sh --force         regenerate even if cached, then apply
#   wallpaper.sh --preview WxH   just write ~/.cache/kuber/preview.png

set -euo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/kuber"
mkdir -p "$CACHE"

# --- palette (mirrors hypr/colors.lua) --------------------------------
BG="#0a0a0d"
INK="#e8e8ec"
INK_DIM="#7d7d87"
INK_FAINT="#35353d"
ACCENT="#c81e2c"

MARK_ALPHA=0.05    # diamond mark opacity — barely there
VIGNETTE_LO="#000000"   # edges
VIGNETTE_HI="#121216"   # centre of the glow (hypr/colors.lua "raised")
FONT="$(fc-match -f '%{file}' 'JetBrains Mono' 2>/dev/null || true)"

gen() { # gen W H OUTFILE
  local w=$1 h=$2 out=$3
  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp:-}"' RETURN

  # 1. base: a soft radial vignette, glow centred left-of-centre so the
  #    frame doesn't feel dead-symmetrical. Subtle — this is depth, not a
  #    spotlight.
  # radial-gradient: centres on its own canvas, so generate one twice the
  # final size (natural centre at w,h) and crop a WxH window offset so that
  # centre lands at (gx,gy) in the final image — simpler and more reliable
  # than distorting the gradient itself.
  local gx=$(( w * 42 / 100 )) gy=$(( h * 46 / 100 ))
  magick -size "$((w*2))x$((h*2))" radial-gradient:"${VIGNETTE_HI}-${VIGNETTE_LO}" \
    -crop "${w}x${h}+$((w-gx))+$((h-gy))" +repage \
    "$tmp/vign.png"
  # a hair of noise breaks up 8-bit banding rings on a gradient this subtle —
  # not a grain texture (too low to see as one), just a dither.
  magick -size "${w}x${h}" xc:gray50 -attenuate 0.4 +noise Gaussian \
    -colorspace Gray -channel A -evaluate set 3% +channel "$tmp/dither.png"
  magick -size "${w}x${h}" xc:"$BG" "$tmp/vign.png" -compose Screen -composite \
    "$tmp/dither.png" -compose Overlay -composite "$tmp/flat.png"

  # 2. one large diamond outline (a rotated square), off-centre, almost
  #    invisible — a single geometric mark instead of a schematic grid.
  local cx=$(( w * 60 / 100 )) cy=$(( h * 44 / 100 ))
  local r=$(( h * 42 / 100 ))
  local diamond="line ${cx},$((cy-r)) $((cx+r)),${cy} line $((cx+r)),${cy} ${cx},$((cy+r)) line ${cx},$((cy+r)) $((cx-r)),${cy} line $((cx-r)),${cy} ${cx},$((cy-r))"
  magick -size "${w}x${h}" xc:none -stroke "$INK" -strokewidth 2 -fill none \
    -draw "$diamond" "$tmp/markfull.png"
  magick "$tmp/markfull.png" -channel A -evaluate multiply "$MARK_ALPHA" +channel "$tmp/mark.png"
  magick "$tmp/flat.png" "$tmp/mark.png" -compose Over -composite "$tmp/marked.png"

  # 3. corner brand: a short red rule + wordmark, bottom-right. No plate,
  #    no box — just a rule and two lines of type.
  local bx=$(( w - 240 )) by=$(( h - 64 ))
  local tag; tag="$(date +%Y.%m.%d)"

  magick "$tmp/marked.png" \
    -stroke "$ACCENT" -strokewidth 2 -draw "line ${bx},${by} $((bx+40)),${by}" \
    ${FONT:+-font "$FONT"} -stroke none -fill "$INK" -pointsize 15 \
      -draw "text ${bx},$((by+26)) 'KUBER'" \
    -fill "$INK_DIM" -pointsize 10 \
      -draw "text ${bx},$((by+44)) \"CORP-01 · $tag\"" \
    -strip -define png:compression-level=9 -define png:compression-filter=5 "$out"
}

apply() {
  command -v hyprctl >/dev/null || { echo "no hyprctl; not applying" >&2; return 0; }
  for _ in $(seq 1 50); do
    hyprctl hyprpaper listloaded >/dev/null 2>&1 && break
    sleep 0.2
  done
  local force=$1
  mapfile -t MONS < <(hyprctl -j monitors | jq -r '.[] | "\(.name) \(.width) \(.height)"')
  local used=()
  for line in "${MONS[@]}"; do
    read -r name w h <<<"$line"
    local png="$CACHE/wall-${w}x${h}.png"
    if [[ "$force" == "1" || ! -f "$png" ]]; then gen "$w" "$h" "$png"; fi
    hyprctl hyprpaper preload "$png"             >/dev/null 2>&1 || true
    hyprctl hyprpaper wallpaper "${name},${png}" >/dev/null 2>&1 || true
    used+=("$png")
  done
  while read -r loaded; do
    [[ -z "$loaded" ]] && continue
    local keep=0
    for u in "${used[@]}"; do [[ "$u" == "$loaded" ]] && keep=1; done
    [[ $keep -eq 0 ]] && hyprctl hyprpaper unload "$loaded" >/dev/null 2>&1 || true
  done < <(hyprctl hyprpaper listloaded 2>/dev/null || true)
}

case "${1:-}" in
  --preview)
    read -r w h <<<"$(echo "${2:-1920x1080}" | tr 'x' ' ')"
    gen "$w" "$h" "$CACHE/preview.png"
    echo "$CACHE/preview.png"
    ;;
  --force) apply 1 ;;
  *)       apply 0 ;;
esac
