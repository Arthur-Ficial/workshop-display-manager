# Golden Goal — CLI/Lib Ship-Ready Spec

The contract that defines the active `wdm` package as ready to ship. The retired
Mac GUI has been archived under `Archive/gui/2026-05-09` and is not part of this
gate.

## Definition

A release-ready `wdm` Unix CLI and Swift library stack where:

- Every CLI verb is backed by one `WDMKit` operation.
- Every CLI verb has an e2e test that spawns the actual `wdm` binary with
  `WDM_TEST_FIXTURE`.
- The active package builds with warnings as errors.
- The CLI/lib/web tests pass without GUI targets in the SwiftPM manifest.
- The release CLI meets the fixture-backed latency budget.
- Real-hardware smoke remains available as an explicit opt-in.

## Acceptance Ledger

`scripts/golden-goal.sh` prints ten lines:

| # | Check |
|---|---|
| 1 | GUI archive lint |
| 2 | Release build clean |
| 3 | Quality lints |
| 4 | `WDMCoreTests` |
| 5 | `WDMSystemTests` |
| 6 | `WDMKitTests` |
| 7 | `WDMCLITests` subprocess e2e |
| 8 | `WDMWebTests` |
| 9 | `perf-cli` |
| 10 | Real-hardware smoke, deferred unless `WDM_REAL_HARDWARE=1` |

## Commands

```sh
make test
make perf-cli
make golden-goal
WDM_REAL_HARDWARE=1 make smoke
```

## Tied To A Hermetic Test

`Tests/WDMCoreTests/GoldenGoalScriptTests.swift` shells the script with
`WDM_GOLDEN_GOAL_SKIP_HEAVY=1` and asserts the ledger shape. A bypassed
pre-commit hook cannot silently break the acceptance harness.
