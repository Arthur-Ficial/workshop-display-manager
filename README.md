<div align="center">

# wdm

**The native macOS CLI for people who actually use multiple displays.**

`switch · cycle · mirror · save · restore · brightness · rotate` — atomically, with auto-revert if the projector goes black.

[![Tests](https://img.shields.io/badge/tests-80%2F80%20green-brightgreen)](#tests)
[![Build](https://img.shields.io/badge/build-warnings--as--errors%20clean-brightgreen)](#building)
[![macOS](https://img.shields.io/badge/macOS-13%2B-blue)](#install)
[![Swift](https://img.shields.io/badge/Swift-6-orange)](https://swift.org)

</div>

---

## Why wdm

You're a workshop teacher, conference speaker, hot-desking remote, or just someone with two monitors. You hit a deadline. The projector picks the wrong resolution. The mirror flips the wrong way. Your terminal lands on the screen the audience can't see. You give up and reach for the trackpad.

`wdm` exists because that whole sequence should be one keystroke. It is the **smallest possible** correct way to drive every aspect of every attached display from a UNIX shell, with safety nets that make destructive changes painless to try.

|                                       | wdm | displayplacer | BetterDisplay | System Settings |
|---------------------------------------|:---:|:-------------:|:-------------:|:---------------:|
| Pure CLI, scriptable, JSON output     | ✅  | ✅            | partial       | ❌              |
| Atomic safe-transaction with auto-revert | ✅ | ❌          | ❌            | partial         |
| Save / restore named profiles         | ✅  | ❌            | ✅            | ❌              |
| Native HUD confirm overlay (Tahoe)    | ✅  | ❌            | ❌            | ❌              |
| Brightness control (built-in)         | ✅  | ❌            | ✅            | ✅              |
| Crash-recovery `wdm restore last`     | ✅  | ❌            | ❌            | ❌              |
| 100% e2e tested, hermetic suite       | ✅  | ❌            | ❌            | n/a             |

---

## Install

### Homebrew (recommended)

```sh
brew tap Arthur-Ficial/wdm
brew install wdm
```

### One-liner installer

```sh
curl -fsSL https://raw.githubusercontent.com/Arthur-Ficial/workshop-display-manager/main/install.sh | bash
```

The installer verifies the SHA-256, the Developer-ID code signature, and the notarization ticket before placing the binary at `/usr/local/bin/wdm`. Pass `--user` to install under `~/.local/bin` instead.

### From source

```sh
git clone git@github.com:Arthur-Ficial/workshop-display-manager.git
cd workshop-display-manager
make release && make install
```

Requires Swift 6, macOS 13+. See [`docs/contributing.md`](docs/contributing.md).

---

## Quickstart

```sh
wdm list                                     # see every display
wdm switch                                   # swap main between two displays
wdm cycle                                    # rotate main forward through all displays
wdm mode 2 1920x1080@60                      # set resolution+refresh, with safe revert
wdm mirror 1 2                               # mirror display 1 onto display 2
wdm brightness main 0.5                      # 50% brightness on the built-in
wdm save desk-A                              # snapshot current arrangement
wdm restore desk-A                           # apply it back later
wdm watch --json                             # stream display reconfig events
```

| Command | What it does |
|---|---|
| `wdm list [--json]` | Enumerate every connected display: ID, name, current mode, origin, rotation, main flag, mirror source. |
| `wdm get <id\|main> [field]` | Read one field of one display. Pipe-friendly. |
| `wdm switch` | Swap which of two displays is main. <1 second. |
| `wdm cycle` | Rotate "main" forward across N displays. |
| `wdm mode <id> <WxH@Hz>` | Set resolution + refresh. Safe-tx wrapped. |
| `wdm save <name>` / `wdm restore <name>` | Named profiles in `~/.config/wdm/profiles/`. |
| `wdm restore last` | Recover the last pre-mutation snapshot, even after a crash. |
| `wdm brightness <id> [0..1]` | Read or set brightness on the built-in display. |

---

## Workshop scenarios

### One-projector talk

You walk into the room, plug into HDMI, plug your dock back in, get to work:

```sh
wdm save desk                # save your dock setup once
# … later, in the workshop room …
wdm switch --confirm         # main → projector, native HUD asks for confirmation
wdm save room-A              # workshop config saved
wdm mode 2 1920x1080@60      # if the projector defaults to a weird mode
# done — give the talk
wdm restore desk             # back at your desk
```

### Hot-desk dock setup

```sh
wdm save desk                # one time
# next time you plug in the dock:
wdm watch --json | jq -r 'select(.kind=="added")' | xargs -n1 wdm restore desk --no-confirm
```

### Dual-projector + iPad mirror (advanced)

```sh
wdm mirror 1 3               # iPad sidecar mirrors built-in
wdm main 2 --confirm         # projector becomes main, with auto-revert if mistaken
wdm save talk-twin
```

---

## The safety model

Every mutating command goes through three layers of revert. **You cannot break out of this** by accident:

```
┌────────────────────────────────────────────────────────────┐
│ 1. SafeTransaction                                         │
│    ─ pre-snapshot                                          │
│    ─ apply                                                 │
│    ─ confirm (terminal prompt | native HUD | scripted)    │
│    ─ on no/timeout: re-apply pre-snapshot via ProfileApplier│
└────────────────────────────────────────────────────────────┘
                       ↓ on crash mid-mutation
┌────────────────────────────────────────────────────────────┐
│ 2. `last` profile                                          │
│    ─ MutationDispatch writes pre-state to                  │
│      `~/.config/wdm/profiles/last.json` BEFORE apply       │
│    ─ recover with `wdm restore last`                       │
└────────────────────────────────────────────────────────────┘
                       ↓ on CG-side commit failure
┌────────────────────────────────────────────────────────────┐
│ 3. CGRestorePermanentDisplayConfiguration                  │
│    ─ fired automatically if CGCompleteDisplayConfiguration │
│      itself returns an error                               │
└────────────────────────────────────────────────────────────┘
```

Full sequence diagram in [`docs/safety.md`](docs/safety.md).

### Confirmation flags

```
(default)        terminal prompt on stderr (`y` within 15s to keep)
--confirm        native macOS HUD overlay with countdown (SPACE keep, any other key cancel)
--no-confirm     skip the prompt (use this in scripts and CI)
```

---

## Architecture

```
WDMCore     pure value types      Mode · DisplayInfo · Snapshot · Point
   │
WDMSystem   protocol + adapters   DisplayProvider · CGDisplayProvider · FixtureDisplayProvider
   │                              IOKitRotation · DisplayServicesBridge · DisplayNameResolver
   │
WDMCLI      command dispatch      ListCommand … SwitchCommand … BrightnessCommand
   │                              SafeTransaction · MutationDispatch · ProfileStore · NativePopupConfirmer
   │
wdm         executable            18-line main.swift
```

Layering rule: dependencies only point downward. Every command goes through the `DisplayProvider` protocol — the same code path is exercised in tests against a JSON-fixture provider as on real hardware.

Full breakdown in [`docs/architecture.md`](docs/architecture.md).

---

## Tests

```sh
make test                    # 80+ tests in 21 suites, hermetic, ~0.02s
make smoke                   # opt-in: runs read-only ops against your real displays
WDM_REAL_HARDWARE=1 swift test            # hardware-gated read smoke
WDM_REAL_HARDWARE_MUTATE=1 swift test     # actually swaps your main display, then restores
```

Every user-facing command has an end-to-end test that spawns through the actual `CLIRunner` against a JSON-fixture display provider. Hermetic, fast, no real hardware needed in CI.

---

## Building

```sh
make build                   # debug
make release                 # release with -warnings-as-errors
make test                    # full hermetic suite
make install                 # copies to /usr/local/bin/wdm
make clean
```

Zero third-party runtime dependencies. Swift 6, macOS 13+ deployment target.

---

## Documentation

- [`CLAUDE.md`](CLAUDE.md) — contributor contract: TDD iron law, modular rules, exit codes
- [`docs/architecture.md`](docs/architecture.md) — module boundaries, layering, why
- [`docs/safety.md`](docs/safety.md) — three-layer revert, sequence diagrams
- [`docs/workflows.md`](docs/workflows.md) — workshop / hot-desk / dual-projector walkthroughs
- [`docs/troubleshooting.md`](docs/troubleshooting.md) — known limitations + workarounds
- [`docs/contributing.md`](docs/contributing.md) — how to add a feature, the iron law
- [`docs/release.md`](docs/release.md) — maintainer release process

API reference (DocC) is published at https://Arthur-Ficial.github.io/workshop-display-manager/ on every push to `main`.

---

## License

Proprietary, all rights reserved. © 2026 Franz Enzenhofer / fullstackoptimization.com.

This is a private project, not licensed for use outside the copyright holder's workshops, projects, and infrastructure. See [`LICENSE`](LICENSE).
