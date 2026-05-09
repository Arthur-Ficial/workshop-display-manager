# ADR 0001 — Developer ID + notarization, not Mac App Store

**Status:** Accepted — 2026-05-05.
**Decided by:** Franz Enzenhofer (user).

## Context

`wdm` and `WDMMac.app` need a public-distribution path. The two realistic options on macOS are:

- **A.** Developer ID + notarization. User downloads a signed/stapled `.app`, drops it into `/Applications`. Gatekeeper accepts. No App Store, no review, no in-app payments.
- **B.** Mac App Store. Distributed through the MAS pipeline. Sandboxed by default. Subject to App Review and the MAS rules.

## Decision

We ship via **Developer ID + notarization (Option A) only.** The Mac App Store path is dropped from v1.0.0 scope and unlikely to be revisited.

## Rationale — why MAS is architecturally incompatible

`WDMMac.app` uses several APIs that MAS's sandbox + App Review explicitly forbid:

| Feature | API | MAS-blocking reason |
|---|---|---|
| Flip H / Flip V overlay | ScreenCaptureKit | Capture works in MAS, but our config requires `com.apple.security.cs.disable-library-validation` — sandbox forbids that entitlement |
| PiP window | ScreenCaptureKit + AppKit windowing | Same library-validation restriction |
| Virtual display creation | `CGVirtualDisplay` SPI | Private API — automatic MAS reject |
| Brightness on built-in display | `DisplayServices.framework` private symbols | Private API — MAS reject |
| Framebuffer rotate / flip | `IOServiceRequestProbe(kIOFBSetTransform)` | IOKit private interface — MAS reject |
| Record / screenshot of arbitrary displays | `CGDisplayCreateImage`, AVAssetWriter | Works, but `wdm shot-all` and `wdm record --background` would need to drop sandbox |

Disabling library-validation requires an entitlement (`com.apple.security.cs.disable-library-validation`) that the App Store explicitly disallows. Removing it would break `flip-overlay` and `pip` — the workshop facilitator's two highest-value features.

**Net:** at least 5 of the app's user-facing features cannot ship via MAS. A reduced MAS variant (basic mode/main/mirror only) would be a fork of the codebase indefinitely; we'd maintain two products. Not worth the upside.

## Consequences

- ✅ Full feature set ships unchanged.
- ✅ Releases are reproducible from a single tagged commit via `scripts/release.sh`.
- ❌ No App Store search / discovery. Users find us via GitHub or word-of-mouth.
- ❌ No App Store payment infrastructure. (Currently not relevant — wdm is free / private.)
- 🔁 If we ever want a "lite" version (read-only display info, no overlay, no virtual displays) for MAS, it would be a new sibling target `WDMMacAS` depending only on `WDMKit`. ~2 weeks of work; not on the v1.x roadmap.

## References

- Apple — App Sandbox Capabilities for the App Store: https://developer.apple.com/documentation/security/app_sandbox/
- Apple — Hardened Runtime entitlements that MAS forbids: https://developer.apple.com/documentation/security/hardened_runtime/
- Plan file: `/Users/arthurficial/.claude/plans/ok-i-want-you-generic-narwhal.md` § Plan A vs Plan B.
