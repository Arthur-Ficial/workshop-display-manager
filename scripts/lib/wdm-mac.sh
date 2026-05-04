#!/usr/bin/env bash
# scripts/lib/wdm-mac.sh — minimal helpers for spawning wdm-mac and
# talking to its remote API. ZERO osascript / AppleScript — every GUI
# interaction goes through wdm-mac-control / the /ui/* endpoints.
#
# Source it: `source "$(dirname "$0")/lib/wdm-mac.sh"`
#
# Removed (deliberately): wdm_ax_click, wdm_keystroke, wdm_window_geom,
# wdm_screenshot, wdm_close_window, wdm_ax_dump, wdm_front, wdm_raise.
# Anything that needed those should now use a wdm-mac-control verb. If a
# verb is missing, add it to wdm-mac-control + the remote API — don't
# resurrect the AppleScript bridge.

# Build the wdm-mac binary + bundle it as WDMMac.app. Returns the .app path.
wdm_build_app() {
  local cfg="${1:-debug}"
  local root
  root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
  ( cd "$root" && swift build -c "$cfg" >&2 ) || return 1
  bash "$root/scripts/bundle-wdm-mac.sh" "$cfg"
}

# Kill any running wdm-mac and wait for it to exit. Always 0.
wdm_kill() {
  pkill -f "wdm-mac" 2>/dev/null || true
  sleep 0.4
}

# Launch the bundled .app. First arg = .app path; remaining = wdm-mac flags.
# Waits up to 5s for the remote state file when --remote is in args.
wdm_launch() {
  local app="$1"; shift
  open -a "$app" --args "$@"
  if [[ " $* " == *" --remote "* ]]; then
    local state; state=$(wdm_state_file)
    local deadline=$(( $(date +%s) + 5 ))
    while [[ ! -f "$state" ]] && (( $(date +%s) < deadline )); do sleep 0.1; done
  else
    sleep 1.5
  fi
}

wdm_state_file() {
  printf '%s\n' "${WDM_REMOTE_STATE_FILE:-$HOME/.config/wdm/remote.json}"
}

wdm_remote_port() {
  python3 -c "import json; print(json.load(open('$(wdm_state_file)'))['port'])"
}

# wdm_remote_curl /ui/snapshot
wdm_remote_curl() {
  local path="$1"; shift
  local port; port=$(wdm_remote_port)
  curl -s "$@" "http://127.0.0.1:$port$path"
}
