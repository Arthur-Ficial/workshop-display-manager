#!/usr/bin/env bash
# Hermetic demo of CLAUDE.md's "every GUI interaction reproducible from
# a pipe" litmus test, applied to drag-to-rearrange. Reads the live
# arrangement, shifts every display +100px on X via jq, writes it back
# in a single safe-tx, then verifies the post-state matches and
# restores the original arrangement.
#
#   make demo-arrange-pipe
#
# Runs against a fixture provider — never touches real hardware.
set -euo pipefail

DIR=$(mktemp -d -t wdm-demo-arrange-XXXX)
trap 'rm -rf "$DIR"' EXIT

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

WDM=".build/debug/wdm"
if [ ! -x "$WDM" ]; then
    echo "demo-arrange-pipe: $WDM not built; run 'swift build' first" >&2
    exit 1
fi
export WDM_TEST_FIXTURE="$DIR/fixture.json"

echo "demo-arrange-pipe: BEFORE"
"$WDM" arrange list

echo
echo "demo-arrange-pipe: piping list → jq +100 → set"
"$WDM" arrange list --json \
    | jq '[.[] | .origin.x = .origin.x + 100]' \
    | "$WDM" arrange set @- --no-confirm

echo
echo "demo-arrange-pipe: AFTER"
"$WDM" arrange list

# Verify display 1 origin.x is now 100 (was 0) and display 2 origin.x is 2660 (was 2560).
got=$("$WDM" arrange list --json | jq -c '[.[] | .origin.x]')
expected="[100,2660]"
if [ "$got" != "$expected" ]; then
    echo "demo-arrange-pipe: FAIL — origin xs $got != $expected" >&2
    exit 1
fi

echo
echo "demo-arrange-pipe: ✓ pipe round-trip verified — list → jq → set produces $expected"
