#!/bin/bash
# lint-rendering-pixel-dims.sh
#
# Enforces CLAUDE.md "CRISP-AS-DAY RENDERING" pillar. Two hard rules:
#
#   1. Any file that uses `SCStreamConfiguration` MUST also reference
#      `backingScaleFactor` (capture must be at native pixel res, not
#      logical points).
#
#   2. No file under Sources/ may set `scalesToFit = true` (forbidden
#      token — defeats explicit pixel sizing).
#
# Source files that touch SCStreamConfiguration are the canonical
# scope; the lint scans only those. Everything else is irrelevant.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WHITELIST_FILE="docs/rendering-pixel-dims-whitelist.md"
WHITELIST=""
if [ -f "$WHITELIST_FILE" ]; then
    WHITELIST=$(awk '/^Sources\// { print $1 }' "$WHITELIST_FILE")
fi

violations=0

# Rule 1: SCStreamConfiguration users must mention backingScaleFactor.
while IFS= read -r f; do
    [ -z "$f" ] && continue
    # Skip recording/fixture variants — they mock SCStream config and
    # don't need backingScaleFactor.
    case "$f" in
        */Recording*|*/Fixture*) continue;;
    esac
    if echo "$WHITELIST" | grep -qFx "$f"; then continue; fi
    if ! grep -q 'backingScaleFactor' "$f"; then
        if [ $violations -eq 0 ]; then
            echo "lint-rendering-pixel-dims: SCStream users missing backingScaleFactor:" >&2
        fi
        echo "  - $f" >&2
        violations=$((violations + 1))
    fi
done < <(grep -rl 'SCStreamConfiguration' Sources --include='*.swift' 2>/dev/null)

# Rule 2: scalesToFit = true is forbidden (defeats native-pixel intent).
while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    if [ $violations -eq 0 ]; then
        echo "lint-rendering-pixel-dims: forbidden 'scalesToFit = true':" >&2
    fi
    echo "  - $hit" >&2
    violations=$((violations + 1))
done < <(grep -rnE 'scalesToFit[[:space:]]*=[[:space:]]*true' \
    Sources --include='*.swift' 2>/dev/null)

if [ $violations -gt 0 ]; then
    echo >&2
    echo "Per CLAUDE.md CRISP-AS-DAY RENDERING: capture at native pixel res" >&2
    echo "(width × backingScaleFactor) and never set scalesToFit = true." >&2
    exit 1
fi

echo "lint-rendering-pixel-dims: ✓ all capture paths use native pixel dims"
