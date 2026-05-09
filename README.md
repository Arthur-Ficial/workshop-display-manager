<div align="center">

# wdm

**Workshop Display Manager: a native macOS Unix CLI and Swift library for managing attached displays.**

`wdm` is the source of truth. The active package is now the CLI, core library, effects layer, typed controller facade, and local web proof of concept. The old Mac GUI has been archived under [`Archive/gui/2026-05-09`](Archive/gui/2026-05-09/README.md) and is not part of the active SwiftPM build.

</div>

---

## What It Does

`wdm` lets a workshop facilitator script display setup without opening System Settings:

```sh
wdm list --json
wdm arrange list --json
wdm arrange move 1 0 0 2 2560 0 --no-confirm
wdm main 2 --no-confirm
wdm mirror 1 2 --no-confirm
wdm mode 2 1920x1080@60 --no-confirm
wdm rotate 2 90 --no-confirm
wdm brightness main 0.5
wdm save room-a
wdm restore room-a --no-confirm
wdm save --auto
wdm daemon --max-events 1
```

Every mutating command uses the same safe transaction path: read the current state, apply the requested change, verify through the display provider, and expose a meaningful exit code when the real system call refuses.

## Current Scope

Active:

- `wdm`: the shipped Unix CLI.
- `WDMCore`: pure values, parsers, JSON shapes, and formatting helpers.
- `WDMSystem`: real macOS effects plus fixture/recording implementations for tests.
- `WDMKit`: the single typed API for every operation.
- `WDMCLI`: thin argv/stdout/stderr/exit-code wrapper.
- `wdm-web` / `WDMWeb`: local proof of concept proving the library is frontend-agnostic.

Archived:

- `WDMMac`, `WDMMacRemote`, `WDMRemoteControl`, `wdm-mac`, `wdm-mac-control`.
- Their GUI e2e/unit tests, Liquid Glass scripts, remote-control scripts, and design docs.
- Archive location: [`Archive/gui/2026-05-09`](Archive/gui/2026-05-09/README.md).

The archive is preserved for reference only. It is intentionally outside `Package.swift`, `make test`, and the default release build.

## Install

From source:

```sh
git clone git@github.com:Arthur-Ficial/workshop-display-manager.git
cd workshop-display-manager
make release
make install
```

Default install path is `/usr/local/bin/wdm`. Override with `PREFIX=/path make install`.

Requirements:

- macOS 13 or newer.
- Swift 6 toolchain.
- No third-party runtime dependencies.

## Quickstart

Read state:

```sh
wdm list
wdm list --json
wdm get main name
wdm modes main
wdm arrange list --json
wdm doctor probe
```

Mutate safely:

```sh
wdm main 2 --no-confirm
wdm arrange move 1 0 0 2 2560 0 --no-confirm
wdm mode 2 1920x1080@60 --no-confirm
wdm rotate 2 0 --no-confirm
wdm mirror 1 2 --no-confirm
wdm restore last --no-confirm
```

Compose like a Unix tool:

```sh
wdm arrange list --json \
  | jq '[.[] | .origin.x = .origin.x + 100]' \
  | wdm arrange set @- --no-confirm
```

## Command Surface

| Command | Purpose |
|---|---|
| `list`, `get`, `modes` | Read display state and supported modes. |
| `arrange list`, `arrange move`, `arrange set` | Read or atomically apply display origins and rotations. |
| `main`, `mode`, `move`, `rotate`, `mirror`, `switch`, `cycle` | Mutate the active display configuration. |
| `save`, `restore`, `profiles`, `scene`, `workshop` | Save and replay named display setups. |
| `brightness`, `ddc`, `hdr`, `scale`, `rename`, `edid` | Hardware and identity utilities with honest unsupported-path errors. |
| `flip`, `flip-overlay`, `pip`, `panorama` | Presentation helpers. |
| `screenshot`, `shot-all`, `record`, `stream` | Capture and streaming tools. |
| `virtual` | Create/remove process-bound virtual displays where macOS supports the SPI. |
| `watch`, `daemon`, `hotkeys`, `bind` | Event and automation surfaces. |
| `doctor`, `sleep`, `focus`, `follow`, `move-window`, `screen-windows`, `tile-app` | Diagnostics, safety, and window placement helpers. |

## Architecture

The active package has strict downward dependencies:

```text
Sources/
  WDMCore/              Pure value types and pure functions.
  CGVirtualDisplaySPI/  Header bridge for Apple's virtual display SPI.
  WDMSystem/            Effects layer: CoreGraphics, IOKit, ScreenCaptureKit, fixtures.
  WDMKit/               Typed facade. WDMController is the single source of truth.
  WDMCLI/               Thin CLI frontend: argv -> WDMKit -> stdout/stderr/exit.
  WDMWeb/               Thin local HTTP proof of concept: JSON -> WDMKit -> JSON.
  wdm/                  Tiny executable wrapper for WDMCLI.
  wdm-web/              Tiny executable wrapper for WDMWeb.

Tests/
  WDMCoreTests/         Pure and lint tests.
  WDMSystemTests/       Effects and fixture-provider tests.
  WDMKitTests/          Controller-level tests against fixtures.
  WDMCLITests/          E2E tests spawning the actual wdm binary.
  WDMWebTests/          Local HTTP smoke tests.

Archive/
  gui/2026-05-09/       Retired Mac GUI code, tests, scripts, docs.
```

Rules:

- `WDMCore` has no I/O.
- `WDMSystem` owns effects.
- `WDMKit` owns business logic and typed errors.
- `WDMCLI` and `WDMWeb` parse/present only.
- Frontends do not call providers directly.
- Every CLI verb has an e2e test that spawns the actual binary with `WDM_TEST_FIXTURE`.

## Build And Test

```sh
make build       # debug wdm
make release     # release wdm with warnings as errors
make test        # active CLI/lib/web gate
make perf-cli    # fixture-backed release CLI latency gate
make smoke       # opt-in real-hardware read smoke
```

`make test` runs:

- GUI archive lint.
- CLI boundary lint.
- every-verb e2e coverage lint.
- no-fakes, modularity, naming, crash, rendering lints.
- `WDMCoreTests`, `WDMSystemTests`, `WDMKitTests`, `WDMCLITests`, `WDMWebTests`.

The CLI e2e harness runs `.build/debug/wdm` as a subprocess and sets `WDM_TEST_FIXTURE` to a per-test JSON fixture. Tests assert stdout, stderr, exit code, and post-state for mutating commands.

## Exit Codes

| Code | Meaning |
|---:|---|
| `0` | Success. |
| `1` | Generic failure. |
| `2` | Usage error. |
| `3` | Display not found. |
| `4` | Mode or feature unsupported. |
| `5` | User cancelled or safe transaction reverted. |
| `6` | Profile not found. |
| `7` | Filesystem I/O error. |
| `8` | CoreGraphics / IOKit error. |

## Documentation

- [`docs/architecture.md`](docs/architecture.md)
- [`docs/safety.md`](docs/safety.md)
- [`docs/workflows.md`](docs/workflows.md)
- [`docs/troubleshooting.md`](docs/troubleshooting.md)
- [`docs/contributing.md`](docs/contributing.md)
- [`docs/release.md`](docs/release.md)
- [`Archive/gui/2026-05-09/README.md`](Archive/gui/2026-05-09/README.md)

## License

Proprietary, all rights reserved. Copyright 2026 Franz Enzenhofer / fullstackoptimization.com.

This repository is not licensed for use outside the copyright holder's workshops, projects, and infrastructure. See [`LICENSE`](LICENSE).
