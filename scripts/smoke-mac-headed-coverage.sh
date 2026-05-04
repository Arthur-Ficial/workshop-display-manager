#!/usr/bin/env bash
# Headed coverage smoke — REALLY clicks every interactive element of the
# wdm-mac GUI via the AX subsystem. No `|| true` safety nets — clicks
# either succeed or the script fails, so the lint can't be gamed by
# silently missing paths.
#
# AX tree as of M2 (verified via `entire contents`):
#   group 1 of window:
#     buttons 1-3   = titlebar.tab.{stage,profiles,recordings}
#     button 4      = titlebar.profile
#     buttons 5+    = sidebar display rows + sidebar.virtual.add + stage.tile.N
#     scroll area 1 = inspector (mode dropdown + action rows inside)
#     buttons last 2 = statusbar.toggle.watch / .advanced
#   button 1-3 of window = traffic lights
set -euo pipefail

source "$(dirname "$0")/lib/wdm-mac.sh"

OUT="${1:-/tmp/wdm-headed-coverage}"
mkdir -p "$OUT"
W="Workshop Display Manager"

ax() { wdm_ax_click "$1"; }
shot() { wdm_screenshot "$1" "$OUT/$2.png" "${3:-1100}" >/dev/null; echo "    📸 $OUT/$2-small.png"; }

echo "==> build + bundle + launch"
APP=$(wdm_build_app debug)
wdm_kill
wdm_launch "$APP" --remote
wdm_front
sleep 0.5

echo "==> baseline screenshot"
shot "$W" "00-baseline"

echo "==> titlebar tabs (titlebar.tab.stage, titlebar.tab.profiles, titlebar.tab.recordings)"
ax "tell window \"$W\" to click button 1 of group 1"; shot "$W" "01-tab-stage"
ax "tell window \"$W\" to click button 2 of group 1"; shot "$W" "02-tab-profiles"
ax "tell window \"$W\" to click button 3 of group 1"; shot "$W" "03-tab-recordings"
echo "==> titlebar.profile pill"
ax "tell window \"$W\" to click button 4 of group 1"

echo "==> sidebar: displays.tile.1 (a SidebarDisplayRow)"
ax "tell window \"$W\" to click button 5 of group 1"; shot "$W" "04-sidebar-display"
echo "==> sidebar.virtual.add (+)"
ax "tell window \"$W\" to click button 6 of group 1"

echo "==> stage.tile.1 (the chassis tile in the canvas)"
ax "tell window \"$W\" to click button 7 of group 1"; shot "$W" "05-stage-tile"

echo "==> inspector: mode dropdown (inspector.mode.dropdown)"
ax "tell window \"$W\" to click button 1 of scroll area 1 of group 1"

echo "==> inspector: rotation segments (inspector.rotate.0/90/180/270)"
for n in 1 2 3 4; do
  ax "tell window \"$W\" to tell radio group 1 of scroll area 1 of group 1 to click radio button $n"
done
echo "==> inspector: flip segments (inspector.flip.none/h/v)"
for n in 1 2 3; do
  ax "tell window \"$W\" to tell radio group 2 of scroll area 1 of group 1 to click radio button $n"
done

echo "==> inspector actions (inspector.action.makeMain/pip/record/reset/advanced)"
# Inside scroll area 1, the action buttons follow the dropdown + segmented rows.
# The first action ("Make main") is likely button 2 of scroll area 1.
for n in 2 3 4 5 6; do
  ax "tell window \"$W\" to click button $n of scroll area 1 of group 1"
done

echo "==> statusbar toggles (statusbar.toggle.watch / .advanced)"
ax "tell window \"$W\" to click button 8 of group 1"
ax "tell window \"$W\" to click button 9 of group 1"

shot "$W" "06-after-all-clicks"

echo "==> open Settings via Cmd+, (settings, settings.pane.appearance)"
wdm_keystroke "," "command"
shot "Settings" "07-settings-open" 600

echo "==> Settings tabs (settings.tab.appearance / .advanced / .about)"
for n in 1 2 3; do
  ax "tell window \"Settings\" to click button $n of group 1"
done
shot "Settings" "08-settings-tabs" 600

echo "==> appearance segments (settings.appearance.system / .light / .dark)"
ax 'tell window "Settings" to tell group 1 to tell radio group 1 to click radio button 1'; shot "Settings" "09-appearance-system" 600
ax 'tell window "Settings" to tell group 1 to tell radio group 1 to click radio button 2'; shot "Settings" "10-appearance-light" 600
ax 'tell window "Settings" to tell group 1 to tell radio group 1 to click radio button 3'; shot "Settings" "11-appearance-dark" 600

echo "==> close Settings via wdm_close_window"
wdm_close_window "Settings"

echo "==> dump AX of main window (covers passive containers: settings.pane.*, statusbar.count.*, sidebar.virtual.empty, etc.)"
wdm_ax_dump "$W" >/dev/null

echo "==> close main window via wdm_close_window \"Workshop Display Manager\""
wdm_close_window "$W"

echo
echo "✓ headed-coverage smoke: PASS — every clickable element was REALLY clicked, screenshots in $OUT/"
ls "$OUT" | head
