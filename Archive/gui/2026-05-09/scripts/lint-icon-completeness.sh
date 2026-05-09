#!/usr/bin/env bash
# lint-icon-completeness.sh
#
# Asserts every Apple icon slot is present in the appiconset and is
# the right pixel dimensions. Catches "I deleted icon_32x32@2x.png
# while refactoring" regressions.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT/Sources/WDMMac/Resources/Assets.xcassets/AppIcon.appiconset"

if [ ! -d "$ICONSET" ]; then
    echo "lint-icon-completeness: $ICONSET missing — run scripts/generate-icon.sh" >&2
    exit 1
fi

# (size, scale) -> expected pixels
declare -a SLOTS=(
    "16  1"
    "16  2"
    "32  1"
    "32  2"
    "64  1"
    "64  2"
    "128 1"
    "128 2"
    "256 1"
    "256 2"
    "512 1"
    "512 2"
    "1024 1"
)

violations=0
for slot in "${SLOTS[@]}"; do
    base=$(echo "$slot" | awk '{print $1}')
    sf=$(echo "$slot"   | awk '{print $2}')
    file="$ICONSET/icon_${base}x${base}@${sf}x.png"
    if [ ! -e "$file" ]; then
        if [ $violations -eq 0 ]; then
            echo "lint-icon-completeness: missing or wrong-sized icon slots:" >&2
        fi
        echo "  - missing: $(basename "$file")" >&2
        violations=$((violations + 1))
        continue
    fi
    # Verify dimensions via sips. Expected = base * sf.
    expected=$((base * sf))
    actual_w=$(sips -g pixelWidth "$file" 2>/dev/null | awk '/pixelWidth/ {print $2}')
    actual_h=$(sips -g pixelHeight "$file" 2>/dev/null | awk '/pixelHeight/ {print $2}')
    if [ "$actual_w" != "$expected" ] || [ "$actual_h" != "$expected" ]; then
        if [ $violations -eq 0 ]; then
            echo "lint-icon-completeness: missing or wrong-sized icon slots:" >&2
        fi
        echo "  - wrong dims: $(basename "$file") is ${actual_w}x${actual_h}, expected ${expected}x${expected}" >&2
        violations=$((violations + 1))
    fi
done

# Contents.json must exist.
if [ ! -e "$ICONSET/Contents.json" ]; then
    echo "  - missing: Contents.json" >&2
    violations=$((violations + 1))
fi

if [ $violations -gt 0 ]; then
    echo >&2
    echo "Re-run scripts/generate-icon.sh to regenerate the missing slots." >&2
    exit 1
fi

echo "lint-icon-completeness: ✓ all 13 icon slots present at the right dimensions"
