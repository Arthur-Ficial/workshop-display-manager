#!/usr/bin/env bash
# scripts/lib/wdm-mac.sh — DRY helpers for spawning, querying, clicking,
# and screenshotting wdm-mac during smokes and demos.
#
# Source it: `source "$(dirname "$0")/lib/wdm-mac.sh"`
# Every helper is named `wdm_*` so callers stay readable.
#
# Conventions:
#   - All helpers operate on the running `wdm-mac` process unless overridden
#     via WDM_MAC_PROC (default "wdm-mac").
#   - Screenshots downsized via `sips -Z` so they're token-cheap to read back.
#   - State file path discovered via WDM_REMOTE_STATE_FILE or default
#     `$HOME/.config/wdm/remote.json`.
#   - These helpers do NOT pkill on entry — that's the caller's choice.

WDM_MAC_PROC="${WDM_MAC_PROC:-wdm-mac}"

# Build the wdm-mac binary + bundle it as WDMMac.app.
# Returns the .app path on stdout.
wdm_build_app() {
  local cfg="${1:-debug}"
  local root
  root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
  ( cd "$root" && swift build -c "$cfg" >&2 ) || return 1
  bash "$root/scripts/bundle-wdm-mac.sh" "$cfg"
}

# Kill any running wdm-mac and wait for it to exit. Returns 0 even when
# nothing was killed — callers using `set -e` shouldn't abort here.
wdm_kill() {
  pkill -f "wdm-mac" 2>/dev/null || true
  sleep 0.4
}

# Launch the bundled .app. First arg = .app path; remaining args = wdm-mac flags.
# Waits up to 5s for the remote state file to appear when --remote is in args.
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

# Path to the remote state file (override via WDM_REMOTE_STATE_FILE).
wdm_state_file() {
  printf '%s\n' "${WDM_REMOTE_STATE_FILE:-$HOME/.config/wdm/remote.json}"
}

# Read the port the --remote API is bound to.
wdm_remote_port() {
  python3 -c "import json; print(json.load(open('$(wdm_state_file)'))['port'])"
}

# curl helper. wdm_remote_curl /ui/snapshot
wdm_remote_curl() {
  local path="$1"; shift
  local port; port=$(wdm_remote_port)
  curl -s "$@" "http://127.0.0.1:$port$path"
}

# Bring wdm-mac (or another process) to the front.
wdm_front() {
  local proc="${1:-$WDM_MAC_PROC}"
  osascript -e "tell application \"System Events\" to set frontmost of first process whose name is \"$proc\" to true" >/dev/null 2>&1
  sleep 0.3
}

# Send a keystroke (with optional modifiers) to wdm-mac. Useful for Cmd+,
# wdm_keystroke "," "command"
wdm_keystroke() {
  local key="$1"
  local mod="${2:-}"
  local using=""
  [[ -n "$mod" ]] && using=" using $mod down"
  osascript -e "tell application \"System Events\" to tell process \"$WDM_MAC_PROC\"
    set frontmost to true
    delay 0.2
    keystroke \"$key\"$using
  end tell" >/dev/null 2>&1
  sleep 0.4
}

# Get a window's geometry. Outputs "X Y W H" space-separated.
# wdm_window_geom "Settings"
wdm_window_geom() {
  local name="$1"
  local pos siz
  pos=$(osascript -e "tell application \"System Events\" to tell process \"$WDM_MAC_PROC\" to get position of (first window whose name is \"$name\")" 2>&1)
  siz=$(osascript -e "tell application \"System Events\" to tell process \"$WDM_MAC_PROC\" to get size of (first window whose name is \"$name\")" 2>&1)
  echo "$pos $siz" | tr ',' ' '
}

# Bring a specific window to the very front (not just the process).
# wdm_raise "Settings"
wdm_raise() {
  local name="$1"
  osascript -e "tell application \"System Events\" to tell process \"$WDM_MAC_PROC\"
    set frontmost to true
    perform action \"AXRaise\" of (first window whose name is \"$name\")
  end tell" >/dev/null 2>&1
  sleep 0.3
}

# Capture a window region to a file. Raises the window first so we don't
# accidentally screenshot whatever's covering it.
# wdm_screenshot "Settings" /tmp/foo.png 700
# Third arg = max-dim for sips downscaling (default 900). Pass 0 to skip.
wdm_screenshot() {
  local name="$1" out="$2" max="${3:-900}"
  wdm_raise "$name"
  read -r X Y W H <<< "$(wdm_window_geom "$name")"
  screencapture -R "${X},${Y},${W},${H}" -x "$out"
  if [[ "$max" != "0" ]]; then
    local downsized="${out%.png}-small.png"
    sips -Z "$max" "$out" --out "$downsized" >/dev/null 2>&1
    printf '%s\n' "$downsized"
  else
    printf '%s\n' "$out"
  fi
}

# Click a deep AX path. The path is the AppleScript locator inside the
# `tell process "<proc>"` block (sans the outer wrapping).
# wdm_ax_click 'tell window "Settings" to tell group 1 to tell radio group 1 to click radio button 3'
wdm_ax_click() {
  local locator="$1"
  osascript -e "tell application \"System Events\" to tell process \"$WDM_MAC_PROC\"
    $locator
  end tell" >/dev/null 2>&1
  sleep 0.4
}

# Click a window's red close button. Verifies it actually closes by
# confirming the window name no longer exists.
# wdm_close_window "Settings"
wdm_close_window() {
  local name="$1"
  osascript -e "tell application \"System Events\" to tell process \"$WDM_MAC_PROC\"
    click button 1 of window \"$name\"
  end tell" >/dev/null 2>&1
  sleep 0.4
  local still
  still=$(osascript -e "tell application \"System Events\" to tell process \"$WDM_MAC_PROC\" to (count of (every window whose name is \"$name\"))" 2>/dev/null || echo 0)
  if [[ "$still" != "0" ]]; then
    echo "wdm_close_window: window '$name' is still open after close click" >&2
    return 1
  fi
  return 0
}

# Dump the full AX entire-contents of a window. Useful when designing a click.
wdm_ax_dump() {
  local name="$1"
  osascript -e "tell application \"System Events\" to tell process \"$WDM_MAC_PROC\" to tell window \"$name\" to get entire contents" 2>&1 \
    | tr ',' '\n'
}
