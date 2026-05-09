#!/bin/bash
# perf-cli.sh
#
# Fast, hermetic performance gate for the shipped Unix surface. Every command
# runs the actual wdm binary against the fixture backend and must stay under the
# per-command budget.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BIN="${WDM_CLI_BINARY:-$ROOT/.build/release/wdm}"
BUDGET_MS="${WDM_CLI_PERF_BUDGET_MS:-1000}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/wdm-perf-cli.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home"
export HOME="$WORK/home"

if [ ! -x "$BIN" ]; then
    echo "perf-cli: $BIN missing or not executable; run make release first" >&2
    exit 2
fi

now() {
    perl -MTime::HiRes=time -e 'printf "%.6f", time'
}

elapsed_ms() {
    perl -e 'printf "%d", (($ARGV[1] - $ARGV[0]) * 1000 + 0.5)' "$1" "$2"
}

write_fixture() {
    local path="$1"
    cat > "$path" <<'JSON'
{
  "snapshot": {
    "createdAt": 1700000000,
    "displays": [
      {
        "id": 1, "name": "Built-in", "isMain": true, "isOnline": true,
        "mirrorSource": null,
        "currentMode": { "width": 2560, "height": 1664, "refreshHz": 60 },
        "origin": { "x": 0, "y": 0 },
        "rotationDegrees": 0
      },
      {
        "id": 2, "name": "Projector", "isMain": false, "isOnline": true,
        "mirrorSource": null,
        "currentMode": { "width": 1920, "height": 1080, "refreshHz": 60 },
        "origin": { "x": 2560, "y": 0 },
        "rotationDegrees": 0
      }
    ]
  },
  "availableModes": {
    "1": [
      { "width": 2560, "height": 1664, "refreshHz": 60 },
      { "width": 1920, "height": 1200, "refreshHz": 60 }
    ],
    "2": [
      { "width": 1920, "height": 1080, "refreshHz": 60 },
      { "width": 1280, "height": 720, "refreshHz": 60 }
    ]
  }
}
JSON
}

failures=0
LAST_FIXTURE=""

fail() {
    echo "perf-cli: FAIL $1" >&2
    failures=$((failures + 1))
}

sanitize() {
    echo "$1" | tr -cs '[:alnum:]' '_'
}

run_perf() {
    local label="$1"
    shift
    local safe
    safe="$(sanitize "$label")"
    local fixture="$WORK/$safe.fixture.json"
    local out="$WORK/$safe.out"
    local err="$WORK/$safe.err"
    local start end ms status
    LAST_FIXTURE="$fixture"
    write_fixture "$fixture"
    start="$(now)"
    WDM_TEST_FIXTURE="$fixture" "$BIN" "$@" >"$out" 2>"$err"
    status=$?
    end="$(now)"
    ms="$(elapsed_ms "$start" "$end")"
    if [ "$status" -ne 0 ]; then
        fail "$label exited $status: $(tr '\n' ' ' <"$err")"
        return 1
    fi
    if [ -s "$err" ]; then
        fail "$label wrote stderr: $(tr '\n' ' ' <"$err")"
        return 1
    fi
    if [ "$ms" -gt "$BUDGET_MS" ]; then
        fail "$label took ${ms}ms (budget ${BUDGET_MS}ms)"
        return 1
    fi
    echo "perf-cli: PASS $label ${ms}ms"
    return 0
}

assert_main_is_two() {
    local fixture="$1"
    local out="$WORK/main-check.out"
    local err="$WORK/main-check.err"
    WDM_TEST_FIXTURE="$fixture" "$BIN" get main id >"$out" 2>"$err"
    local status=$?
    if [ "$status" -ne 0 ]; then
        fail "main post-state check exited $status: $(tr '\n' ' ' <"$err")"
        return
    fi
    if ! grep -qx "2" "$out"; then
        fail "main post-state expected 2, got: $(tr '\n' ' ' <"$out")"
    fi
}

run_perf "help" help
run_perf "version" version
run_perf "list --json" list --json
run_perf "get main id" get main id
run_perf "modes 1 --json" modes 1 --json
run_perf "arrange list --json" arrange list --json
if run_perf "main 2 --no-confirm" main 2 --no-confirm; then
    assert_main_is_two "$LAST_FIXTURE"
fi

if [ "$failures" -gt 0 ]; then
    exit 1
fi
echo "perf-cli: ✓ release CLI commands stayed under ${BUDGET_MS}ms"
