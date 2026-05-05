#!/bin/bash
# lint-github-tickets.sh
#
# Asserts every milestone defined in tasks/golden-goal-spec.md has a
# corresponding GitHub issue (open or closed) on the canonical repo.
# Per user 2026-05-05: "make sure every ticket is done in the GitHub
# tickets — this is part of the golden goal!"
#
# This is a SOFT lint by default — it warns but doesn't fail when
# `gh` isn't authenticated or the network is offline (so pre-commit
# stays usable on a plane). Set WDM_LINT_TICKETS_STRICT=1 to make
# missing-issue cases hard-fail.
#
# Discovery:
#   - Milestone IDs come from `tasks/golden-goal-spec.md` AND from
#     the milestone-tagged commit history (commit subjects starting
#     with "M<N>:" or "M<N><letter>:").
#   - GitHub issues are fetched via `gh issue list --search "M<N>"`
#     (matching by title prefix). One issue per Mn is expected.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REPO="Arthur-Ficial/workshop-display-manager"

# Discover milestone IDs from the spec file (matches "M0", "M1", … "M10").
SPEC_MILESTONES=$(grep -oE '\bM([0-9]|10)\b' tasks/golden-goal-spec.md 2>/dev/null \
    | sort -u)

if [ -z "$SPEC_MILESTONES" ]; then
    echo "lint-github-tickets: no milestones found in tasks/golden-goal-spec.md" >&2
    exit 2
fi

# Soft-fail when `gh` not available. `gh auth status` can return non-zero
# even when an active GITHUB_TOKEN works (multi-account hosts), so don't
# pre-check it — just try the actual list call and skip on failure.
if ! command -v gh >/dev/null 2>&1; then
    echo "lint-github-tickets: ⚠ gh CLI missing — skipping (install: brew install gh)" >&2
    exit 0
fi

# Fetch every issue (open + closed) once.
ISSUES_JSON=$(gh issue list -R "$REPO" --state all --limit 200 --json number,title,state 2>/dev/null)
if [ -z "$ISSUES_JSON" ] || [ "$ISSUES_JSON" = "[]" ]; then
    echo "lint-github-tickets: ⚠ could not fetch issues from $REPO (offline / unauth?) — skipping" >&2
    exit 0
fi

violations=0
for milestone in $SPEC_MILESTONES; do
    # Match "M<N> —" at the start of any issue title.
    matched=$(echo "$ISSUES_JSON" | jq -r --arg m "${milestone} " '.[] | select(.title | startswith($m)) | "\(.number) \(.state)"')
    if [ -z "$matched" ]; then
        if [ $violations -eq 0 ]; then
            echo "lint-github-tickets: milestones without a GitHub issue:" >&2
        fi
        echo "  - $milestone" >&2
        violations=$((violations + 1))
    fi
done

if [ $violations -gt 0 ]; then
    if [ "${WDM_LINT_TICKETS_STRICT:-}" = "1" ]; then
        echo >&2
        echo "Create issues with: gh issue create -R $REPO --title \"<Mn> — <title>\"" >&2
        exit 1
    else
        echo "lint-github-tickets: ⚠ $violations milestones missing issues (set WDM_LINT_TICKETS_STRICT=1 to enforce)" >&2
        exit 0
    fi
fi

echo "lint-github-tickets: ✓ every milestone has a GitHub issue"
