#!/usr/bin/env bash
# Visible demo: launch wdm-mac (headed), open Settings, flip the
# appearance picker through System → Light → Dark, screenshotting after
# each step. Uses scripts/lib/wdm-mac.sh — no AppleScript boilerplate
# in this file.
#
# Usage: bash scripts/demo-settings-flip.sh [output-dir]
# Output: $OUT/demo-{system,light,dark}-small.png and a status log.
set -euo pipefail

source "$(dirname "$0")/lib/wdm-mac.sh"

OUT="${1:-/tmp/wdm-demo}"
mkdir -p "$OUT"

echo "==> build + bundle"
APP=$(wdm_build_app debug)
echo "    app: $APP"

echo "==> kill any old wdm-mac, launch fresh with --remote"
wdm_kill
HOME="${HOME:-$OUT}" wdm_launch "$APP" --remote
wdm_front

echo "==> open Settings via Cmd+,"
wdm_keystroke "," "command"

# Three radio buttons in the appearance picker, in order:
declare -a steps=(
  "1 system"
  "2 light"
  "3 dark"
)
for step in "${steps[@]}"; do
  read -r idx label <<< "$step"
  echo "==> click radio button $idx ($label)"
  wdm_ax_click "tell window \"Settings\" to tell group 1 to tell radio group 1 to click radio button $idx"
  out="$OUT/demo-${label}.png"
  small=$(wdm_screenshot "Settings" "$out" 600)
  echo "    screenshot: $small"
done

echo
echo "==> close the Settings window via its red close button"
wdm_close_window "Settings"
echo "    Settings closed cleanly."

echo
echo "✓ demo complete. Open the three PNGs in $OUT/ to see the flip."
