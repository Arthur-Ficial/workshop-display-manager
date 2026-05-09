# Archived Mac GUI

Archived on 2026-05-09.

The active project is now the `wdm` Unix CLI and Swift library stack. This
folder preserves the previous Mac GUI work so it can be studied or revived
later without slowing or destabilizing the shipped CLI/lib surface.

## Contents

```text
Archive/gui/2026-05-09/
  Sources/
    WDMCore/             GUI-only pure helpers moved out of the active core.
    WDMMac/              SwiftUI/AppKit GUI library.
    WDMMacRemote/        Remote-control adapter and headed/headless runners.
    WDMRemoteControl/    HTTP/SSE remote-control protocol and server.
    wdm-mac/             GUI executable entrypoint.
    wdm-mac-control/     Companion control CLI.
  Tests/
    WDMCoreTests/        Tests for archived GUI-only pure helpers.
    WDMMacE2ETests/      Headed/headless GUI e2e tests.
    WDMMacRemoteTests/   Remote adapter tests.
    WDMRemoteControlTests/
  scripts/
    bundle-wdm-mac.sh
    generate-icon.sh
    lint-gui-parity.sh
    lint-icon-completeness.sh
    lint-liquid-glass*.sh
    lint-no-gui-logic.sh
    lint-remote-coverage.sh
    smoke-mac-remote.sh
    wdm-update.sh
    lib/wdm-mac.sh
  docs/
    superpowers/         AI-controllable GUI design docs.
    cli-only-verbs.md    Historical GUI parity allowlist.
    adr/                 GUI distribution and updater ADRs.
  examples/
    LiquidGlassReference/
  tasks/
    *.md                 Historical GUI task plans/specs.
```

## Status

This code is not referenced by `Package.swift`. It is not built by `make build`,
`make release`, `make test`, or `swift test`.

The archive lint, [`scripts/lint-gui-archived.sh`](../../../scripts/lint-gui-archived.sh),
keeps GUI products, targets, source directories, and tests out of the active
package. If the GUI is revived, it should return as a separate, testable change
after the CLI/lib gate remains green.

## Restore Notes

To revive the GUI, copy or move the relevant folders back into active `Sources/`
and `Tests/`, then re-add the SwiftPM products and targets in `Package.swift`.
Do this with a fresh failing test or lint first. The archived code may be stale;
do not assume it still builds against the current library surface.
