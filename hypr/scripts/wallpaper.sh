#!/usr/bin/env bash
# Kuber — wallpaper generator + applier.
# Black field + faint red grid + corner data-brackets + a corp title block,
# bottom-right. Flat and digital, not paper-grained (that's Skemos's look).
# One image per resolution, cached. Portable: reads the real monitor list
# from hyprctl.
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

GRID=56            # target grid pitch (px)
GRID_ALPHA=0.05    # grid opacity — faint
FONT="$(fc-match -f '%{file}' 'JetBrains Mono' 2>/dev/null || true)"

gen() { # gen W H OUTFILE
  local w=$1 h=$2 out=$3
  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp:-}"' RETURN

  # 1. faint grid — square cells, lines knocked back to GRID_ALPHA.
  local gridcmds
  gridcmds="$(awk -v w="$w" -v h="$h" -v p0="$GRID" 'BEGIN {
      cols = int(w / p0 + 0.5); if (cols < 2) cols = 2
      p = w / cols
      for (x = 0; x < w - 0.1; x += p) printf "line %.1f,0 %.1f,%d ", x, x, h
      for (y = 0; y < h - 0.1; y += p) printf "line 0,%.1f %d,%.1f ", y, w, y
  }')"
  magick -size "${w}x${h}" xc:none -stroke "$INK" -strokewidth 1 -fill none \
    -draw "$gridcmds" "$tmp/gridfull.png"
  magick "$tmp/gridfull.png" \
    -channel A -evaluate multiply "$GRID_ALPHA" +channel \
    "$tmp/grid.png"

  # 2. base + grid. (No paper grain — flat digital black, not laid paper.)
  magick -size "${w}x${h}" xc:"$BG" \
    "$tmp/grid.png" -compose Over -composite \
    "$tmp/flat.png"

  # 3. corner data-brackets: an L-shaped bracket per corner (ink), with a
  #    short red tick off the top-left one — the one brand touch.
  local inset=36 len=72 topshift=0
  local brackets=""
  for corner in "0 0 1 1" "$((w-1)) 0 -1 1" "0 $((h-1)) 1 -1" "$((w-1)) $((h-1)) -1 -1"; do
    read -r cx cy sx sy <<<"$corner"
    local ax=$(( cx + sx*inset )) ay=$(( cy + sy*inset + topshift ))
    brackets+=" line ${ax},${ay} $(( ax + sx*len )),${ay}"
    brackets+=" line ${ax},${ay} ${ax},$(( ay + sy*len ))"
  done

  # 4. title block, bottom-right: a small filled red tab + "KUBER" + a
  #    coordinate-looking tag. Corp-plate, not a drafting title block.
  local bw=220 bh=56
  local bx=$(( w - 28 - bw ))
  local by=$(( h - 28 - bh ))
  local tb="rectangle ${bx},${by} $((bx+bw)),$((by+bh))"
  tb+=" line ${bx},$((by+bh)) $((bx+28)),${by}"   # one angled cut corner, top-left of the plate

  local tag; tag="$(date +%Y.%m.%d)"

  magick "$tmp/flat.png" \
    -stroke "$INK" -strokewidth 1 -fill none -draw "$brackets" \
    -stroke none -fill "$ACCENT" -draw "rectangle $((bx-10)),${by} $((bx-4)),$((by+bh))" \
    -stroke "$INK_FAINT" -strokewidth 1 -fill "$BG" -draw "$tb" \
    ${FONT:+-font "$FONT"} -stroke none -fill "$INK" -pointsize 15 \
      -draw "text $((bx+14)),$((by+22)) 'KUBER'" \
    -fill "$INK_DIM" -pointsize 10 \
      -draw "text $((bx+14)),$((by+40)) \"CORP-01 · $tag\"" \
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
