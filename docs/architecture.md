# Architecture

`wdm` is intentionally tiny. The codebase is five layers with strict downward
dependencies. The CLI (`wdm`) is the primary frontend; a local web server
(`wdm-web`) ships as a proof of concept that the lib is interface-agnostic.
A future Mac GUI sits as a sibling on the same lib.

```
   ┌───────────────────────────────┐    ┌────────────────────────────────┐
   │ wdm (executable)              │    │ wdm-web (executable, PoC)      │
   │   parses argv → CLIRunner.run │    │   parses argv → WDMWebMain.run │
   └───────────────┬───────────────┘    └───────────────┬────────────────┘
                   │                                    │
   ┌───────────────▼───────────────┐    ┌───────────────▼────────────────┐
   │ WDMCLI (thin frontend)        │    │ WDMWeb (thin frontend, PoC)    │
   │   • CLIRunner                 │    │   • WDMWebServer (NWListener)  │
   │   • Commands/* (one per verb) │    │   • Router + Routes            │
   │   • argv→Kit, exit codes      │    │   • Handlers/* (one per verb)  │
   │   • output formatting         │    │   • JSON in/out, HTTP status   │
   └───────────────┬───────────────┘    └───────────────┬────────────────┘
                   │                                    │
                   └───────────────┬────────────────────┘
                                   │
                   ┌───────────────▼───────────────┐
                   │ WDMKit (typed façade · SSOT)  │
                   │   • WDMController + Operations│
                   │   • SafeMutation, Confirmer   │
                   │   • Profile/Scene stores      │
                   │   • Provider factories        │
                   │   • WDMError (typed)          │
                   │   • Output writers, formatters│
                   └───────────────┬───────────────┘
                                   │
                   ┌───────────────▼───────────────┐
                   │ WDMSystem (effects)           │
                   │   • DisplayProvider (protocol)│
                   │   • CGDisplayProvider (real)  │
                   │   • FixtureDisplayProvider    │
                   │   • CursorIO, ProcessLister,  │
                   │     Screenshotter, Recorder,  │
                   │     PipFlipper, … (each w/    │
                   │     real + recording impl)    │
                   └───────────────┬───────────────┘
                                   │
                   ┌───────────────▼───────────────┐
                   │ WDMCore (pure)                │
                   │   • Mode, Point, Snapshot     │
                   │   • DisplayInfo, Profile      │
                   │   • ArrangementEntry          │
                   │   • parsers, formatters       │
                   └───────────────────────────────┘
```

## Layering rule

**Dependencies point downward only. Frontends are siblings; they never depend on each other.**

- `WDMCore` knows nothing about the system. Value types + pure functions. No `import AppKit`, no `import CoreGraphics`. Pure-function unit tests need no displays.
- `WDMSystem` adapts `WDMCore` to real hardware. Each side-effect category is a protocol with a real impl + a recording impl: `DisplayProvider`, `CursorIO`, `ProcessLister`/`ProcessSignaler`, `Screenshotter`, `Recorder`, `PipFlipper`, `OverlayFlipper`, `DisplayCapturer`, `VirtualDisplayManager`, `Sleeper`, `WindowMover`/`WindowLister`/`CursorTracker`, `DDCProvider`, `HDRProvider`, `HotkeyRegistrar`, `DisplayEventStream`. Recording impls let every Kit op be tested hermetically.
- `WDMKit` is the **single source of truth**. Every user-visible verb has exactly one `WDMController.<verb>` op. Frontends call it; never re-implement it. Knows nothing of argv, exit codes, stdin, FileHandle, HTTP, or window servers.
- `WDMCLI` consumes only `WDMKit`. Commands never call `WDMSystem` directly — they go through `deps.controller`. The CLI is responsible for argv parsing, stdout/stderr formatting, exit-code mapping, and signal handling for blocking commands.
- `WDMWeb` consumes only `WDMKit`. Same lib, different parser (HTTP/1.1) and presenter (JSON + HTTP status). **Never imports `WDMSystem`. Never imports `WDMCLI`.** Backed by Foundation `Network.framework`, no third-party dependencies.
- `wdm` is a six-line `main.swift`: parse argv, build writers, call `CLIRunner.run`, exit. `wdm-web` is a one-liner: `WDMWebMain.run()`.

## SSOT and the frontend contract

A frontend's job is parsing and presenting. The shape:

```
input  → frontend-specific parsing (argv / HTTP / GUI events / RPC)
       → typed Kit call (WDMController.<verb>(...))
       → typed Kit result (value / ApplyResult / typed throw)
       → frontend-specific output (stdout+exit code / JSON+HTTP status / GUI redraw / RPC reply)
```

If the same logic appears in two frontends, the extraction is incomplete. Push it into `Sources/WDMKit/Operations/`.

The `wdm arrange` verb is the canonical example: one Kit op (`WDMController.arrangement()` / `setArrangement(_:confirmer:)`), one CLI verb (`wdm arrange list / move / set @-`), one HTTP route pair (`GET/POST /arrangement`). All three round-trip the same JSON shape — a future Mac GUI subscribes to the same data via `WDMController.arrangement()` directly.

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
