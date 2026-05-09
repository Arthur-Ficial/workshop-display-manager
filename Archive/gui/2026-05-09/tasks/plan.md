# Implementation Plan: Document the disabled headed-Settings test

> Generated 2026-05-05 by `/plan` against `SPEC.md`. Scope: pay down one CLAUDE.md violation honestly, with a real test and a real doc page.

## Overview

The wdm CLAUDE.md states: *"No `@disabled` without an issue link in a comment."* `Tests/WDMMacE2ETests/HeadedSettingsTests.swift:18` currently violates this rule — it carries a `@Test(.disabled("flaky under parallel test execution; re-enable once tests serialize"))` with prose context but no tracking link. Because Arthur-Ficial repos cannot use GitHub Issues (Actions quota exhausted, see `~/.claude/.../memory/feedback_no_github_actions.md`), the canonical tracking surface is an in-repo doc.

## Architecture Decisions

1. **In-repo flake registry, not GitHub Issues.** A `docs/known-flakes.md` file with one anchor per disabled test acts as the project's tracking system. Already aligns with `docs/known-issue-applehpm-panic.md` precedent.
2. **Annotation references doc anchor.** The `.disabled()` reason string ends with `(see docs/known-flakes.md#<anchor>)` — discoverable from grep, machine-checkable later.
3. **Test the rule, then enforce in code.** Per Iron Law, write a failing test first that scans `Tests/` for `@disabled` without a `docs/known-flakes.md` reference, then make it pass by adding the doc link.

## Dependency Graph

```
docs/known-flakes.md (new file)
    │
    └── Tests/WDMMacE2ETests/HeadedSettingsTests.swift  (annotation references the doc)
        │
        └── Tests/WDMCLITests/DisabledTestsHaveLinkTest.swift  (new — asserts the rule)
```

Bottom-up: write the failing test, then the doc, then the annotation update.

## Task List

### Phase 1: Foundation (RED)

- [ ] **Task 1: Failing test asserts every `.disabled` reason links to a `known-flakes.md` anchor**
  - Acceptance:
    - New test `DisabledTestsHaveLinkTest` lives under `Tests/WDMCLITests/`
    - Test scans every `Tests/**/*.swift` file for `@Test(.disabled(`
    - For each match, asserts the reason string contains `docs/known-flakes.md#`
    - Currently fails for `HeadedSettingsTests.swift:18` (1 violation)
  - Verify: `swift test --filter DisabledTestsHaveLinkTest` exits non-zero with the expected message
  - Files: `Tests/WDMCLITests/DisabledTestsHaveLinkTest.swift` (new)
  - Scope: XS (1 file)
  - Depends on: nothing

### Phase 2: Implementation (GREEN)

- [ ] **Task 2: Create `docs/known-flakes.md` with the headed-Settings entry**
  - Acceptance:
    - File documents what the flake is, why it's disabled, the unblock condition, and the manual repro
    - Anchor `#headed-settings-parallel` exists for the test to reference
    - Format mirrors the existing `docs/known-issue-applehpm-panic.md` style
  - Verify: `grep -q '^## ' docs/known-flakes.md` matches; file is valid markdown
  - Files: `docs/known-flakes.md` (new)
  - Scope: XS (1 file)
  - Depends on: Task 1

- [ ] **Task 3: Update the `.disabled(...)` reason string to reference the doc anchor**
  - Acceptance:
    - `Tests/WDMMacE2ETests/HeadedSettingsTests.swift:18` reason ends with `(see docs/known-flakes.md#headed-settings-parallel)`
    - Existing prose context preserved
    - `Tests/WDMCLITests/DisabledTestsHaveLinkTest.swift` now passes
  - Verify: `swift test --filter DisabledTestsHaveLinkTest` exits 0
  - Files: `Tests/WDMMacE2ETests/HeadedSettingsTests.swift`
  - Scope: XS (1 file)
  - Depends on: Tasks 1, 2

### Checkpoint: Foundation + Implementation
- [ ] `swift test` — full suite exits 0 (no regressions)
- [ ] `swift build -c release -Xswiftc -warnings-as-errors` — clean
- [ ] No new `@disabled` violations introduced
- [ ] Diff is ≤3 files, ≤80 lines net

### Phase 3: Review + Ship

- [ ] **Task 4: Five-axis review** (`/review`)
  - Verify: structured findings, no Critical issues
  - Scope: review-only

- [ ] **Task 5: Ship gate** (`/ship`)
  - Verify: GO with rollback plan (rollback = revert one commit)
  - Personas: code-reviewer, security-auditor, test-engineer in parallel
  - Scope: review-only

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Test scanner produces false positives on multi-line `.disabled(` calls | Med | Scan source text for the literal `.disabled(` and pull the next-line string content too; or require single-line annotation as the project convention |
| Doc anchor format clashes with another tool's expectation | Low | Use kebab-case anchors; mirror existing `docs/` precedent |
| Adding the test fails on macOS 13 (no Mac frontend dependency) | Low | Test lives under `WDMCLITests`, no SwiftUI imports — pure file scan |

## Open Questions

- None — every decision above is mechanical.
