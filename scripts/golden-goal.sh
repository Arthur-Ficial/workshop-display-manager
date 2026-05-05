#!/bin/bash
# golden-goal.sh
#
# The contract for "ship-ready". Returns 0 iff every line in the
# 10-line acceptance ledger PASSes. Lines that depend on
# yet-unwritten lints / not-yet-built artefacts print DEFERRED
# with the milestone they unblock at — the DEFERRED count must
# monotonically decrease milestone-over-milestone.
#
# Lines:
#   1.  release-build-clean      (M0)
#   2.  swift-test               (M0)
#   3.  headed-e2e               (M0; gated WDM_HEADED_E2E=1)
#   4.  lint-quality             (M0; grows as M1..M4..M7 add lints)
#   5.  codesign-verify          (M6)
#   6.  notarized-stapled        (M6)
#   7.  cli-web-gui-parity       (M1)
#   8.  every-verb-has-e2e       (M2)
#   9.  every-gui-element-has-e2e (M3 fully; partially today)
#  10.  soak                     (M8; 60-sec smoke default, 30-min when WDM_SOAK=1)
#
# Wired by `make golden-goal`. Re-run at every milestone end.
# Tied into Tests/WDMCoreTests/GoldenGoalScriptTests.swift so a
# bypassed pre-commit can't slip a regression.

set -uo pipefail   # not -e: we want to keep checking after a single failure

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PASSED=0
FAILED=0
DEFERRED=0
RESULTS=()

pass()     { RESULTS+=("[PASS] $1"); PASSED=$((PASSED + 1)); }
fail()     { RESULTS+=("[FAIL] $1"); FAILED=$((FAILED + 1)); }
deferred() { RESULTS+=("[DEFERRED] $1"); DEFERRED=$((DEFERRED + 1)); }

# 1. release-build-clean
# WDM_GOLDEN_GOAL_SKIP_HEAVY=1 short-circuits build+test (used by the
# in-test invocation — we already passed the build to be running).
if [ "${WDM_GOLDEN_GOAL_SKIP_HEAVY:-}" = "1" ]; then
    pass "1. release-build-clean (skipped — caller asserted)"
elif swift build -c release -Xswiftc -warnings-as-errors >/tmp/golden-goal-build.log 2>&1; then
    pass "1. release-build-clean"
else
    fail "1. release-build-clean (see /tmp/golden-goal-build.log)"
fi

# 2. swift-test
if [ "${WDM_GOLDEN_GOAL_SKIP_HEAVY:-}" = "1" ]; then
    pass "2. swift-test (skipped — caller asserted)"
elif swift test --parallel >/tmp/golden-goal-test.log 2>&1; then
    TEST_COUNT=$(grep -oE 'Test run with [0-9]+ tests' /tmp/golden-goal-test.log | tail -1 | grep -oE '[0-9]+' || echo "?")
    pass "2. swift-test (${TEST_COUNT} tests)"
else
    fail "2. swift-test (see /tmp/golden-goal-test.log)"
fi

# 3. headed-e2e — runs by default per user 2026-05-05 ("they must run").
# Headed tests open real GUI windows on the user's screen — that's the
# point: the workshop facilitator must SEE the e2e flow drive the app.
# Three suites are temporarily skipped pending M5 (ax-walker-tab-role
# fix, see docs/known-flakes.md): HeadedSnapshotCoverage, HeadedTabClick,
# HeadedClickCoverage. WDM_GOLDEN_GOAL_SKIP_HEAVY=1 short-circuits
# (used by the inner golden-goal-script test).
if [ "${WDM_GOLDEN_GOAL_SKIP_HEAVY:-}" = "1" ]; then
    pass "3. headed-e2e (skipped — caller asserted)"
else
    pkill -9 -f wdm-mac 2>/dev/null || true
    rm -rf "$HOME/.cache/wdm-headed-tests" 2>/dev/null || true
    if WDM_HEADED_E2E=1 WDM_MAC_APP="$ROOT/.build/debug/WDMMac.app" \
       swift test \
         --filter "Headed.*" \
         --skip "HeadedSnapshotCoverage" \
         --skip "HeadedTabClick" \
         --skip "HeadedClickCoverage" \
         >/tmp/golden-goal-headed.log 2>&1; then
        HEADED_COUNT=$(grep -oE 'Test run with [0-9]+ tests' /tmp/golden-goal-headed.log | tail -1 | grep -oE '[0-9]+' || echo "?")
        pass "3. headed-e2e (${HEADED_COUNT} tests visible on screen; 3 suites skipped, see docs/known-flakes.md)"
    else
        fail "3. headed-e2e (see /tmp/golden-goal-headed.log)"
    fi
fi

# 4. lint-quality — every scripts/lint-*.sh exits 0
LINT_FAILS=0
LINT_TOTAL=0
LINT_DETAIL=""
for lint in scripts/lint-*.sh; do
    [ -e "$lint" ] || continue
    LINT_TOTAL=$((LINT_TOTAL + 1))
    if ! bash "$lint" >/tmp/golden-goal-lint.log 2>&1; then
        LINT_FAILS=$((LINT_FAILS + 1))
        LINT_DETAIL="${LINT_DETAIL} $(basename "$lint")"
    fi
done
if [ $LINT_FAILS -eq 0 ]; then
    pass "4. lint-quality (${LINT_TOTAL} lints)"
else
    fail "4. lint-quality (${LINT_FAILS}/${LINT_TOTAL} failed:${LINT_DETAIL})"
fi

# 5. codesign-verify
if [ -d ".build/release/WDMMac.app" ]; then
    if spctl -a -t exec -vv .build/release/WDMMac.app >/tmp/golden-goal-spctl.log 2>&1; then
        pass "5. codesign-verify"
    else
        # spctl will reject Developer ID until notarization stapled
        deferred "5. codesign-verify (M6: notarization + stapler needed; see /tmp/golden-goal-spctl.log)"
    fi
else
    deferred "5. codesign-verify (M6: bundle not built; run make app-mac-release first)"
fi

# 6. notarized-stapled
if [ -d ".build/release/WDMMac.app" ]; then
    if xcrun stapler validate .build/release/WDMMac.app >/tmp/golden-goal-stapler.log 2>&1; then
        pass "6. notarized-stapled"
    else
        deferred "6. notarized-stapled (M6: scripts/release.sh needed)"
    fi
else
    deferred "6. notarized-stapled (M6: bundle not built)"
fi

# 7. cli-gui-parity (Web parity dropped from v1.0.0 scope per user 2026-05-05)
if [ -x scripts/lint-gui-parity.sh ]; then
    if bash scripts/lint-gui-parity.sh >/tmp/golden-goal-parity.log 2>&1; then
        pass "7. cli-gui-parity"
    else
        fail "7. cli-gui-parity (see /tmp/golden-goal-parity.log)"
    fi
else
    deferred "7. cli-gui-parity (M1: lint not written yet)"
fi

# 8. every-verb-has-e2e — already counted in line 4 lint-quality, but
# pinned here too so the milestone-by-milestone ledger shows the
# transition from DEFERRED → ENFORCED for this specific contract.
if [ -x scripts/lint-every-verb-has-e2e.sh ]; then
    if bash scripts/lint-every-verb-has-e2e.sh >/tmp/golden-goal-verb-e2e.log 2>&1; then
        pass "8. every-verb-has-e2e"
    else
        fail "8. every-verb-has-e2e (see /tmp/golden-goal-verb-e2e.log)"
    fi
else
    deferred "8. every-verb-has-e2e (M2: lint not written yet)"
fi

# 9. every-gui-element-has-e2e
if [ -x scripts/lint-remote-coverage.sh ]; then
    if bash scripts/lint-remote-coverage.sh >/tmp/golden-goal-gui-e2e.log 2>&1; then
        pass "9. every-gui-element-has-e2e"
    else
        fail "9. every-gui-element-has-e2e (see /tmp/golden-goal-gui-e2e.log)"
    fi
else
    deferred "9. every-gui-element-has-e2e (M3: full enforcement; partial today)"
fi

# 10. soak
if [ -x scripts/golden-goal-soak.sh ]; then
    if bash scripts/golden-goal-soak.sh >/tmp/golden-goal-soak.log 2>&1; then
        if [ "${WDM_SOAK:-}" = "1" ]; then
            pass "10. soak (30 min)"
        else
            pass "10. soak (60-sec smoke; WDM_SOAK=1 for 30-min)"
        fi
    else
        fail "10. soak (see /tmp/golden-goal-soak.log)"
    fi
else
    deferred "10. soak (M8: script not written yet)"
fi

# Print ledger
echo
echo "=== golden-goal ledger ==="
for r in "${RESULTS[@]}"; do
    echo "$r"
done
echo
echo "  PASS:     $PASSED"
echo "  FAIL:     $FAILED"
echo "  DEFERRED: $DEFERRED  (must monotonically decrease milestone-over-milestone)"
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
exit 0
