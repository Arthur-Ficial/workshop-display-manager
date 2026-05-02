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
                Mode, DisplayInfo, Profile, Snapshot, parsers, formatters, JSON codec.
  WDMSystem/    DisplayProvider protocol + two implementations:
                  - CGDisplayProvider (real, CoreGraphics + IOKit)
                  - FixtureDisplayProvider (reads/writes a JSON fixture for tests)
                Factory: DisplayProviderFactory.make() honours WDM_TEST_FIXTURE.
  WDMCLI/       Command parsing (swift-argument-parser), dispatch, output formatters.
                Each subcommand is its own type. No subcommand calls CoreGraphics directly —
                always through DisplayProvider.
  wdm/          Tiny executable: parses argv, calls WDMCLI.run(), translates errors to exit codes.

Tests/
  WDMCoreTests/    Pure unit tests for Core types.
  WDMSystemTests/  Tests for FixtureDisplayProvider behaviour (round-trip, error paths).
  WDMCLITests/     E2E: spawn the built binary with WDM_TEST_FIXTURE and assert.
```

**Layering rule:** dependencies only point downward. `WDMCore` knows nothing of `WDMSystem` or `WDMCLI`. `WDMSystem` depends on `WDMCore`. `WDMCLI` depends on both. `wdm` depends on `WDMCLI`.

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
wdm rotate <id> <0|90|180|270>          physical rotation
wdm flip <id> <none|horizontal|vertical|both> [--no-confirm|--confirm]  flip framebuffer (h, v, hv, off aliases)
wdm flip-overlay <id> <axis> [--duration-ms N]  software overlay flip (works on every Mac, incl. AirPlay)
wdm pip <src> [--on <dst>] [--size WxH] [--flip <axis>] [--duration-ms N]  movable picture-in-picture mirror
wdm doctor probe [<id>] [--json]        diagnose what wdm sees per display (mode, origin, main, rotation, mirror)
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
