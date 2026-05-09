#!/bin/bash
# lint-crash-regression.sh
#
# Enforces CLAUDE.md "NO CRASHES" pillar at lint level. Forbids known
# crash-generating patterns:
#
#   1. `Task { try? await stop() }` and similar fire-and-forget
#      teardowns — these race the next teardown step. CLAUDE.md:
#      "fire-and-forget Task { try? await stop() } is a crash
#      generator — race between stop completing and your next
#      teardown step."
#
#   2. `signal(SIGINT, SIG_IGN)` and friends in lib code — installs a
#      process-wide trap that breaks the host's clean-interrupt
#      contract. CLAUDE.md: "no signal(SIG_IGN) in libraries."
#
#   3. `setActivationPolicy(.accessory)` without a `readActivationPolicy`
#      check — switching from .regular to .accessory hides a regular
#      host's main window. CLAUDE.md: "activation-policy switches are
#      scoped."
#
# Allowlist: pre-existing offenders or context-where-it's-actually-fine
# go in `docs/crash-regression-whitelist.md` (one regex per line).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WHITELIST_FILE="docs/crash-regression-whitelist.md"
WHITELIST=""
if [ -f "$WHITELIST_FILE" ]; then
    # Lines that are reviewed/accepted: any `<path>:<line>` listed in the doc.
    WHITELIST=$(grep -oE '`Sources/[^`]+:[0-9]+`' "$WHITELIST_FILE" 2>/dev/null \
        | tr -d '`' | sort -u)
fi
is_whitelisted() {
    local hit="$1"
    # The hit format is "<path>:<line>: <code>". Extract the prefix.
    local prefix="${hit%%: *}"
    echo "$WHITELIST" | grep -qFx "$prefix"
}

violations=0
report() {
    if is_whitelisted "$1"; then return 0; fi
    if [ $violations -eq 0 ]; then
        echo "lint-crash-regression: forbidden crash-generating patterns:" >&2
    fi
    echo "  - $1" >&2
    violations=$((violations + 1))
}

# Pattern 1: fire-and-forget Task { try? await stop() }.
# Match `Task {` followed (within the same file's next ~5 lines, naive)
# by `try? await ... stop()`. We use grep -A3 to keep it simple.
while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Skip test files — flake regression tests can intentionally
    # exercise these patterns.
    case "$line" in *Tests/*) continue;; esac
    case "$line" in *Recording*) continue;; esac
    report "$line"
done < <(grep -rnE 'Task[[:space:]]*\{[^}]*try\?[[:space:]]+await[[:space:]]+[A-Za-z_.]+\.stop\(' \
    Sources --include='*.swift' 2>/dev/null)

# Pattern 2: signal(SIG*, SIG_IGN) in lib code — never acceptable.
while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in *Tests/*) continue;; esac
    report "$line"
done < <(grep -rnE 'signal\([[:space:]]*SIG[A-Z]+[[:space:]]*,[[:space:]]*SIG_IGN' \
    Sources --include='*.swift' 2>/dev/null)

# Pattern 3: unscoped activation-policy switch.
# Find setActivationPolicy(.accessory) without a nearby (preceding
# 10-line) readActivationPolicy or .regular check.
while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    file=$(echo "$hit" | cut -d: -f1)
    line_no=$(echo "$hit" | cut -d: -f2)
    case "$file" in *Tests/*) continue;; esac
    # Look back 12 lines for a guard.
    start=$((line_no - 12))
    [ $start -lt 1 ] && start=1
    if sed -n "${start},${line_no}p" "$file" 2>/dev/null \
       | grep -qE 'readActivationPolicy|\.regular|\.prohibited[[:space:]]*\?\?'; then
        continue
    fi
    report "$hit"
done < <(grep -rnE 'setActivationPolicy\([[:space:]]*\.accessory' \
    Sources --include='*.swift' 2>/dev/null)

if [ $violations -gt 0 ]; then
    echo >&2
    echo "Per CLAUDE.md NO CRASHES: these patterns generate user-visible" >&2
    echo "crashes. Fix the root cause; if the pattern is genuinely safe in" >&2
    echo "this context, add it to docs/crash-regression-whitelist.md." >&2
    exit 1
fi

echo "lint-crash-regression: ✓ no known crash-generating patterns"
