# Spec: wdm — Workshop Display Manager

> Generated 2026-05-05 by running the `/spec` lifecycle phase against the existing codebase. Source of truth for *behaviour and boundaries*; CLAUDE.md remains the source of truth for the development laws (Iron Law, no fakes/fallbacks, modular limits).

---

## Assumptions surfaced before writing

1. The project is **already shipped** for its primary frontend (CLI). This SPEC documents the lived contract and seeds the next planning round — it is not a green-field design doc.
2. The CLI is the canonical surface; Web (PoC) and Mac (in development) are siblings consuming the same `WDMKit` ops.
3. macOS 13+ is the deploy target; macOS 26+ is required only for the Liquid-Glass Mac frontend.
4. Hardware-specific limitations (rotate/flip on Apple Silicon built-ins, brightness on external monitors) are **honest refusals**, not bugs to fix.
5. There is **no CI**: `make test` locally is the gate. (Quota was exhausted on Arthur-Ficial repos — see `.claude/projects/.../memory/feedback_no_github_actions.md`.)

→ Correct any of these now or they govern the rest of the spec.

---

## Objective

Give workshop facilitators (one human, many displays) a scriptable, hermetic-testable, native-macOS tool to read and mutate every aspect of the display configuration — modes, arrangement, mirroring, rotation, flipping, picture-in-picture, virtual displays, screenshot/record/stream, brightness, daemonised auto-restore — without writing AppleScript, without GUI babysitting, and without ever lying about success.

Success looks like:

- A facilitator can save a profile, hot-swap displays during a session, and `wdm restore` returns them to a known-good layout in <1s.
- The same operation reproduces from CLI, web, and (eventually) Mac GUI by calling exactly one shared `WDMController` op.
- An AI agent can drive the GUI via the remote API end-to-end without any osascript / AppleScript.
- Every user-visible verb has an automated e2e test against the fixture provider.

---

## Tech Stack

- **Language:** Swift 6.3+
- **Deploy target:** macOS 13+ (Mac frontend: macOS 26+)
- **Frameworks:** Foundation, CoreGraphics, IOKit, AppKit (NSScreen names), private `DisplayServices` (brightness, dlopen-gated), private `CGVirtualDisplay` SPI, Network.framework (HTTP server), SwiftUI + Liquid Glass (Mac frontend)
- **Runtime deps:** `swift-argument-parser` (Apple)
- **Test framework:** `swift-testing` (built-in)
- **Build / runtime constraint:** zero warnings (`-warnings-as-errors`), zero third-party runtime deps beyond the one above

---

## Commands

```sh
make build               # swift build (debug)
make release             # swift build -c release -Xswiftc -warnings-as-errors
make test                # swift test (hermetic; uses fixture provider, never real hardware)
make smoke               # WDM_REAL_HARDWARE=1 read-only smoke against attached displays
make smoke-mac-remote    # spawn wdm-mac headless, drive via wdm-mac-control, tear down
make e2e-fullflow        # spawn wdm-mac headed, drive every clickable via /ui/* (visible)
make lint-glass          # forbid non-Liquid-Glass chrome in Sources/WDMMac/
make lint-glass-env      # check macOS 26+, Xcode 26+, Swift 6+, NSGlassEffectView header
make lint-remote-coverage # forbid AccessibilityIDs that no test ever clicks
make install             # cp .build/release/wdm /usr/local/bin/wdm
```

Run a single CLI verb against the fixture without touching real hardware:

```sh
WDM_TEST_FIXTURE=$(pwd)/Tests/.../fixture.json .build/debug/wdm list --json
```

---

## Project Structure

```
Sources/
  WDMCore/              Pure value types + pure functions. Foundation only.
  WDMSystem/            Effects layer. DisplayProvider protocol + CG/IOKit + fixture impls.
  WDMKit/               Typed façade. WDMController is THE single source of truth per verb.
  WDMCLI/               Thin frontend. Argv → WDMKit op → exit code + stdout/stderr.
  WDMWeb/               Thin frontend. JSON HTTP → WDMKit op → JSON + status code.
  WDMRemoteControl/     Shared HTTP+SSE remote-control protocol for visual frontends.
  WDMMac/               SwiftUI + Liquid Glass Mac frontend. Headed and --headless.
  WDMMacRemote/         WDMRemoteControl adapter for the Mac frontend.
  CGVirtualDisplaySPI/  Header-only bridging to private CGVirtualDisplay SPI.
  wdm/                  Tiny exec — argv → WDMCLI.run() → exit.
  wdm-web/              Tiny exec — argv → WDMWebMain.run() → HTTP server.
  wdm-mac/              Tiny exec — launches WDMMac app.
  wdm-mac-control/      Companion CLI mirroring agent-browser surface 1:1.

Tests/
  WDMCoreTests/         Pure unit tests.
  WDMSystemTests/       Effect-layer protocol tests.
  WDMKitTests/          Lib-level tests against FixtureDisplayProvider.
  WDMCLITests/          E2E: invoke CLIRunner with WDM_TEST_FIXTURE, assert stdout/stderr/exit.
  WDMWebTests/          Real-HTTP smoke against ephemeral localhost port.
  WDMMacE2ETests/       Headed/headless GUI driven via the remote API only.
  WDMMacRemoteTests/    AX walker + remote API unit tests.
  WDMRemoteControlTests/ Protocol round-trip tests.

docs/
  architecture.md, contributing.md, safety.md, troubleshooting.md, workflows.md, release.md
  known-issue-applehpm-panic.md
  superpowers/specs/    Per-feature design docs (kept alongside the code).
```

Layering rule: dependencies point downward only.
`WDMCore` ⤺ `WDMSystem` ⤺ `WDMKit` ⤺ {`WDMCLI`, `WDMWeb`, `WDMMac`, future frontends}.
Frontends are siblings and never import each other. Frontends never import `WDMSystem`.

---

## Code Style

One representative slice — typed Kit op wired through a thin frontend:

```swift
// Sources/WDMKit/Operations/WDMControllerArrangement.swift
extension WDMController {
    /// Atomically apply a full arrangement plan via a single safe-tx.
    /// Throws WDMError.displayNotFound for any unknown alias.
    public func setArrangement(
        _ plan: ArrangementPlan,
        confirmer: Confirmer
    ) throws -> ApplyResult {
        let resolved = try plan.resolve(against: provider.snapshot())
        return try SafeMutation.apply(resolved, provider: provider, confirmer: confirmer)
    }
}

// Sources/WDMCLI/Commands/Arrange.swift
struct ArrangeSet: ParsableCommand {
    @Argument var input: String              // "@-" or "@<path>"
    @Flag var noConfirm: Bool = false

    func run(deps: CLIDependencies) throws {
        let plan = try ArrangementPlan.read(input)
        let confirmer = noConfirm ? .none : deps.terminalConfirmer
        let result = try deps.controller.setArrangement(plan, confirmer: confirmer)
        deps.stdout.write(result.summary)
    }
}
```

Conventions:

- One public type per file. File name = type name. ≤150 lines per file. ≤30 lines per function. Cyclomatic ≤7.
- Default to `internal`. `public` only when another module needs it.
- Modules talk via protocols (`DisplayProvider`, `Confirmer`, `WindowMover`, …). DI everywhere; no singletons; no `static var shared`.
- Pure where possible. Effects only in `WDMSystem`. `WDMKit` orchestrates. Frontends never call `provider.*`.
- Names: no "and" — `parseAndValidate` ⇒ split into `parse` + `validate`.
- Comments explain *why*, never *what*. Default to none.

---

## Testing Strategy

- **swift-testing** (built-in to Swift 6).
- **Hermetic by default.** `make test` runs the entire suite against the fixture provider — no real hardware, no environment dependencies.
- **Real-hardware smoke** (`make smoke`) runs read-only operations against attached displays, gated by `WDM_REAL_HARDWARE=1`. Additional, never a substitute for e2e.
- **Mandatory e2e per verb.** Every user-facing verb spawns the actual `wdm` binary as a subprocess, with `WDM_TEST_FIXTURE=...`, asserts stdout + stderr + exit code + post-state. A verb without an e2e test does not exist.
- **Mac GUI tests are 100% truthful.** `WDMMacE2ETests` drive the headless GUI via the remote API only — no AX shortcuts in production code paths, no osascript anywhere under `Tests/` or `Sources/`. Smoke shell scripts are demos, not tests.
- **Lint as test.** `make lint-glass`, `make lint-glass-env`, `make lint-remote-coverage` are first-class — failures block.
- **Coverage target:** every public Kit op + every CLI verb + every web route + every GUI remoteID has a green automated test. Currently: 470 tests across 114 suites.

---

## Boundaries

### Always do
- Write a failing test before any production code (Iron Law).
- Use real APIs end to end. Probe at runtime when an API may be unavailable; refuse explicitly with a typed error and the documented exit code.
- Run `make test` green before commit. Run `make release` warnings-as-errors clean before release.
- Pass through `WDMController` for every verb. Frontends format only.
- Land each feature with its e2e test in the same commit.
- **Every feature ships with a *visual* headed e2e remote-control test, not just headless.** The headless registry path proves the wiring; only the headed `WDM_HEADED_E2E=1` path proves SwiftUI actually lays out the controls a human sees and that AppKit's accessibility tree exposes them. A feature that passes only the headless suite has not been demonstrated to work — see CLAUDE.md "Tests are 100% truthful — non-negotiable" and the three-step RED → GREEN → DEMO rule. The test must drive the feature through the live `/ui/*` HTTP API the same way `wdm-mac-control` does, and assert observable state change post-click. No osascript, no AppleScript, no `tell application "System Events"` anywhere under `Tests/`.

### Ask first
- Adding a runtime dependency (anything beyond `swift-argument-parser`).
- Changing an exit code or an existing CLI verb's surface (breaking change).
- Touching CGVirtualDisplay SPI, IOKit transforms, or DisplayServices brightness — anything private.
- Bumping the macOS deploy target.
- Flipping the GitHub repo visibility (NEVER autonomous; always confirm twice).

### Never do
- Ship a fallback that hides a failed real effect. Failure must be loud, with the right exit code.
- Ship a stub with `// TODO: actually implement`. Either the path is real or the verb refuses with `WDMError.unsupported`.
- Use the fixture provider in production. `WDM_TEST_FIXTURE` must not affect a release-built binary.
- Add osascript / AppleScript / `tell application "System Events"` anywhere under `Sources/`, `Tests/`, or `scripts/` (lint scripts naming the patterns to ban them are the only exception).
- Introduce a GUI element without a stable `.remoteID("<area>.<thing>")` and a test that drives it through the remote API.
- Skip `--no-verify` on git commits.

---

## Success Criteria (lifecycle gates)

- [x] `make test` exits 0 with 470+ tests across 114+ suites
- [x] `make release` exits 0 with zero warnings
- [x] Every CLI verb in CLAUDE.md has a matching e2e test under `Tests/WDMCLITests/`
- [x] Every Kit op is reachable from CLI and Web; web smoke passes against fixture
- [x] `make e2e-fullflow` drives the headed GUI through `/ui/*` only — zero osascript
- [ ] WDMMac frontend reaches feature parity with CLI for read verbs (target: next planning cycle)
- [ ] Drag-to-rearrange GUI hooks ship as a worked example of `wdm arrange` (target: same)

---

## Open Questions

1. **WDMMac feature scope for v1.** Mirror exactly the CLI verb set, or trim to a curated subset for the workshop use case?
2. **Web frontend status.** Is `wdm-web` a permanent PoC (no auth, localhost only), or does it need TLS + tokens for the workshop network in v2?
3. **Hooks installation.** Should the Addy Osmani agent-skills `hooks/` (sdd-cache, simplify-ignore, session-start) be wired into `.claude/settings.local.json` as a follow-up, or kept out as decided in `.claude/AGENT-SKILLS.md`?
4. **Brightness fallback.** Currently throws on external monitors. Worth wiring DDC/CI for external monitors that support it, despite the "out of scope" note in CLAUDE.md? (Answer per CLAUDE.md is "no, use the OSD" — confirm this still holds.)
