# wdm — Workshop Display Manager

Native macOS Unix CLI and Swift library for managing attached displays. The
active product is `wdm`; the retired Mac GUI is archived under
`Archive/gui/2026-05-09` and is not part of the active build, test gate, or
release path.

`AGENTS.md` is a symlink to this file, so these rules are the active
contributor instructions for humans and AI agents.

---

## Current Scope

Active:

- `wdm`: shipped Unix CLI.
- `WDMCore`: pure values, parsers, JSON shapes, and formatters.
- `WDMSystem`: real macOS effects plus fixture/recording implementations for tests.
- `WDMKit`: typed facade and single source of truth for all operations.
- `WDMCLI`: thin argv/stdout/stderr/exit-code frontend.
- `wdm-web` / `WDMWeb`: local HTTP proof of concept over the same Kit layer.

Archived:

- `WDMMac`, `WDMMacRemote`, `WDMRemoteControl`, `wdm-mac`, `wdm-mac-control`.
- GUI tests, Liquid Glass assets/scripts, remote-control docs, and GUI planning tasks.
- Archive location: `Archive/gui/2026-05-09/README.md`.

The archive is preserved for reference only. Do not reintroduce GUI targets,
GUI tests, or remote-control scripts into the active package unless the GUI is
rebuilt from a fresh TDD plan.

---

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.
EVERY USER-FACING FEATURE HAS AN AUTOMATED END-TO-END TEST.
```

Red, green, refactor:

1. RED: write the smallest failing test that describes the next behavior. Run it and verify the expected failure.
2. GREEN: write the minimal production code that makes that test pass.
3. REFACTOR: clean names, structure, and duplication only after the suite is green.

If production code was written before the failing test, delete that code and
restart from the test.

### E2E Rule

Every CLI feature ships with an automated end-to-end test that:

- spawns the actual `.build/debug/wdm` binary as a subprocess,
- runs with `WDM_TEST_FIXTURE=path/to/fixture.json`,
- is hermetic and never touches real hardware,
- asserts stdout, stderr, exit code, and post-state for mutating commands,
- runs in `swift test` with zero manual setup.

Unit tests for pure logic are useful, but they never replace the subprocess e2e
test. A feature without e2e coverage does not exist.

Read-only real-hardware smoke coverage is gated by `WDM_REAL_HARDWARE=1` and
run with `make smoke`. It is additional evidence, not a substitute for e2e.

---

## No Fake Or Fallback Functionality

Every shipped feature must use real APIs, produce real effects, and surface
real failures.

Required:

- Display mutations call the real CoreGraphics/IOKit path in production.
- Saved profiles round-trip through files that `wdm restore` can read back.
- Errors preserve useful system context and map to documented exit codes.
- Cheap post-state verification reads back through the same provider.

Forbidden:

- Production stubs or `return success` placeholders.
- Silent fallbacks that hide failed effects.
- Invented display data in user output.
- Mocks in production paths.
- Hard-coded display IDs or assumed display counts.
- Retry loops that mask broken effects.

Unsupported hardware or OS paths must be probed, refused explicitly, and tested
on both supported and unsupported branches.

---

## No Crashes

A user-visible crash is a release blocker.

Rules:

- Fix or revert crash-causing code before shipping anything else.
- Every crash gets a subprocess regression test first.
- Long-lived callbacks, streams, timers, and notifications must detach before their owner is deallocated.
- Teardown must wait for framework stop semantics before freeing state.
- Re-entered operations must tear down stale state at the start of each run.
- Libraries must not globally ignore SIGINT or SIGTERM.

For CLI crash tests, spawn `wdm`, exercise the path, wait through the race
window, and assert the process exits with the documented status instead of a
signal or uncaught exception.

---

## Crisp Capture And Rendering

Any screen-capture, screenshot, mirror, recording, stream, or overlay path must
operate at native pixel resolution.

Rules:

- Capture in pixels, not points.
- Multiply point sizes by `backingScaleFactor` where AppKit dimensions are involved.
- Set `CALayer.contentsScale` when displaying captured frames.
- Disable framework-side scaling when sizing is controlled by wdm.
- Pin color space where the framework allows it.
- Real-hardware visual tests must assert output pixel dimensions for capture/render paths.

Blur is a defect. A test that only checks that a function ran is not enough.

---

## Modular Code

Hard limits:

- One public type per file.
- Files stay at or below 150 lines.
- Functions stay at or below 30 lines.
- Cyclomatic complexity stays at or below 7 per function.
- Public surface is minimal.
- Modules talk through protocols, not concrete effect implementations.
- No singletons or global mutable state.
- No names with "and"; split the behavior.
- Pure logic lives in `WDMCore`.
- Effects live in `WDMSystem`.
- Business operations live in `WDMKit`.
- Frontends parse and present only.

If a unit is hard to test in isolation, the boundary is probably wrong.

---

## Architecture

```text
Sources/
  WDMCore/              Pure values and pure functions.
  CGVirtualDisplaySPI/  Header bridge for Apple's virtual display SPI.
  WDMSystem/            CoreGraphics, IOKit, ScreenCaptureKit, fixtures, recorders.
  WDMKit/               Typed facade. WDMController is the operation source of truth.
  WDMCLI/               argv -> WDMKit -> stdout/stderr/exit code.
  WDMWeb/               local JSON HTTP -> WDMKit -> JSON.
  wdm/                  tiny executable wrapper for WDMCLI.
  wdm-web/              tiny executable wrapper for WDMWeb.

Tests/
  WDMCoreTests/         pure and lint tests.
  WDMSystemTests/       effect-layer and fixture tests.
  WDMKitTests/          controller tests against fixtures.
  WDMCLITests/          subprocess e2e tests for the real wdm binary.
  WDMWebTests/          local HTTP smoke tests.

Archive/
  gui/2026-05-09/       retired GUI code, tests, docs, scripts, assets.
```

Dependency direction is downward:

```text
WDMCore <- WDMSystem <- WDMKit <- WDMCLI
                                <- WDMWeb
```

Frontend boundary:

```text
input -> frontend parsing -> typed WDMKit call -> typed result -> frontend output
```

Frontend code may parse input, format output, and map `WDMError` to its own
surface. It must not instantiate providers, call provider methods directly, or
duplicate business logic from another frontend.

Every user-visible verb has exactly one Kit operation behind it. If CLI and Web
need the same behavior, the behavior belongs in `Sources/WDMKit/Operations/`.

---

## Unix Style

- Stdout is data and must be pipeable.
- Stderr is for human messages only.
- `--json` means machine-readable JSON.
- Exit codes are meaningful and documented.
- No color unless stdout is a TTY.
- No prompts unless stdin is a TTY.
- Mutating non-interactive commands require `--confirm` or `--no-confirm`.
- Objects are addressed by stable identifiers or documented aliases.
- Commands stay small and composable.

Example:

```sh
wdm arrange list --json \
  | jq '[.[] | .origin.x = .origin.x + 100]' \
  | wdm arrange set @- --no-confirm
```

Exit codes:

| Code | Meaning |
|---:|---|
| 0 | success |
| 1 | generic failure |
| 2 | usage error |
| 3 | display not found |
| 4 | mode or feature unsupported |
| 5 | user cancelled or safe transaction reverted |
| 6 | profile not found |
| 7 | filesystem I/O error |
| 8 | CoreGraphics / IOKit error |

---

## Safety

Every mutating display command goes through the safe transaction path in
`WDMKit`:

1. Snapshot current state.
2. Apply the requested change with `.forSession`.
3. Verify post-state where cheap.
4. Confirm, keep, or revert according to flags and runtime context.
5. Surface typed failures with the documented exit code.

Commands must not bypass this path to call effect providers directly.

---

## Required Gates

Run before pushing:

```sh
make build
make test
make perf-cli
```

`make test` runs the active package gate:

- GUI archive lint.
- CLI boundary lint.
- every-verb subprocess e2e coverage lint.
- no-fakes, modularity, naming, crash, and rendering lints.
- `WDMCoreTests`, `WDMSystemTests`, `WDMKitTests`, `WDMCLITests`, `WDMWebTests`.

`make perf-cli` builds release `wdm` with warnings as errors and checks
fixture-backed CLI latency for common read and mutate paths.

---

## Archive Rule

The retired GUI is intentionally stored, not shipped. Active code must not:

- list archived GUI targets in `Package.swift`,
- depend on archived GUI modules,
- invoke archived GUI scripts from Makefile or lint gates,
- use archived tests as evidence for active behavior.

`scripts/lint-gui-archived.sh` enforces the boundary. If the GUI returns, it
must return as a new tested frontend over `WDMKit`, not as a blind restore of
the archived package graph.
