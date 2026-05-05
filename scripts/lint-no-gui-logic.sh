#!/bin/bash
# lint-no-gui-logic.sh
#
# Enforces CLAUDE.md's "Render-layer rule (DRY)": GUI modules
# (Sources/WDMMac, Sources/WDMMacRemote) MUST NOT contain business logic.
# All logic lives in the lib (WDMCore / WDMSystem / WDMKit) so every
# frontend — CLI, GUI, web, future MCP — uses the same code paths.
#
# Specifically: no `extension <LibType> { ... }` declarations in GUI
# modules. Adding methods/properties to a lib type from the GUI is a
# textbook DRY break — the next frontend reimplements the same logic.
# Put the extension in `Sources/WDMCore` (pure) or `Sources/WDMKit`
# (effectful) instead.
#
# Discovery: scan WDMCore / WDMSystem / WDMKit for every public type
# declaration; forbid `extension <Name>` for any of those names in
# GUI sources.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB_DIRS=("$ROOT/Sources/WDMCore" "$ROOT/Sources/WDMSystem" "$ROOT/Sources/WDMKit")
GUI_DIRS=("$ROOT/Sources/WDMMac" "$ROOT/Sources/WDMMacRemote")

# Collect every public type declared in the lib.
LIB_TYPES=$(grep -rhE '^[[:space:]]*public[[:space:]]+(final[[:space:]]+)?(enum|struct|class|actor|protocol)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
  "${LIB_DIRS[@]}" --include='*.swift' 2>/dev/null \
  | sed -E 's/.*(enum|struct|class|actor|protocol)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\2/' \
  | sort -u)

if [ -z "$LIB_TYPES" ]; then
  echo "lint-no-gui-logic: could not discover any lib types (sanity check failed)" >&2
  exit 2
fi

violations=0
while IFS= read -r t; do
  [ -z "$t" ] && continue
  # Match `extension <Type>` followed by space, brace, colon, or end-of-word.
  hits=$(grep -rlE "^[[:space:]]*extension[[:space:]]+${t}([[:space:]:{]|\$)" \
    "${GUI_DIRS[@]}" --include='*.swift' 2>/dev/null || true)
  if [ -n "$hits" ]; then
    if [ $violations -eq 0 ]; then
      echo "lint-no-gui-logic: business-logic extensions on lib types found in GUI module:" >&2
    fi
    while IFS= read -r f; do
      echo "  - extension $t in $f" >&2
    done <<< "$hits"
    violations=$((violations + 1))
  fi
done <<< "$LIB_TYPES"

if [ $violations -gt 0 ]; then
  echo >&2
  echo "GUI sources may not extend lib types. Move the extension to" >&2
  echo "Sources/WDMCore (pure) or Sources/WDMKit (effectful) so the CLI," >&2
  echo "web, and future frontends share the same logic." >&2
  exit 1
fi

echo "lint-no-gui-logic: ✓ no business-logic extensions in GUI modules"
