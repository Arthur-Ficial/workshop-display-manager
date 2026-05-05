# wdm — Workshop Display Manager

Native macOS CLI for managing all attached displays. 100% Swift, no shell-outs, no third-party runtime deps beyond Apple's `swift-argument-parser`.

---

## THE IRON LAW (non-negotiable)

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.
EVERY FEATURE HAS AN AUTOMATED END-TO-END TEST.
```

This is binding for every contributor (human or AI). Violating the letter violates the spirit.

### Red → Green → Refactor, every time

1. **RED.** Write the smallest failing test that describes the next behaviour. Run it. Watch it fail with the *expected* failure message. If it passes immediately, the test is wrong — delete it and start over.
2. **GREEN.** Write the minimal code that makes the test pass. Nothing more. No "while I'm here" extras. No speculative options. No premature abstraction.
3. **REFACTOR.** Only on green. Names, duplication, structure. Tests stay green throughout. No new behaviour.

If you wrote production code without a failing test first: **delete it, re-read this file, start the cycle.** Do not "adapt" the deleted code while writing the test — implement fresh from the test.

### 100% E2E coverage rule

Every user-facing feature ships with an automated **end-to-end** test that:

- spawns the actual `wdm` binary as a subprocess (no in-process shortcuts),
- runs it against the **fixture display backend** (`WDM_TEST_FIXTURE=path/to/fixture.json`) so the test is hermetic and never touches real hardware,
- asserts on stdout, stderr, exit code, and (for mutating commands) the post-state of the fixture,
- runs in `swift test` with zero manual setup.

Unit tests for pure logic are encouraged on top of this. They do not replace the e2e test.

A feature without an e2e test does not exist. Do not merge it. Do not claim it works.

### Real-hardware smoke test

Read-only operations against real CoreGraphics also have a smoke test gated by env var `WDM_REAL_HARDWARE=1`. Run via `make smoke`. This is *additional* to e2e, never a substitute.

---

## NO FAKE OR FALLBACK FUNCTIONALITY (non-negotiable)

**Every feature must be real and really, really working. No fakes. No fallbacks. No pretending.**

This is the third pillar, equal to the iron law and modular code. Read it before you write a single line.

### What "real" means

- **Real APIs, real effects.** A command that says "set the main display" calls `CGCompleteDisplayConfiguration` and the OS actually moves the menu bar. It does not log "would set main display" and return success. It does not write to a file and call that "applied".
- **Real data, real round-trips.** A command that says "saved profile" must produce a file that `wdm restore` can read back and reproduce the exact configuration. Verified by e2e test, end-to-end, every time.
- **Real errors.** If the system call fails, surface the underlying error code with context. Never swallow. Never translate to a generic success. Never `try?` an effect away.
- **Real verification.** Before claiming a command worked, read the post-state back through the same `DisplayProvider` and assert it matches what the user asked for. The e2e test does this; the runtime path should too where cheap.

### What is NOT allowed

- ❌ **No stubs in production code paths.** If a feature isn't fully implemented for a target, it doesn't ship. Period. No `// TODO: actually implement`. No `return .success` placeholders.
- ❌ **No silent fallbacks.** Don't catch a CoreGraphics error and "fall back" to a no-op that pretends success. If the real path fails, fail loudly with the right exit code.
- ❌ **No fake data in human output.** `wdm list` shows what `CGGetActiveDisplayList` returns. It does not invent a display. It does not show a "default" entry when the API returns empty.
- ❌ **No mocks in production.** The fixture backend exists for **tests only**, gated by `WDM_TEST_FIXTURE`. It must be impossible to accidentally ship a binary that uses it. Production builds use `CGDisplayProvider`, full stop.
- ❌ **No "graceful degradation" that hides failure.** If brightness control isn't supported on a display, return the documented error code (not `0.5` as a guess, not `nil` masquerading as success). The user must be able to tell the difference between "feature unavailable" and "feature applied".
- ❌ **No "it works in the demo" shortcuts.** No hard-coded display IDs. No assumed display counts. No "if there's only one display, just …" branches that mask the general case.
- ❌ **No retry-until-success loops that mask broken effects.** If `CGBeginDisplayConfiguration` fails, exit `8`. Don't retry blindly hoping it works on the third try.

### Honest unsupported-path policy

When a hardware or OS limitation genuinely blocks a feature (see "Hardware-specific limitations" below), the response is:

1. **Probe at runtime.** Detect whether the API is available on this machine.
2. **Refuse explicitly.** Throw a typed error → exit code → human-readable stderr message that says exactly what's unsupported and what the user can do instead.
3. **Test both branches.** The e2e test asserts the supported path produces the real effect, and the unsupported path produces the documented refusal. Both are real behaviour.

This is the opposite of a fallback. A fallback hides the limitation; honest refusal exposes it.

### Smell check before commit

For every changed file, ask:

- Does every function that claims to do X actually do X, end to end, on real input?
- If I pulled the network cable / removed a display / revoked a permission, would this code lie about success?
- Is there any code path I added "just in case" that returns a value I made up?

If any answer is yes: delete the lie, surface the failure, write the test that proves the real path.

---

## NO CRASHES (non-negotiable)

**A user-visible crash is a release-blocker, never a "we'll get to it." Crashes are measured, controlled, and fixed before anything else ships.**

The user reported "the app crashed after Flip" 2026-05-05. That kind of report must never appear in a production session.

### Hard rules

- **Crash = priority 0.** Drop whatever else you're doing. The next commit fixes the crash, or reverts the code that introduced it.
- **Every crash gets a regression test.** Before fixing, write a test that proves the crash existed. Spawn the binary as a subprocess, exercise the path, assert `proc.isRunning == true` afterwards (or assert the listener-port still accepts). The test must FAIL on the broken build and PASS on the fixed one. CLAUDE.md "tests must actually run" applies double here — a crash test that's never executed catches nothing.
- **Race conditions in tear-down are crashes.** Specifically: framework callbacks (SCStream sample buffers, IOKit notifications, NSWindow delegates, timers) firing after their owning state has been deallocated. Always detach the callback's reference to the dying state BEFORE freeing the state, AND wait synchronously for the framework's stop semantics before proceeding. "Fire-and-forget Task { try? await stop() }" is a crash generator — race between stop completing and your next teardown step.
- **Defensive teardown at re-entry.** Long-lived flippers / streamers / probes that get reused across calls must `teardown()` at the start of each `run()` so leftover state from a prior run can't race the new one.
- **No `signal(SIG_IGN)` in libraries.** A library that ignores SIGINT/SIGTERM globally breaks the host's ability to be interrupted cleanly. Use `DispatchSourceSignal` *without* the SIG_IGN preamble in CLI-only paths; in GUI hosts the host already owns signal handling.
- **Activation-policy switches are scoped.** Switching to `.accessory` is appropriate for a CLI process about to draw an overlay (suppresses Dock-icon flash). For a GUI host (wdm-mac), switching to `.accessory` HIDES the user's main window and looks like a crash. Read the current policy, only switch from `.prohibited`.

### How to "make it testable" for crashes

Standard pattern:
1. Spawn the binary as a subprocess in the test (`spawnHeadless(env:)` already does this).
2. Drive the suspect path via `/ui/click` or another stable interface.
3. Wait long enough for the bug's race window to fire (1–2 × the longest async operation).
4. Assert the subprocess is still alive: `#expect(proc.isRunning)` AND `#expect(isPortAccepting(port:))`. Both, because a process can be alive in the kernel sense but its listener thread can have crashed.

The test is the contract. If a crash recurs in any form, this test catches it before the user does.

---

## CRISP-AS-DAY RENDERING (non-negotiable)

**Anything that captures or renders a display must do so at NATIVE PIXEL RESOLUTION. No exceptions, no upscaling, no "good enough."**

User-visible blur in flip-overlays, picture-in-picture mirrors, screen recordings, screenshots, or stage thumbnails is a defect, not a polish item. The user's eye notices a 1-pixel softness on Retina; treating that as acceptable lies to them about what wdm is doing.

### Hard rules for every screen-capture / render path

- **Capture in pixels, not points.** `SCDisplay.width/height`, `NSScreen.frame`, `CGDisplayBounds(...)` — every framework's "size" property may return logical points. On Retina, points × `nsScreen.backingScaleFactor` = native pixels. Capture-config dimensions (e.g. `SCStreamConfiguration.width/height`) MUST be in pixels. If you don't multiply by the scale, you capture at half resolution and upscale = blur.
- **Mark `CALayer.contentsScale`.** When rendering a captured frame back into a `CALayer`, set `contentsScale = backingScaleFactor`. CoreAnimation otherwise treats your hi-DPI bitmap as 1x and rescales = blur.
- **Filter `.nearest` on pixel-aligned content.** When the source pixel dims match the destination pixel dims, `magnificationFilter = .nearest` keeps every pixel sharp. Bilinear scaling on already-aligned pixels is a soft-blur generator. Use linear/trilinear filters only when you genuinely need to scale.
- **No `scalesToFit`.** `SCStreamConfiguration.scalesToFit = false`. We control sizing explicitly; framework-side scaling defeats the rule.
- **60 fps minimum.** `cfg.minimumFrameInterval = CMTime(value: 1, timescale: 60)` for anything that follows the user's screen — workshop facilitators see at the screen's refresh rate, the overlay must too.
- **Color-space pinned.** `cfg.colorSpaceName = CGColorSpace.sRGB` so the captured frame doesn't get re-tagged in transit (color-shifted overlays look "off" in a way users can't articulate but feel).

### Test for it

Every screen-capture path must have a real-hardware visual test that:
1. Triggers the capture/render.
2. Reads the resulting bitmap (file output, layer contents, screenshot).
3. Asserts the pixel dimensions match `display.width × backingScaleFactor`.

A test that asserts "the function ran" without checking output dimensions does not catch the upscale bug.

### Smell check before commit

For any new screen-capture / render code, ask:
- Did I multiply by `backingScaleFactor` somewhere?
- Did I set `layer.contentsScale`?
- Did I set the magnification/minification filter explicitly, or am I relying on a default that's likely bilinear?
- Did I run it on the user's real Retina display and look at the output with my own eyes?

If any answer is no, the path is blurry. Fix it before shipping.

---

## SUPER RESPONSIVE INTERACTION (non-negotiable)

**Every interaction in WDMMac must be SUPER fast. No sluggishness. No exceptions.**

This is the fourth pillar, equal to the iron law / no-fakes / modular. The user reported it twice with screenshots; if a click feels off-instant, that is a defect, not a tradeoff.

### Hard targets (enforced — measurable, not vibes)

- **First visible feedback after click ≤ 50 ms.** The button highlight, the slider thumb move, the tab swap — *something* visibly responds in under one display frame at 60 Hz. CSS / SwiftUI default cross-fade is 0.25 s — that is *too slow* on its own; add explicit `.animation(.easeOut(duration: 0.08))` or remove the implicit animation entirely on hot-path controls.
- **Full state change ≤ 100 ms.** Clicking a rotation segment → display rotates and the new tile origin appears in the snapshot within 100 ms wall time on the user's MacBook Air.
- **Slider drag ≤ 16 ms per tick.** Brightness slider must keep up at 60 Hz. If the controller call costs more, throttle/coalesce — never block.
- **`/ui/click` → `/ui/snapshot` round-trip ≤ 100 ms** on the test rig. Hermetic e2e benchmark — if it ever exceeds, the build fails.

### What this forbids

- ❌ Default SwiftUI animations on hot-path interactions. They look fine on first sight and feel sluggish on the third click. Override with explicit short durations or remove.
- ❌ Doing extra work per click. `reload()` after every VM mutation re-fetches every display + every brightness — do the minimum: update only what changed.
- ❌ Synchronous IPC on the main thread on click. Round-trips to WebContent / DisplayServices / IOKit go off-main; main thread updates the visible state immediately, the IPC reconciles in the background.
- ❌ Combine subscribers that rebuild the entire registry on every `@Published` write. Diff or scope the trigger to the field that actually changed.
- ❌ Animations on AX-tree-visible elements that delay the AX walker seeing the new state. The AI tests must observe state change within the 100 ms budget too.

### What this requires

- ✅ Profile, don't guess. Use `os_signpost` / `signposter.beginInterval(...)` around suspect spans. The PERF ticket in `tasks/todo.md` tells you where to look first.
- ✅ Measure on the *user's hardware*. Synthetic benchmarks lie; the workshop facilitator clicking on their MacBook Air is the only ground truth that matters.
- ✅ Add a hermetic perf e2e for every new hot path. `swift test --filter Perf*` should bench the round-trip and fail if any verb exceeds its budget.
- ✅ Treat sluggishness as a **defect**, not a polish item. File it like a crash. Block the next feature on it if it regresses past the budget.

If a click on this app ever feels even slightly slower than a click in System Settings, you have failed this pillar. Fix it before shipping anything else.

---

## SUPER MODULAR CODE (non-negotiable)

The codebase is decomposed into the smallest sensible units. Every file does one thing. Every type has one reason to change. Every function has one job.

**Hard limits, enforced by review:**

- **One public type per file.** File name = type name. No `Utilities.swift` grab-bags.
- **Files ≤ 150 lines.** Over the limit → split. No exceptions for "it's all related".
- **Functions ≤ 30 lines.** Over the limit → extract. Long functions hide bugs.
- **Cyclomatic complexity ≤ 7 per function.** Deep nesting → extract a helper or invert the condition.
- **Public surface is minimal.** Default to `internal`. `public` only when another module genuinely needs it. Every `public` symbol is a promise.
- **Modules talk through protocols, not concretes.** `WDMCLI` consumes `DisplayProvider`, not `CGDisplayProvider`. Swap-in, swap-out.
- **Dependency injection everywhere.** No singletons. No global state. No `static var shared`. Anything stateful is constructed and passed in.
- **No "and" in names.** `parseAndValidate(...)` → split into `parse` and `validate`. A name with "and" is two things pretending to be one.
- **Pure where possible.** Anything that doesn't need I/O or system calls lives in `WDMCore` as a free function on a value type. Pure functions are the cheapest unit to test.
- **Effects at the edges.** I/O, CoreGraphics, the filesystem live in `WDMSystem`. Business logic in `WDMCore` is effect-free. `WDMCLI` orchestrates.

**Why:** modular code is testable code. If a unit is hard to test in isolation, the boundaries are wrong. Listen to the test pain — it's design feedback, not a testing problem.

**Smell check before commit:** open every changed file. Could a new contributor describe what it does in one sentence? If not, it's doing too much. Split it.

---

## Architecture

```
Sources/
  WDMCore/      Pure value types + pure functions. No I/O, no Apple frameworks beyond Foundation.
                Mode, DisplayInfo, Profile, Snapshot, ArrangementEntry, parsers, formatters, JSON codec.
  WDMSystem/    Effects layer. DisplayProvider protocol + two implementations:
                  - CGDisplayProvider (real, CoreGraphics + IOKit)
                  - FixtureDisplayProvider (reads/writes a JSON fixture for tests)
                Plus injectable side-effect protocols: CursorIO, ProcessLister,
                ProcessSignaler, Screenshotter, Recorder, Streamer, PipFlipper,
                OverlayFlipper, DisplayCapturer, VirtualDisplayManager,
                Sleeper, WindowMover, WindowLister, CursorTracker, DDCProvider,
                HDRProvider, HotkeyRegistrar, DisplayEventStream — each with a
                real impl + a recording impl for hermetic tests.
  WDMKit/       Typed façade — the SINGLE SOURCE OF TRUTH for every operation.
                WDMController is the cohesive entry point, organised by domain
                in Operations/WDMController<Topic>.swift. Profile/scene stores,
                safety primitives (SafeMutation, Confirmer), provider factories,
                formatters, alias overlay, typed errors (WDMError) all live
                here. Knows nothing of argv, exit codes, stdin, FileHandle, or HTTP.
  WDMCLI/      THIN frontend. Argv → WDMKit op → exit code + stdout/stderr.
                Commands/*.swift never `import WDMSystem` and never instantiate
                providers directly — they go through `deps.controller` (a WDMController).
  WDMWeb/       THIN frontend. JSON HTTP → WDMKit op → JSON + HTTP status.
                Imports ONLY WDMKit — never WDMSystem, never WDMCLI. Backed by
                Foundation Network.framework, no third-party deps. One handler
                per CLI verb in Handlers/, declarative routes in Router/Routes.swift.
  wdm/          Tiny executable: parses argv, calls WDMCLI.run(), exits.
  wdm-web/      Tiny executable: parses argv, calls WDMWebMain.run(), serves HTTP.

Tests/
  WDMCoreTests/    Pure unit tests for Core types.
  WDMSystemTests/  Tests for the effect-layer protocols (round-trip, error paths).
  WDMKitTests/     Lib-level tests for every WDMController op against the
                   FixtureDisplayProvider (red→green per new symbol).
  WDMCLITests/     E2E: invoke CLIRunner with WDM_TEST_FIXTURE, assert exit
                   code + stdout/stderr.
  WDMWebTests/     Real-HTTP smoke: bind to ephemeral localhost port, drive
                   routes via URLSession, assert status + body.
```

**Layering rule:** dependencies only point downward. `WDMCore` ⤺ `WDMSystem` ⤺
`WDMKit` ⤺ {`WDMCLI`, `WDMWeb`, future `WDMMac`}. The frontends are SIBLINGS;
they never depend on each other. CLI must never `import WDMSystem` from a
command file. Web must never `import WDMSystem` or `import WDMCLI`.

**SSOT + DRY (non-negotiable):** every user-visible verb has EXACTLY ONE Kit
op behind it. Adding a new verb = (1) add a method on `WDMController` (or a
typed enum like `WDMController.virtual`), (2) add a frontend wrapper per
frontend that needs it. Two frontends never re-implement the same logic. If
you find yourself copying logic between `Sources/WDMCLI/Commands/X.swift` and
`Sources/WDMWeb/Handlers/X.swift`, the extraction is incomplete — push it
into `Sources/WDMKit/Operations/`.

### Frontend boundary contract

A frontend is anything user-facing: CLI, web, GUI, IDE plugin, MCP server.
Every frontend follows the same shape:

```
input  → frontend-specific parsing (argv / HTTP / GUI events / RPC)
       → typed Kit call (WDMController.<verb>(...))
       → typed Kit result (value / ApplyResult / typed throw)
       → frontend-specific output (stdout+exit code / JSON+HTTP status / GUI redraw / RPC reply)
```

Frontend code is allowed to:
- Parse its own input format.
- Format Kit results for its presentation layer (table, JSON, HTML).
- Map `WDMError` cases to its own surface (exit codes, HTTP status, alert).

Frontend code is NOT allowed to:
- Call `provider.snapshot()` or any other `DisplayProvider` method directly.
- Import `WDMSystem`.
- Instantiate stores, factories, or safety primitives that live in `WDMKit`.
- Re-implement business logic that another frontend already drives.

**Adding a new frontend** (e.g. WDMMac SwiftUI app, MCP server): create a
sibling target depending only on `WDMKit`. You should be able to drive every
existing verb without touching any other module.

### AI-controllable frontends — non-negotiable for every GUI / web frontend

Every visual frontend (WDMMac today, WDMWeb's `--remote` later, every
future GUI / MCP server / IDE plugin) MUST expose every user interaction
over a localhost remote-control API. The reference shape is Vercel's
`agent-browser`: a typed accessibility-style scene snapshot is the
**primary** state surface, PNG screenshots are optional, events stream
live over SSE.

**Routes** (full spec in
`docs/superpowers/specs/2026-05-04-ai-controllable-gui-design.md`):

- `GET /ui/snapshot[?interactive=1]` — JSON scene tree, stable `@e1`-style
  refs per launch. The primary state surface — same role as
  `agent-browser snapshot -i`.
- `GET /ui/state` — typed app-level state (selection, sheets, toasts,
  safe-tx, recordings).
- `GET /ui/events` — SSE stream of every state mutation. Mandatory; the
  AI must not need to poll.
- `GET /ui/screenshot[?ref=@e2]` — PNG of the window or one element.
  Optional convenience.
- `GET /ui/diff/snapshot` — per-client diff vs previous snapshot.
- `POST /ui/click|dblclick|hover|focus|scroll|scrollintoview|drag|fill|type|press|select|check|uncheck`
  — every action a human can perform with mouse / keyboard.

**Contract.** The protocol lives in `WDMRemoteControl`
(`RemoteControllable`). The HTTP+SSE server (`RemoteControlServer`) is
shared. Each frontend ships a thin adapter (`WDMMacRemoteAdapter`,
future `WDMWebRemoteAdapter`).

**Defaults.** Off. A frontend launched without `--remote` opens NO
listener and writes NO token. With `--remote`: bind `127.0.0.1` only,
per-launch bearer token written to `~/.config/wdm/remote.json` (0600), no
TLS, headed by default, `--headless` for offscreen rendering (hermetic
tests + future MCP).

**Visual feedback (mandatory).** Every action triggers a glass-effect
halo over the target element with the verb label, ~600 ms fade. Local
human always sees what the AI just did. `--no-halo` disables (intended
for video capture only).

**Element identity.** Every interactive element declares a stable
`.remoteID("<area>.<thing>")` at view-declaration time (aliased to
`.accessibilityIdentifier`). Auto-generated runtime IDs are forbidden —
they re-shuffle on re-render and break the snapshot contract.

**Companion CLI.** Every visual frontend ships a sibling executable that
mirrors the `agent-browser` surface 1:1 (e.g. `wdm-mac-control snapshot
-i`, `wdm-mac-control click @e2`). Pure unix-pipe demos must work end-
to-end with no GUI scripting.

**Tests are 100% truthful — non-negotiable.** A test that "passes" must
prove the actual feature works. Specifically:

- A bash smoke is a **demo**, not a test. Smokes don't count as e2e
  coverage. Real coverage = real Swift tests under
  `Tests/WDMMacE2ETests/` with assertions.
- Listing an `accessibilityIdentifier` value as a string literal is NOT
  coverage. The ID must appear inside an actual click verb
  (`wdm-mac-control click`, `/ui/click` POST,
  `AXUIElementPerformAction`). The lint
  `make lint-remote-coverage` enforces this.
- The remote API and the in-process AX walker are the SOLE acceptable
  test interfaces for the GUI. **Zero osascript / AppleScript / `tell
  application "System Events"`** anywhere under `Tests/`, `scripts/`,
  or `Sources/` (other than the linter scripts themselves which mention
  the banned patterns to ban them). The lint checks this too.
- `|| true` in a smoke that swallows a click failure is a lint-level
  defect: it lets coverage pass while clicks fall through. Forbidden.
- An e2e test that exits 0 without verifying observable state change is
  not a test. After a click, snapshot again and assert the new state.
- **A test that doesn't actually run is not a real test.** Writing the
  test file and watching the suite report "0 executed" because of a
  guard / env-var / `make` target you never invoke = the test does not
  exist. Every e2e suite must be runnable from a single command on the
  developer's machine, and that command must be invoked before the
  feature is considered done. Specifically:
    - Headless e2e (`HeadlessXxxTests`): must run by default in
      `swift test` / `make test`. If a test is gated behind an env-var
      that defaults off, the gate is wrong — make it run by default.
    - Headed e2e (`HeadedXxxTests`): gated behind `WDM_HEADED_E2E=1`,
      runnable via `make e2e-fullflow` (or a focused `make` target).
      The feature is not done until that target has been run AND the
      suite passed AND the developer (or AI) watched the visible
      window do the thing on the user's screen.
    - Any test that "passes" because the body early-returns on a
      missing env var is a hidden no-op. The skipped state must be
      visible — printed on stderr, counted separately, surfaced by the
      test runner — never silently green.
  "Wrote the test, didn't run it" violates the iron law just as hard
  as "wrote the code without a failing test first." Tests are not
  artifacts; they are evidence — and evidence you don't collect
  doesn't exist.

If a UI element exists, an e2e test for it must exist. If there is no
test, the element must not exist. There is no third option. The lint
explodes loudly when this is violated — that explosion is the desired
behaviour, not a problem to silence.

**Test rule (TDD + visibly-demonstrable e2e).** Every new UI feature
follows three steps in order, no exceptions:

1. **RED** — write the failing remote-driven e2e test FIRST. The test
   spawns `wdm-mac --remote --headless` (or attaches via the state file
   in headed mode), drives the feature through the remote API only
   (`/ui/snapshot`, `/ui/click`, `/ui/dispatch`), and asserts on the
   resulting state. No in-process shortcut. No view-model unit test as a
   substitute.
2. **GREEN** — write the minimum SwiftUI / Kit code to make the test
   pass. Every interactive element must declare a stable
   `.accessibilityIdentifier` so the AccessibilityWalker picks it up.
3. **DEMO** — the feature ships with a one-line `make` recipe (or
   commented `wdm-mac-control` pipeline at the bottom of the test) that
   reproduces the e2e flow on the developer's machine in front of the
   user. The user must be able to SEE it work — not just trust a green
   tick. The smoke output is part of the deliverable.

A UI feature without all three is not done. Same weight as the CLI iron
law. The agent-browser-style remote API (`snapshot` is JSON state,
`click @ref` mutates) is the SOLE acceptable test interface for the GUI.

**Render-layer rule (DRY).** GUI views are a *render layer* over
`WDMKit` — they hold presentation state only (selection, expanded panes,
hover targets). All business logic, validation, sequencing, IO, and
side effects live in `WDMController` ops. A view file that constructs a
`DisplayProvider`, opens a file, runs a process, or branches on
hardware quirks is a defect — push the logic into `WDMKit` and call it
from the view.

**Unix-CLI parity (non-negotiable).** Every GUI feature is also doable
from the unix shell via `wdm <verb>`. The order is always: (1) add the
Kit op, (2) wire the CLI verb, (3) wire the GUI control. If a GUI
needs to do something there's no `wdm` verb for, the Kit op is missing
— stop and add the verb first. The litmus test:

```sh
# every GUI interaction reproducible from a pipe, no exceptions
wdm <verb> ... | jq ... | wdm <other-verb> @-
```

If a GUI button has no shell-only equivalent, it's an SSOT violation
and the lib is incomplete.

### Frontend status

- **CLI (`wdm`) — primary, shipped.** All flow-of-business decisions are made
  with the CLI in mind first. New verbs land in the CLI before any other
  frontend. The unix-pipe contract is the contract.
- **Web (`wdm-web`) — proof of concept.** Demonstrates the lib is
  interface-agnostic. Not a shipped product. Runs locally, no auth, no TLS.
  Used to verify that "every CLI verb has a Kit op" because if it doesn't,
  the web frontend can't expose it.
- **GUI / Mac (future).** Will sit on the same Kit. Same SSOT rule applies.

If a verb works in the CLI but not in the web (or vice-versa), the lib is
under-specified. Fix the lib, then both frontends pick it up automatically.

### The drag-to-rearrange use case (worked example)

A live GUI that lets the user drag monitor tiles to rearrange them needs:
1. A real-time **read** of the current layout — origin + rotation per display.
2. A **bulk write** that applies many moves atomically when the gesture ends.

This is `wdm arrange` in the CLI, identical via `GET /arrangement` and
`POST /arrangement` in the web. Both are thin wrappers over
`WDMController.arrangement()` and `WDMController.setArrangement(_:confirmer:)`.

Pure unix-pipe demo (no GUI, no web — proves the lib's surface):

```sh
# Nudge every display 100 px right, atomically:
wdm arrange list --json \
  | jq '[.[] | .origin.x = .origin.x + 100]' \
  | wdm arrange set @- --no-confirm

# Read, modify, write — exactly what the future GUI will do.
```

If a future use case can't be expressed as `wdm <verb>` in the CLI, the lib
is missing an op. Add the Kit op first, then the CLI verb, then the other
frontends.

---

## UNIX style — non-negotiable

- **Stdout is data.** Suitable for piping. Default human-readable table; `--json` switches to machine-parseable JSON.
- **Stderr is for humans only.** Progress, errors, prompts. Never mix data into stderr.
- **Exit codes are meaningful** (see below). `0` = success, non-zero = failure with a specific code.
- **No colour unless stdout is a TTY.** Detect with `isatty(STDOUT_FILENO)`.
- **No interactive prompts unless stdin is a TTY.** When non-interactive, mutating commands require `--confirm` or `--no-confirm` explicitly; otherwise refuse and exit `2`.
- **Idempotent where possible.** `wdm main 2` on a system where display 2 is already main is a no-op success.
- **Composable.** Every read command supports `--json`. Every command names objects by stable identifiers (CGDirectDisplayID), with friendly aliases (`main`, `1`, `2`, …, EDID UUID).
- **One command, one job.** No mega-flags. Sub-commands compose.

### Exit codes

| Code | Meaning                                          |
|------|--------------------------------------------------|
| 0    | success                                          |
| 1    | generic failure                                  |
| 2    | usage error (bad args, missing required input)   |
| 3    | display not found                                |
| 4    | mode not supported by display                    |
| 5    | user cancelled / safe-transaction auto-reverted  |
| 6    | profile not found                                |
| 7    | I/O error (filesystem)                           |
| 8    | CoreGraphics / IOKit error                       |

---

## Safety — the fallback you asked for

Every mutating command (`mode`, `main`, `mirror`, `move`, `rotate`, `switch`, `cycle`, `restore`) goes through `CGBeginDisplayConfiguration` → … → `CGCompleteDisplayConfiguration(_, .forSession)`.

`.forSession` means: **if the user logs out or reboots, the change is gone.** Plus, before complete:

1. We snapshot the current configuration to `~/.config/wdm/snapshots/last.json` so `wdm restore last` always works.
2. After complete, we prompt according to the confirmation flag:
   - default → terminal prompt on stderr: `Press y in 15s to keep, anything else reverts:`
   - `--confirm` → native Mac popup with a live countdown (SPACE to keep, any other key to cancel, auto-revert at 0)
   - `--no-confirm` → no prompt, change kept
3. On timeout / `n` / Ctrl-C, we call `CGRestorePermanentDisplayConfiguration()` (which restores the persistent config) and exit `5`.
4. If the process is killed before confirmation, `.forSession` ensures the OS reverts on logout.

This is the macOS-native equivalent of the "your screen will revert in 15 seconds" dialog — but driven by us, scriptable, with sane non-interactive defaults.

---

## CLI surface

```
wdm list [--json]                       enumerate displays
wdm get <id|main> [field] [--json]      read one field
wdm modes <id> [--json]                 list available resolutions/refresh rates
wdm mode <id> <WxH@Hz> [--no-confirm|--confirm]   set display mode (safe-tx)
wdm main <id> [--no-confirm|--confirm]            set primary display (safe-tx)
wdm switch [--no-confirm|--confirm]               swap main between two displays (fast)
wdm cycle [--no-confirm|--confirm]                rotate main forward through all displays
wdm mirror <src> <dst> [--no-confirm|--confirm]   mirror src→dst (safe-tx)
wdm unmirror <id> [--no-confirm|--confirm]        break mirror (safe-tx)
wdm move <id> <x> <y> [--no-confirm|--confirm]    set arrangement origin (safe-tx)
wdm arrange list [--json]               real-time read of every display's origin + rotation
wdm arrange move <id> <x> <y> [<id> <x> <y> ...] [--no-confirm|--confirm]   bulk move
wdm arrange set @-|@<path> [--no-confirm|--confirm]   apply a JSON arrangement plan (drag-to-rearrange GUI hook)
wdm rotate <id> <0|90|180|270>          physical rotation
wdm flip <id> <none|horizontal|vertical|both> [--no-confirm|--confirm]  flip framebuffer (h, v, hv, off aliases)
wdm flip-overlay <id> <axis> [--duration-ms N]  software overlay flip (works on every Mac, incl. AirPlay)
wdm pip <src> [--on <dst>] [--size WxH] [--flip <axis>] [--duration-ms N]  movable picture-in-picture mirror
wdm doctor probe [<id>] [--json]        diagnose what wdm sees per display (mode, origin, main, rotation, mirror)
wdm doctor disconnect <id> [--duration-ms N]  soft-disconnect via CGDisplayCapture (public API)
wdm virtual create --name <s> [--mode WxH@Hz] [--hidpi]  create a virtual display (CGVirtualDisplay SPI)
wdm virtual list / remove <id>          enumerate / hint to kill the owning create process
wdm screenshot <id|main> --out <path>   PNG capture of any display (real or virtual)
wdm record <id|main> --out <path> --duration <sec>  H.264 .mov recording of any display
wdm profiles remove <name>              delete a saved profile (exits 6 if missing — never silent)
wdm sleep                               sleep the Mac immediately — drains AppleHPM before unplug (issue #1 workaround)
wdm save <name>                         snapshot to ~/.config/wdm/profiles/<name>.json
wdm restore <name> [--no-confirm|--confirm]       apply named profile (safe-tx)
wdm profiles [--json]                   list saved profiles
wdm brightness <id> [0.0..1.0]          read or set brightness (built-in only)
wdm watch [--json]                      stream display reconfiguration events
wdm version                             print version
```

Every one of these has an e2e test against a fixture before merge.

---

## Test commands

```
make test           swift test (hermetic, fixture backend)
make smoke          WDM_REAL_HARDWARE=1 read-only smoke against real displays
make build          swift build -c release
make install        copy .build/release/wdm to /usr/local/bin/
```

Build must be clean (zero warnings → `-warnings-as-errors`). Tests must be green. No skipped tests. No `@disabled` without an issue link in a comment.

---

## Hardware-specific limitations (intentional, documented)

- **Display names** come from `NSScreen.localizedName` (AppKit, public).
- **Brightness** uses the private `DisplayServices.framework` via `dlopen`/`dlsym`. Built-in displays support it; most external monitors return nil (DDC/CI control of external monitors is out of scope; use the monitor's OSD).
- **Rotate** uses `IOServiceRequestProbe` with `kIOFBSetTransform` against `IODisplayConnect`. This works on Intel Macs and any Apple Silicon Mac whose external displays expose an `IODisplayConnect` framebuffer. On Apple Silicon Macs without that service (most native MacBook Air/Pro built-ins), `wdm rotate` throws a clear error pointing the user to System Settings → Displays → Rotation. There is no public API for rotation on Apple Silicon; we do not ship a private fallback we can't verify.
- **Flip** uses the same `IOServiceRequestProbe` / `kIOFBSetTransform` pathway as rotate, OR-ing the `kIOScaleInvertX` / `kIOScaleInvertY` bits into the transform alongside the rotation-derived bits. Same Apple Silicon caveat: where `IODisplayConnect` is exposed, `wdm flip` works for that display; where it isn't, `wdm flip` refuses with a clear error and exit 8. AirPlay / Sidecar virtual displays do not expose framebuffer transforms via IOKit and are not supported (no public API exists for them).

When you add a new feature that depends on a private framework or an Apple Silicon-only path, follow the same rule: probe at runtime, throw a clear user-facing error if unsupported, and the e2e test asserts both branches.

---

## Dependencies policy

- **Runtime:** only Apple's `swift-argument-parser`. Nothing else. CoreGraphics and IOKit are system frameworks, not deps.
- **Test:** `swift-testing` (built in to Swift 6). Nothing else.
- **Build:** Swift 6.3+, macOS 13+ (we target macOS 13 for compatibility, even though we develop on 26).

If you're tempted to add a dep, you're solving the wrong problem.

---

## Repository

- **Visibility:** private (Arthur-Ficial/workshop-display-manager).
- **License:** proprietary, all rights reserved (`LICENSE`).
- **CI:** none yet — local `make test` is the gate.

---

## Definition of done (per feature)

- [ ] Failing test written first
- [ ] Test fails with the expected reason
- [ ] Minimal implementation written
- [ ] Test passes
- [ ] All other tests still pass (`swift test` green)
- [ ] Build clean (`swift build -c release`, zero warnings)
- [ ] E2E test exists and runs in `swift test` (no env vars, no real hardware)
- [ ] CLAUDE.md / README still accurate
- [ ] Committed with a single-purpose commit message

If any box is unchecked, the feature is not done.
