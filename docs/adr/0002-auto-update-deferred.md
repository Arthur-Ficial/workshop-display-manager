# ADR 0002 — Auto-update deferred to post-v1.0.0

**Status:** Accepted — 2026-05-05.
**Decided by:** Franz Enzenhofer (user).

## Context

After v1.0.0 ships, users need a way to update to v1.1.0+. The realistic options are:

- **A.** Manual updater via shell script (`scripts/wdm-update.sh`): downloads the latest GitHub release zip, replaces `/Applications/WDMMac.app`, re-launches. Plain bash. No runtime dependency.
- **B.** Sparkle framework: native macOS in-app updater. User opens a Settings → Updates pane, the app checks a feed, prompts, downloads, replaces itself. Industry-standard.
- **C.** Mac App Store: handled automatically. Already excluded — see ADR 0001.

CLAUDE.md "no third-party runtime deps" makes Sparkle expensive: it would need to be wrapped as a build-time-only generator or vendored. Either path adds maintenance.

## Decision

**v1.0.0 ships with the manual `wdm-update.sh` (Option A).** Sparkle (Option B) is on the post-v1.0.0 backlog; revisit when the user base outgrows running a shell command.

## Rationale

- Workshop facilitators are technical — running `bash <(curl …)` is acceptable.
- Sparkle's appcast.xml feed + signing key management is a maintenance tax for the early-version user base.
- The manual updater is 30 lines of shell. Easy to audit, easy to remove later when Sparkle lands.
- v1.0.0's ship gate is feature completeness + notarization, not auto-update polish.

## Consequences

- ✅ One less third-party dep, faster ship.
- ❌ Users who stop running `wdm-update.sh` will silently fall behind on releases. Mitigation: when the app starts, query GitHub's latest-release tag and surface a notification in the status bar if behind. Tracked in #126 (post-v1.0.0).
- 🔁 Migrating to Sparkle later is non-breaking — the manual `wdm-update.sh` keeps working alongside.

## References

- Sparkle: https://sparkle-project.org/
- `scripts/wdm-update.sh` — the v1.0.0 update mechanism.
