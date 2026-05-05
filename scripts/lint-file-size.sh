#!/bin/bash
# lint-file-size.sh
#
# Enforces CLAUDE.md "SUPER MODULAR" pillar: every Swift file under
# Sources/ MUST be ≤ 150 lines. Long files are textbook signs of
# multiple responsibilities — split them.
#
# Tests under Tests/ are exempt (test files commonly batch many
# small @Test cases under one Suite, and that's fine; the cost of
# splitting them is more than the legibility win).
#
# Allowlist: docs/file-size-whitelist.md — files with a documented
# justification (typically generated code or large fixture
# constants). Format: one filename per line, comments after `#`.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LIMIT=150

WHITELIST=""
if [ -f docs/file-size-whitelist.md ]; then
    # Match lines starting with "Sources/" and containing ".swift" (this
    # is the only path shape that can appear in the whitelist; the awk
    # regex avoids tricky escapes for `/` inside character classes).
    WHITELIST=$(awk '/^Sources\// && /\.swift/ { print $1 }' docs/file-size-whitelist.md)
fi

violations=0
while IFS= read -r f; do
    [ -z "$f" ] && continue
    lines=$(wc -l < "$f" | awk '{print $1}')
    if [ "$lines" -le "$LIMIT" ]; then
        continue
    fi
    relpath=${f#./}
    # Skip whitelisted files.
    if echo "$WHITELIST" | grep -qFx "$relpath"; then
        continue
    fi
    if [ $violations -eq 0 ]; then
        echo "lint-file-size: files exceeding ${LIMIT} lines:" >&2
    fi
    printf "  - %s (%d lines)\n" "$relpath" "$lines" >&2
    violations=$((violations + 1))
done < <(find Sources -name '*.swift' -type f 2>/dev/null)

if [ $violations -gt 0 ]; then
    echo >&2
    echo "Per CLAUDE.md \"SUPER MODULAR\": files >150 lines are doing too much." >&2
    echo "Split into one-public-type-per-file. If a file is generated or otherwise" >&2
    echo "must exceed the limit, add it to docs/file-size-whitelist.md with a" >&2
    echo "one-line justification." >&2
    exit 1
fi

echo "lint-file-size: ✓ all Sources/ files ≤ ${LIMIT} lines"
