# Architecture

`wdm` is intentionally tiny. The whole binary fits in four modules with strict downward dependencies. This document explains why each module exists and what lives where.

```
        ┌───────────────────────────────┐
        │ wdm  (executable, 6 lines)    │
        │   parses argv → CLIRunner.run │
        └───────────────┬───────────────┘
                        │
        ┌───────────────▼───────────────┐
        │ WDMCLI                        │
        │   • CLIRunner (top-level)     │
        │   • Commands/* (one per verb) │
        │   • Safety/SafeTransaction    │
        │   • Profiles/ProfileStore     │
        │   • Format/* (JSON, table)    │
        │   • Output/* (writers)        │
        └───────────────┬───────────────┘
                        │
        ┌───────────────▼───────────────┐
        │ WDMSystem                     │
        │   • DisplayProvider (protocol)│
        │   • CGDisplayProvider (real)  │
        │   • FixtureDisplayProvider    │
        │   • IOKitRotation             │
        │   • DisplayServicesBridge     │
        │   • DisplayNameResolver       │
        └───────────────┬───────────────┘
                        │
        ┌───────────────▼───────────────┐
        │ WDMCore                       │
        │   • Mode, Point               │
        │   • DisplayInfo, Snapshot     │
        │   • Pure parsers/formatters   │
        └───────────────────────────────┘
```

## Layering rule

**Dependencies point downward only.**

- `WDMCore` knows nothing about the system. It is value types and pure functions. No `import AppKit`, no `import CoreGraphics`. It exists so unit tests for parsing, formatting, and JSON round-trip never need a display.
- `WDMSystem` adapts `WDMCore` to real hardware. It defines the `DisplayProvider` protocol and ships two implementations: `CGDisplayProvider` (CoreGraphics + IOKit + DisplayServices) and `FixtureDisplayProvider` (reads/writes a JSON fixture file). Any future backend implements the same protocol.
- `WDMCLI` consumes `WDMSystem` only through the protocol. Commands never call CoreGraphics directly. This is why the e2e tests can spawn the entire CLI against the fixture and exercise 100% of the user-facing logic without touching real displays.
- `wdm` is six lines: parse argv, build the writers, call `CLIRunner.run`, exit.

## Why protocols, not concretes

`DisplayProvider.swift` is the spine. Every mutating verb takes a `DisplayProvider` and an `ApplyOptions`, and returns an `ApplyResult`. Tests pass a `FixtureDisplayProvider`. Production passes a `CGDisplayProvider`. Adding a third backend (e.g. a remote-control display server) means writing one file.

Likewise `Confirmer.swift`. Three implementations: `StdinConfirmer` (terminal prompt), `NativePopupConfirmer` (Tahoe HUD overlay), `AutoYesConfirmer` / `AutoNoConfirmer` (tests). The selection is made in `CLIRunner` based on flags + env, and the chosen one is passed via `CLIDeps`.

## Modular constraints

These are enforced by review, not tooling — but they shape every change.

- One public type per file. File name matches the type name.
- Files ≤ 150 lines. Functions ≤ 30 lines. If you exceed, the boundary is wrong; split it.
- Default to `internal`. `public` is a promise.
- No singletons. No `static var shared` (one exception: `KeyBoxStash` for the C event-tap callback, where we have no other choice).
- Effects at the edges: I/O, CoreGraphics, the filesystem live in `WDMSystem`. Logic in `WDMCore` is effect-free.

## Where to put a new feature

| Feature kind | Goes in |
|---|---|
| Pure type / parser / formatter | `WDMCore` |
| New CG/IOKit interaction | `WDMSystem` (extend `DisplayProvider` if visible to commands) |
| New verb (e.g. `wdm watch`) | `WDMCLI/Commands/` + a registry entry in `CLIRunner.swift` |
| New confirmer kind | `WDMCLI/Safety/` |
| New output format | `WDMCLI/Format/` |

Always add the test first. See [`contributing.md`](contributing.md).
