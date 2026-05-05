# Golden Goal — Ship-Ready Spec

The contract that defines "wdm is done." Re-checked at every milestone end via `make golden-goal`.

## Definition

A signed + notarized + stapled `WDMMac.app` plus its companion binaries (`wdm`, `wdm-web`, `wdm-mac-control`), where:

- (a) Every CLI verb has a Kit op AND a GUI surface — or sits on the documented `docs/cli-only-verbs.md` allowlist.
- (b) Every GUI element has a headless e2e test plus a headed visual e2e test.
- (c) Every CLAUDE.md architectural pillar is enforced by an automated lint that runs in `scripts/pre-commit` AND as a hermetic Swift test (so `--no-verify` cannot bypass).
- (d) Every release is reproducible from a single tagged commit via `bash scripts/release.sh <version>`.
- (e) The resulting `.app` opens on a clean Mac (no dev-cert TCC) and survives a 30-minute mixed-driver soak without crashing.

## Acceptance ledger

`scripts/golden-goal.sh` returns 0 iff every line passes:

| # | Check | Unblocks at |
|---|---|---|
| 1 | release-build-clean (`swift build -c release -Xswiftc -warnings-as-errors`) | M0 |
| 2 | swift-test (count ≥ baseline 508) | M0 |
| 3 | headed-e2e (`WDM_HEADED_E2E=1 swift test --filter "Headed.*"`) | M0 |
| 4 | lint-quality (every `scripts/lint-*.sh` exits 0; count grows M1..M4..M7) | M0 (grows) |
| 5 | codesign-verify (`spctl -a -t exec -vv` on `.build/release/WDMMac.app`) | M6 |
| 6 | notarized-stapled (`xcrun stapler validate`; latest CFBundleVersion in notarytool history = Accepted) | M6 |
| 7 | cli-web-gui-parity (`scripts/lint-cli-web-parity.sh` + `scripts/lint-gui-parity.sh`) | M1 |
| 8 | every-verb-has-e2e (`scripts/lint-every-verb-has-e2e.sh`) | M2 |
| 9 | every-gui-element-has-e2e (`scripts/lint-remote-coverage.sh` extended) | M3 (full) |
| 10 | soak (60-sec smoke default; full 30-min when `WDM_SOAK=1`) | M8 |

## Cadence

- Run `make golden-goal` at every milestone end.
- DEFERRED count must monotonically decrease vs the previous milestone.
- If DEFERRED stays flat or grows: stop, report, replan.

## Tied to a hermetic test

`Tests/WDMCoreTests/GoldenGoalScriptTests.swift` shells the script and asserts the documented exit-code shape. A bypassed `git commit --no-verify` cannot land a regression that breaks the harness without also failing the test suite.
