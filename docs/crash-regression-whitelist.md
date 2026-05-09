# Crash-regression whitelist

`scripts/lint-crash-regression.sh` flags known crash-generating patterns. Lines listed here are reviewed and accepted as safe in their context. Format: `<path>:<line> <pattern>` — the lint matches the full grep-style entry.

## Activation-policy switches (reviewed and scoped)

The following `setActivationPolicy(.accessory)` calls have been individually reviewed and confirmed scoped (each restores the original policy in a `defer` or `teardown` block). The lint reads only the backtick-quoted `<path>:<line>` tokens below:

- `Sources/WDMSystem/NativeStreamer.swift:60` — recording session; restored at session end.
- `Sources/WDMSystem/CGVirtualDisplayManager.swift:121` — virtual-display CLI command holds the activation policy for the duration of the run loop; restored on stop().
- `Sources/WDMSystem/CGVirtualDisplayManager.swift:126` — same flow.
- `Sources/WDMKit/Safety/NativePopupConfirmer.swift:40` — popup confirmer; restored when the popup closes.

## SIG_IGN handlers — temporary

Following the same hygiene as commit 61d307e (which removed SIG_IGN from `AppKitOverlayFlipper`), these CLI-side signal traps should be migrated to `DispatchSourceSignal`. Tracked as a follow-up; whitelisted now to keep the lint enforced for new code.

- `Sources/WDMCLI/Commands/DoctorCommand.swift:82` — SIGINT handler in `wdm doctor disconnect` foreground loop.
- `Sources/WDMCLI/Commands/DoctorCommand.swift:83` — SIGTERM handler.
- `Sources/WDMCLI/Commands/DoctorCommand.swift:84` — SIGHUP handler.

## How the lint reads this file

It doesn't — yet. This file is a human review log. To make it lint-readable, list each whitelisted `<file>:<line>:<pattern>` exactly as printed by the lint. M4 keeps the reviewing manual; later milestones can wire up parsing.

For now the lint is **soft on activation-policy switches** until M5b (which refactors the popup confirmer) — see the WDM_LINT_CRASH_REGRESSION_STRICT envvar gate in the script.
