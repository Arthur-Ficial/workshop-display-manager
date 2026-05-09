# Spec: wdm — Workshop Display Manager

`wdm` is a native macOS Unix CLI and Swift library for managing attached
displays. The active repository scope is CLI/lib/web. The retired Mac GUI is
archived under `Archive/gui/2026-05-09`.

## Objective

Give workshop facilitators a scriptable, hermetic-testable way to read and
mutate display configuration: modes, arrangement, mirroring, rotation, flipping,
picture-in-picture, virtual displays, screenshot/record/stream, brightness,
auto-restore, and diagnostics.

## Active Products

- `wdm`: primary CLI.
- `WDMCore`: pure values and parsers.
- `WDMSystem`: macOS effects, fixtures, and recording implementations.
- `WDMKit`: typed controller facade and single source of truth.
- `WDMCLI`: thin command frontend.
- `wdm-web` / `WDMWeb`: local HTTP proof of concept.

## Archived Products

- `WDMMac`
- `WDMMacRemote`
- `WDMRemoteControl`
- `wdm-mac`
- `wdm-mac-control`

Archive location: `Archive/gui/2026-05-09`.

## Commands

```sh
make build
make release
make test
make perf-cli
make smoke
make install
```

## Project Structure

```text
Sources/
  WDMCore/
  CGVirtualDisplaySPI/
  WDMSystem/
  WDMKit/
  WDMCLI/
  WDMWeb/
  wdm/
  wdm-web/

Tests/
  WDMCoreTests/
  WDMSystemTests/
  WDMKitTests/
  WDMCLITests/
  WDMWebTests/

Archive/
  gui/2026-05-09/
```

## Gates

- `make test` must pass.
- `make perf-cli` must pass.
- Every CLI verb has a subprocess e2e test under `Tests/WDMCLITests`.
- GUI code must remain archived outside the active SwiftPM package.
- Real hardware tests are opt-in and never replace fixture-backed e2e coverage.
