#!/usr/bin/env bash
# Hermetic e2e smoke for wdm-mac --remote --headless via wdm-mac-control.
# Drives the same flow an AI agent would. Now built on scripts/lib/wdm-mac.sh.
set -euo pipefail

source "$(dirname "$0")/lib/wdm-mac.sh"

DIR=$(mktemp -d -t wdm-mac-smoke-XXXX)
trap 'rm -rf "$DIR"; wdm_kill' EXIT

cat > "$DIR/fixture.json" <<'EOF'
{
  "snapshot": {
    "createdAt": 1700000000,
    "displays": [
      {"id": 1, "name": "Built-in", "isMain": true, "isOnline": true, "mirrorSource": null,
       "currentMode": {"width": 2560, "height": 1664, "refreshHz": 60},
       "origin": {"x": 0, "y": 0}, "rotationDegrees": 0},
      {"id": 2, "name": "Projector", "isMain": false, "isOnline": true, "mirrorSource": null,
       "currentMode": {"width": 1920, "height": 1080, "refreshHz": 60},
       "origin": {"x": 2560, "y": 0}, "rotationDegrees": 0}
    ]
  },
  "availableModes": {
    "1": [{"width": 2560, "height": 1664, "refreshHz": 60}],
    "2": [{"width": 1920, "height": 1080, "refreshHz": 60}]
  }
}
EOF

export HOME="$DIR"
export WDM_TEST_FIXTURE="$DIR/fixture.json"
export WDM_REMOTE_STATE_FILE="$DIR/remote.json"
BIN=.build/debug

echo "==> launching wdm-mac --remote --headless"
"$BIN/wdm-mac" --remote --headless --state-file "$DIR/remote.json" 2>"$DIR/server.log" &
sleep 0.5
echo "    server: $(cat "$DIR/server.log")"
echo

echo "==> snapshot — what the AI sees:"
"$BIN/wdm-mac-control" snapshot
echo

echo "==> click @e2 (the Projector tile):"
"$BIN/wdm-mac-control" click @e2
echo

echo "==> snapshot after click (selected ✓ moves to @e2):"
"$BIN/wdm-mac-control" snapshot
echo

echo "==> unix-pipe demo: select 'Projector' by label, no @ref hardcoded:"
ref=$("$BIN/wdm-mac-control" snapshot --json \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print([n["ref"] for n in d["nodes"] if n["label"]=="Projector"][0])')
"$BIN/wdm-mac-control" click "$ref"

echo
echo "✓ smoke-mac-remote: PASS"
