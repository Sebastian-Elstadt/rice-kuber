#!/usr/bin/env bash
# Kuber — Waybar security-status pill. Glanceable worst-of-5 read from the
# shared security backend's summaries (same /var/log/skemos-security that
# Skemos's panel reads — see README.md "Security"). Read-only: this script
# never calls sudo or triggers a scan, it only reads group-readable JSON.
# Click opens the full panel (security-toggle.sh), same as SUPER+S.

set -uo pipefail
LOG_DIR="/var/log/skemos-security"
JOBS=(integrity rkhunter arch-audit ufw-status audit-status)

worst="unknown"
detail=()
for job in "${JOBS[@]}"; do
  f="$LOG_DIR/$job.summary.json"
  [[ -r $f ]] || continue
  s=$(jq -r '.status // "unknown"' "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]')
  detail+=("$job: ${s:-unknown}")
  case "$s" in
    fail) worst=fail ;;
    warn) [[ $worst != fail ]] && worst=warn ;;
    ok)   [[ $worst == unknown ]] && worst=ok ;;
  esac
done

case "$worst" in
  fail) label="SEC FAIL" ;;
  warn) label="SEC WARN" ;;
  ok)   label="SEC OK" ;;
  *)    label="SEC —" ;;
esac

tooltip=$(printf '%s\n' "${detail[@]:-no data yet}" | sed 's/"/\\"/g' | paste -sd '\n' -)
printf '{"text":"%s","class":"%s","tooltip":"%s · click to open panel (SUPER+S)"}\n' \
  "$label" "$worst" "${tooltip//$'\n'/\\n}"
