#!/usr/bin/env bash
# SUPER+S: open the security panel, or close it if it is already open.
# Placement (left edge, fixed size) comes from the window rule in
# hypr/rules.lua, matched on the `kuber-security` app-id.
set -u
pat='^foot -a kuber-security '
if pgrep -f -- "$pat" >/dev/null; then
  pkill -f -- "$pat"
else
  exec foot -a kuber-security -T 'KUBER SECURITY' -e "$(dirname "$(readlink -f "$0")")/security-panel.sh"
fi
