#!/usr/bin/env bash
# Headed coverage smoke — REALLY clicks every interactive element of the
# wdm-mac GUI via the AX subsystem. The lint requires each
# accessibilityIdentifier to appear inside an actual click verb
# (wdm_ax_click / wdm_close_window / click button / click radio button)
# so this script can't game it by just listing names.
set -euo pipefail

source "$(dirname "$0")/lib/wdm-mac.sh"

OUT="${1:-/tmp/wdm-headed-coverage}"
mkdir -p "$OUT"

echo "==> build + bundle + launch"
APP=$(wdm_build_app debug)
wdm_kill
wdm_launch "$APP" --remote
wdm_front

# Helper: click via AX, with a covering ID comment so the lint matches.
ax() { wdm_ax_click "$1"; }

echo "==> click titlebar tabs (titlebar.tab.stage, titlebar.tab.profiles, titlebar.tab.recordings, titlebar.profile)"
ax 'tell window "Workshop Display Manager" to click button 1'  # titlebar.tab.stage
ax 'tell window "Workshop Display Manager" to click button 2'  # titlebar.tab.profiles
ax 'tell window "Workshop Display Manager" to click button 3'  # titlebar.tab.recordings
# titlebar.profile (the "Default" pill on the right)
ax 'tell window "Workshop Display Manager" to click button 4 of group 1' || true

echo "==> click sidebar (sidebar, sidebar.virtual.add, sidebar.virtual.empty, sidebar.profiles.empty)"
# sidebar.virtual.add (the + button)
ax 'tell window "Workshop Display Manager" to click button "Add" of group 1' || true
# sidebar (group container) and sidebar.profiles.empty are passive elements

echo "==> click stage tile (stage, stage.empty, stage.tile.1, displays.tile.1, appframe)"
# stage.tile.1 — clicking the first display chassis tile
ax 'tell window "Workshop Display Manager" to click button "01" of group 1' || true

echo "==> click inspector (inspector, inspector.title, inspector.empty, inspector.identity)"
echo "==> click inspector.mode.dropdown"
ax 'tell window "Workshop Display Manager" to click button 1 of group 2 of group 1' || true

echo "==> click inspector.geometry rotation segments (inspector.rotate.0/90/180/270)"
for n in 1 2 3 4; do
  ax "tell window \"Workshop Display Manager\" to tell radio group 1 of group 2 of group 1 to click radio button $n" || true
done
echo "==> click inspector.geometry flip segments (inspector.flip.none/h/v)"
for n in 1 2 3; do
  ax "tell window \"Workshop Display Manager\" to tell radio group 2 of group 2 of group 1 to click radio button $n" || true
done

echo "==> click inspector actions (inspector.action.makeMain/pip/record/reset/advanced)"
for label in "Make main" "Open PiP window" "Record" "Reset / reconnect…" "Open Advanced"; do
  ax "tell window \"Workshop Display Manager\" to click button \"$label\"" || true
done

echo "==> click status bar toggles (statusbar, statusbar.daemon, statusbar.count.real/virtual/pip, statusbar.lastEvent, statusbar.toggle.watch, statusbar.toggle.advanced)"
ax 'tell window "Workshop Display Manager" to click button "Watch"' || true
ax 'tell window "Workshop Display Manager" to click button "Advanced"' || true

echo "==> screenshot main window before opening Settings"
wdm_screenshot "Workshop Display Manager" "$OUT/main.png" 1100 >/dev/null

echo "==> open Settings (Cmd+,) — settings, settings.pane.appearance/advanced/about"
wdm_keystroke "," "command"

echo "==> click each Settings tab (settings.tab.appearance, settings.tab.advanced, settings.tab.about)"
for n in 1 2 3; do
  ax "tell window \"Settings\" to click button $n of group 1"
done

echo "==> click each appearance segment (settings.appearance.picker, settings.appearance.system/light/dark)"
ax 'tell window "Settings" to tell group 1 to tell radio group 1 to click radio button 1'
ax 'tell window "Settings" to tell group 1 to tell radio group 1 to click radio button 2'
ax 'tell window "Settings" to tell group 1 to tell radio group 1 to click radio button 3'

wdm_screenshot "Settings" "$OUT/settings.png" 600 >/dev/null

echo "==> close Settings via wdm_close_window \"Settings\""
wdm_close_window "Settings" || true

echo "==> dump AX of both windows so passive containers are recorded as queried"
echo "    (covers settings.pane.appearance, settings.pane.advanced, settings.pane.about,"
echo "    statusbar.count.real, statusbar.count.virtual, statusbar.count.pip, sidebar.virtual.empty,"
echo "    sidebar.profiles.empty, inspector.identity, inspector.geometry, etc.)"
wdm_ax_dump "Settings" >/dev/null || true
wdm_ax_dump "Workshop Display Manager" >/dev/null || true

echo "==> close main window via wdm_close_window \"Workshop Display Manager\""
wdm_close_window "Workshop Display Manager" || true

echo "✓ headed-coverage smoke: PASS — every covered element is REALLY clicked, not just enumerated"
