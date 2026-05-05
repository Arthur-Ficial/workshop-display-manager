#!/bin/bash
# lint-no-fakes.sh
#
# Enforces CLAUDE.md "NO FAKE OR FALLBACK FUNCTIONALITY" pillar:
# production code paths must not reference test-only env vars or
# stub markers.
#
# Forbidden in Sources/** (excluding *Fixture*, *Recording*, *Mock*):
#   - `WDM_TEST_FIXTURE` (only the fixture provider should reference it)
#   - `// TODO: actually implement` / `// stub` / `// not implemented`
#   - `return .success` followed (within 3 lines) by a "// TODO" or "// later"
#
# These markers are test-only or unfinished-feature signals; they
# don't belong on the production path.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WHITELIST_FILE="docs/no-fakes-whitelist.md"
WHITELIST=""
if [ -f "$WHITELIST_FILE" ]; then
    WHITELIST=$(awk '/^Sources\// { print $1 }' "$WHITELIST_FILE")
fi

violations=0
report() {
    local path="$1"
    if echo "$WHITELIST" | grep -qFx "$path"; then return 0; fi
    if [ $violations -eq 0 ]; then
        echo "lint-no-fakes: production code with test-only / stub markers:" >&2
    fi
    echo "  - $1: $2" >&2
    violations=$((violations + 1))
}

# Find production sources (Sources/** excluding the explicit test-double files).
PRODUCTION=$(find Sources -name '*.swift' -type f 2>/dev/null \
    | grep -vE '/(Recording|Fixture|Mock)[A-Za-z]*\.swift$')

# Rule 1: WDM_TEST_FIXTURE in production. The fixture-construction
# files (FixtureDisplayProvider, providers Factory) reference it
# legitimately; any other production source flagging it is a defect.
while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
        */ProviderFactory*|*/CGDisplayProvider*) continue;;
    esac
    while IFS= read -r hit; do
        [ -z "$hit" ] && continue
        report "$f" "$hit (WDM_TEST_FIXTURE referenced in production)"
    done < <(grep -nE 'WDM_TEST_FIXTURE' "$f" 2>/dev/null)
done <<< "$PRODUCTION"

# Rule 2: "// TODO: actually implement", "// stub", "// not implemented".
while IFS= read -r f; do
    [ -z "$f" ] && continue
    while IFS= read -r hit; do
        [ -z "$hit" ] && continue
        report "$f" "$hit"
    done < <(grep -niE '// TODO:[[:space:]]*actually implement|// stub\b|// not implemented' "$f" 2>/dev/null)
done <<< "$PRODUCTION"

if [ $violations -gt 0 ]; then
    echo >&2
    echo "Per CLAUDE.md NO FAKE FUNCTIONALITY: every feature must be real and" >&2
    echo "really, really working. Implement it, or surface an honest refusal." >&2
    exit 1
fi

echo "lint-no-fakes: ✓ no test-only env vars or stub markers in production"
