#!/bin/bash
# lint-naming.sh
#
# Enforces CLAUDE.md "SUPER MODULAR" naming rules:
#   1. No "and" segment in func names — `parseAndValidate` etc. → split.
#   2. No grab-bag filenames: Utilities*.swift, Helpers*.swift,
#      Extensions*.swift, Misc*.swift, Common*.swift.
#
# Allowlist: lines starting with `#` in
# docs/naming-whitelist.md exempt specific names (rare cases).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WHITELIST_FILE="docs/naming-whitelist.md"

ALLOW=""
if [ -f "$WHITELIST_FILE" ]; then
    ALLOW=$(awk '/^Sources\// { print $1 }' "$WHITELIST_FILE")
fi

violations=0

# Rule 1: no "and" segment in function names. Match `func \w+And\w+`.
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    name=$(echo "$line" | grep -oE 'func +[A-Za-z_][A-Za-z0-9_]*' | awk '{print $2}')
    [ -z "$name" ] && continue
    # `andthen` etc. only matches if there's a Capital after And.
    if echo "$name" | grep -qE '^[a-z][A-Za-z0-9]*And[A-Z]'; then
        key="$file:$name"
        if echo "$ALLOW" | grep -qFx "$key"; then continue; fi
        if [ $violations -eq 0 ]; then
            echo "lint-naming: function names with 'and' segment (split into two functions):" >&2
        fi
        echo "  - $key" >&2
        violations=$((violations + 1))
    fi
done < <(grep -rnE 'func [a-z][A-Za-z0-9]*And[A-Z]' Sources --include='*.swift' 2>/dev/null)

# Rule 2: forbid grab-bag filenames.
for pattern in 'Utilities' 'Helpers' 'Extensions' 'Misc' 'Common'; do
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        rel=${f#./}
        # Some legitimate file names contain these tokens (e.g., "WDMSystem"
        # has "System" not "Common"). The exact-match patterns above only
        # catch <Name><Token>.swift (e.g., "Utilities.swift", "Misc.swift",
        # "FoobarHelpers.swift"). We allow the keyword IF and only IF it
        # is followed by a more specific suffix — e.g., "ExtensionsTests"
        # is fine. Strict match: file basename equals exactly <Token>.swift
        # OR ends with <Token>.swift after a non-empty prefix that is a
        # type name.
        base=$(basename "$rel" .swift)
        if [ "$base" = "$pattern" ] || [ "$base" = "${pattern}" ]; then
            if echo "$ALLOW" | grep -qFx "$rel"; then continue; fi
            if [ $violations -eq 0 ]; then
                echo "lint-naming: grab-bag filenames are forbidden:" >&2
            fi
            echo "  - $rel (matches forbidden pattern '$pattern')" >&2
            violations=$((violations + 1))
        fi
    done < <(find Sources -name "${pattern}.swift" -type f 2>/dev/null)
done

if [ $violations -gt 0 ]; then
    echo >&2
    echo "Per CLAUDE.md SUPER MODULAR: \"and\" in a name = two responsibilities" >&2
    echo "in one function. Grab-bag files = misc dumping ground. Refactor or" >&2
    echo "add an exact justification line to ${WHITELIST_FILE}." >&2
    exit 1
fi

echo "lint-naming: ✓ no 'and' in func names, no grab-bag filenames"
