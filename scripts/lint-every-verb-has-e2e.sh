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
#   - A verb is "covered" iff its kebab-case token appears as the first
#     argument in a CLITestHarness.run([...]) subprocess invocation.
#
# Exit code: 0 if every verb is covered, 1 otherwise.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if grep -R "CLIRunner.run" Tests/WDMCLITests --include='*.swift' \
    | grep -v "Tests/WDMCLITests/CLITestHarness.swift" >/dev/null; then
    echo "lint-every-verb-has-e2e: direct CLIRunner.run calls are not e2e." >&2
    echo "Use CLITestHarness.run so tests spawn the actual wdm binary." >&2
    exit 1
fi

if ! grep -q "Process()" Tests/WDMCLITests/CLITestHarness.swift; then
    echo "lint-every-verb-has-e2e: CLITestHarness must spawn Process()." >&2
    exit 1
fi

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
    # The verb is covered iff it is the first argument to the subprocess
    # harness. Suite names and incidental string literals do not count.
    if VERB="$verb" perl -0ne '
        BEGIN { $verb = quotemeta($ENV{"VERB"}); $found = 0 }
        if (/(?:[A-Za-z_][A-Za-z0-9_]*\.)?(?:[A-Za-z_][A-Za-z0-9_]*)?[Rr]un[A-Za-z0-9_]*\(\s*(?:args:\s*)?\[\s*"$verb"/) {
            $found = 1
        }
        END { exit($found ? 0 : 1) }
    ' Tests/WDMCLITests/*.swift; then
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
    echo "uses CLITestHarness.run([\"<verb>\", …]) and asserts" >&2
    echo "the resulting state. Per CLAUDE.md iron law: a feature without an e2e" >&2
    echo "test does not exist." >&2
    exit 1
fi

echo "lint-every-verb-has-e2e: ✓ every CLI verb has an e2e test"
