# WDMKit extraction — design

**Date:** 2026-05-03
**Status:** in progress

## Goal

All reusable orchestration / utilities currently inside `WDMCLI` move into a
new library target `WDMKit`. The UNIX CLI becomes a thin shell that does only:

1. argv parsing
2. dispatch to a Kit operation
3. translate the result to stdout/stderr + exit code

Multiple frontends (CLI, GUI, web) can then sit on the same `WDMKit` surface.

## Layering

```
WDMCore (pure)
  ↑
WDMSystem (effects: CoreGraphics / IOKit / DisplayServices, providers, drivers)
  ↑
WDMKit (orchestration: factories, profile store, formatters, safety, alias overlay)
  ↑
WDMCLI (argv parsing, exit codes, command dispatch — thin)
  ↑
wdm executable
```

`WDMKit` knows nothing of `argv`, `Int32` exit codes, or stdin. It exposes:

- `OutputWriter` (text sink protocol, generic)
- Formatters (JSON / table / completions / manpage) — produce strings
- `ProfileStore`, `AutoProfileStore`, `ProfileApplier`, `SceneStore`, `KeybindingStore`, `VirtualSceneStore`
- `Confirmer` protocol + `AutoYesConfirmer` / `AutoNoConfirmer` / `NativePopupConfirmer` / `StdinConfirmer` (all reusable)
- `SafeTransaction` (the snapshot → apply → confirm → revert primitive)
- `SafeMutation` (the higher-level snapshot+save-last+safe-tx flow currently inlined in `CLI.MutationDispatch`)
- `DisplayProviderFactory` and friends (env-driven construction — `env: [String:String]` is already generic)
- `DDCProviderFactory`, `HDRProviderFactory`, `HotkeyRegistrarFactory`, `LaunchAgentInstaller`
- `DisplayAliasOverlay`
- `DisplayResolver` (alias / "main" / "1" → CGDirectDisplayID)
- `WDMError` cases (currently `CLIError`) — domain error type that lib code throws; exit-code mapping stays in CLI.

## What stays in WDMCLI

- `Args` (argv flag/positional helper)
- `CLIRunner` (top-level dispatch switch)
- `HelpText`
- `ExitCodes` (process exit code constants — UNIX-shaped)
- `CLIDeps` (composition-root struct, constructed from env at process start)
- `Commands/*.swift` (one per subcommand — argv → Kit op → exit code)
- `MutationDispatch` shrinks to argv parsing + confirmer selection, then calls `Kit.SafeMutation.run`.
- `wdm/main.swift` (executable entry)

## TDD posture (no behaviour change)

This is a refactor under existing test coverage:

- 386 tests across `WDMCoreTests`, `WDMSystemTests`, `WDMCLITests` (mostly e2e
  spawning the binary against `WDM_TEST_FIXTURE`) are the safety net.
- Every move runs `swift test` after; tests must stay green.
- No new tests added in this pass — adding lib-only unit tests that re-cover
  behaviour already covered by the e2e harness would be duplicate.
- Once frontends start exercising Kit directly, lib-level unit tests get added
  per the regular Red-Green-Refactor cycle.

## Sequencing

Folders move one at a time. After each move, `swift test`. The order minimises
intermediate breakage by moving leaf-most folders first:

1. `Output/` (no internal deps)
2. `Aliases/`
3. `Format/`
4. `Safety/`
5. `CLIError + ExitCodes` (paired — `CLIError.exitCode` references `ExitCodes`; both move; `ExitCodes` is conceptually CLI-only but moving it together avoids a circular dep — acceptable trade-off given the constants are inert in lib).
6. `Profiles/` (uses `CLIError`)
7. `ProviderFactory/` + `DDC/` + `HDR/` + `Hotkeys/` + `Daemon/`
8. `DisplayResolver`
9. Split `MutationDispatch`: extract Kit-side `SafeMutation`; CLI side keeps argv parsing.
10. Final `swift test` + `swift build -c release` clean (warnings-as-errors).

Phase 2 (per-command extraction into named `Operations/<X>Op.swift`) is **not**
in scope for this pass — Phase 1 already exposes everything reusable. After
Phase 1 lands, frontends can construct providers via factories and call
operations through `Kit.SafeMutation` + the existing protocol surface.
