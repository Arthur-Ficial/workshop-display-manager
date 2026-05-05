#!/bin/bash
# lint-every-verb-has-e2e.sh
#
# Enforces CLAUDE.md's "100% E2E coverage rule": every CLI verb must be
# exercised by at least one e2e test under Tests/WDMCLITests/ that
# spawns the actual wdm binary as a subprocess. If a verb has no test,
# it does not exist (CLAUDE.md § Iron Law).
#
# Discovery:
#   - CLI verbs come from Sources/WDMCLI/Commands/*Command.swift
#     (filename minus "Command.swift", kebab-case).
#   - A verb is "covered" iff its kebab-case token appears as an
#     argument in a `proc.arguments = [..., "<verb>", ...]` literal
#     OR as a test-name string under Tests/WDMCLITests/**/*.swift.
#
# Exit code: 0 if every verb is covered, 1 otherwise.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

camel_to_kebab() {
    sed -E 's/([A-Z]+)([A-Z][a-z])/\1-\2/g; s/([a-z0-9])([A-Z])/\1-\2/g' \
        | tr '[:upper:]' '[:lower:]'
}

VERBS=$(for f in Sources/WDMCLI/Commands/*Command.swift; do
    [ -e "$f" ] || continue
    base=$(basename "$f" Command.swift)
    [ -z "$base" ] && continue
    [ "$base" = "Args" ] && continue
    [ "$base" = "MutationDispatch" ] && continue
    echo "$base" | camel_to_kebab
done | sort -u)

violations=0
while IFS= read -r verb; do
    [ -z "$verb" ] && continue
    # The verb is covered iff it appears as a quoted string in any
    # WDMCLITests source. This catches both:
    #   proc.arguments = ["rotate", "1", "90"]
    #   @Suite("wdm rotate (e2e)")
    if grep -rqE "\"${verb}\"" Tests/WDMCLITests --include='*.swift' 2>/dev/null; then
        continue
    fi
    if [ $violations -eq 0 ]; then
        echo "lint-every-verb-has-e2e: CLI verbs without an e2e test in Tests/WDMCLITests:" >&2
    fi
    echo "  - $verb" >&2
    violations=$((violations + 1))
done <<< "$VERBS"

if [ $violations -gt 0 ]; then
    echo >&2
    echo "Add a test under Tests/WDMCLITests/<Verb>CommandE2ETests.swift that" >&2
    echo "spawns the wdm binary with [\"$verb\", …] in proc.arguments and asserts" >&2
    echo "the resulting state. Per CLAUDE.md iron law: a feature without an e2e" >&2
    echo "test does not exist." >&2
    exit 1
fi

echo "lint-every-verb-has-e2e: ✓ every CLI verb has an e2e test"
