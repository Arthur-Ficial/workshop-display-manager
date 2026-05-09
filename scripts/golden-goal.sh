#!/bin/bash
# golden-goal.sh
#
# Ten-line acceptance ledger for the active Unix CLI/lib package. The retired
# Mac GUI has its own archive and is intentionally not part of this gate.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PASSED=0
FAILED=0
DEFERRED=0
RESULTS=()

pass()     { RESULTS+=("[PASS] $1"); PASSED=$((PASSED + 1)); }
fail()     { RESULTS+=("[FAIL] $1"); FAILED=$((FAILED + 1)); }
deferred() { RESULTS+=("[DEFERRED] $1"); DEFERRED=$((DEFERRED + 1)); }

run_line() {
    local n="$1"
    local label="$2"
    local log="$3"
    shift 3
    if [ "${WDM_GOLDEN_GOAL_SKIP_HEAVY:-}" = "1" ]; then
        pass "$n. $label (skipped — caller asserted)"
    elif "$@" >"$log" 2>&1; then
        pass "$n. $label"
    else
        fail "$n. $label (see $log)"
    fi
}

run_line 1 "gui-archived" /tmp/golden-goal-gui-archived.log \
    bash scripts/lint-gui-archived.sh
run_line 2 "release-build-clean" /tmp/golden-goal-release.log \
    make release
run_line 3 "quality-lints" /tmp/golden-goal-lint.log \
    make lint
run_line 4 "WDMCoreTests" /tmp/golden-goal-core.log \
    swift test --no-parallel --filter WDMCoreTests
run_line 5 "WDMSystemTests" /tmp/golden-goal-system.log \
    swift test --no-parallel --filter WDMSystemTests
run_line 6 "WDMKitTests" /tmp/golden-goal-kit.log \
    swift test --no-parallel --filter WDMKitTests
run_line 7 "WDMCLITests subprocess e2e" /tmp/golden-goal-cli.log \
    swift test --no-parallel --filter WDMCLITests
run_line 8 "WDMWebTests" /tmp/golden-goal-web.log \
    swift test --no-parallel --filter WDMWebTests
run_line 9 "perf-cli" /tmp/golden-goal-perf.log \
    make perf-cli

if [ "${WDM_GOLDEN_GOAL_SKIP_HEAVY:-}" = "1" ]; then
    pass "10. real-hardware-smoke (skipped — caller asserted)"
elif [ "${WDM_REAL_HARDWARE:-}" = "1" ]; then
    if make smoke >/tmp/golden-goal-smoke.log 2>&1; then
        pass "10. real-hardware-smoke"
    else
        fail "10. real-hardware-smoke (see /tmp/golden-goal-smoke.log)"
    fi
else
    deferred "10. real-hardware-smoke (set WDM_REAL_HARDWARE=1 to run)"
fi

echo
echo "=== golden-goal ledger ==="
for r in "${RESULTS[@]}"; do
    echo "$r"
done
echo
echo "  PASS:     $PASSED"
echo "  FAIL:     $FAILED"
echo "  DEFERRED: $DEFERRED"
echo

if [ $FAILED -gt 0 ]; then
    echo "golden-goal: NOT MET ($FAILED failures)"
    exit 1
fi
if [ $DEFERRED -gt 0 ]; then
    echo "golden-goal: ON TRACK (no failures; $DEFERRED deferred)"
    exit 0
fi
echo "golden-goal: ✓ MET (10/10 ENFORCED)"
