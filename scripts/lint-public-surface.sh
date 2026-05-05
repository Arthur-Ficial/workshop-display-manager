#!/bin/bash
# lint-public-surface.sh
#
# Soft lint per CLAUDE.md "SUPER MODULAR" §"Public surface is minimal":
# warn about `public` symbols in WDMCore / WDMSystem / WDMKit that
# aren't referenced from any other module. New `public` declarations
# should default to `internal`; only mark `public` when another
# module actually consumes it.
#
# Discovery is heuristic — `public func/let/var/struct/class/enum/protocol Name`
# patterns + grep across other modules. False positives are inevitable
# (KVO names, generic constraints, etc.) — hence the SOFT default. Use
# WDM_LINT_PUBLIC_SURFACE_STRICT=1 to fail the build.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WHITELIST_FILE="docs/public-surface-whitelist.md"
ALLOW=""
if [ -f "$WHITELIST_FILE" ]; then
    ALLOW=$(awk '/^[A-Za-z]/ && /:/ { print $1 }' "$WHITELIST_FILE")
fi

LIB_MODULES=("WDMCore" "WDMSystem" "WDMKit")
CONSUMER_DIRS=("Sources/WDMMac" "Sources/WDMMacRemote" "Sources/WDMCLI"
               "Sources/WDMWeb" "Sources/WDMRemoteControl"
               "Sources/wdm" "Sources/wdm-mac" "Sources/wdm-mac-control"
               "Sources/wdm-web" "Tests/")

# Print every public symbol declared in lib modules.
public_symbols() {
    for mod in "${LIB_MODULES[@]}"; do
        grep -rhnE '^[[:space:]]*public[[:space:]]+(final[[:space:]]+|nonisolated[[:space:]]+)*(func|var|let|class|struct|enum|protocol|actor|typealias)[[:space:]]+[A-Za-z_]' \
            "Sources/$mod" --include='*.swift' 2>/dev/null \
        | sed -E "s|^|Sources/$mod/|" \
        | awk -F: -v mod="$mod" '{
            # Print "Sources/<mod>/<rest>" — file path is rebuilt below
            # because grep -h dropped it; we only need module + line + sym.
            line=$0
            # Extract the symbol name: word after the kind keyword.
            n = match(line, /(func|var|let|class|struct|enum|protocol|actor|typealias)[[:space:]]+/)
            if (n) {
                rest = substr(line, n + RLENGTH)
                if (match(rest, /[A-Za-z_][A-Za-z0-9_]*/)) {
                    sym = substr(rest, RSTART, RLENGTH)
                    print mod ":" sym
                }
            }
        }'
    done | sort -u
}

violations=0
while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    sym="${entry##*:}"
    mod="${entry%%:*}"
    # Skip allowlisted.
    if echo "$ALLOW" | grep -qFx "$entry"; then
        continue
    fi
    # Skip ubiquitous Swift trait names that show up everywhere.
    case "$sym" in
        init|deinit|description|hashValue|hash|encode|decode|callAsFunction) continue;;
    esac
    # Search consumer modules. Heuristic: any occurrence of the symbol.
    found=0
    for dir in "${CONSUMER_DIRS[@]}"; do
        [ -d "$dir" ] || continue
        # Skip self-module-tests when checking unused — XYZTests for a
        # module XYZ is internal-feeling but counts as a consumer here.
        if grep -rqE "\\b${sym}\\b" "$dir" --include='*.swift' 2>/dev/null; then
            found=1; break
        fi
    done
    if [ $found -eq 0 ]; then
        if [ $violations -eq 0 ]; then
            echo "lint-public-surface: public symbols with no cross-module consumer:" >&2
        fi
        echo "  - $entry" >&2
        violations=$((violations + 1))
    fi
done < <(public_symbols)

if [ $violations -gt 0 ]; then
    echo >&2
    echo "Per CLAUDE.md SUPER MODULAR: default to internal; only mark public" >&2
    echo "when another module consumes the symbol. Either change to internal" >&2
    echo "or add the symbol to ${WHITELIST_FILE} with a justification." >&2
    if [ "${WDM_LINT_PUBLIC_SURFACE_STRICT:-}" = "1" ]; then
        exit 1
    fi
    echo "lint-public-surface: ⚠ ${violations} candidates (soft; WDM_LINT_PUBLIC_SURFACE_STRICT=1 to enforce)" >&2
    exit 0
fi

echo "lint-public-surface: ✓ every public symbol has a cross-module consumer"
