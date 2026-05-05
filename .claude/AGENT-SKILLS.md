# Agent Skills (project-local install)

Source: https://github.com/addyosmani/agent-skills (MIT)
Installed: 2026-05-05 — files copied into this project's `.claude/`. **No global plugin install was performed.** This affects only this repo.

## What's here

- `commands/*.md` — 7 lifecycle slash commands (rewritten to point at the local skill paths instead of the `agent-skills:` plugin namespace)
- `skills/<name>/SKILL.md` — 21 skill workflow files
- `agents/*.md` — 3 specialist subagent definitions used by `/ship`

## Lifecycle workflow

```
/spec          → SPEC.md           (spec-driven-development)
/plan          → tasks/plan.md     (planning-and-task-breakdown)
/build         → implementation    (incremental-implementation + test-driven-development)
/test          → tests pass        (test-driven-development; bug fixes use Prove-It)
/review        → 5-axis review     (code-review-and-quality)
/ship          → GO / NO-GO        (shipping-and-launch — fan-out to code-reviewer, security-auditor, test-engineer)
/code-simplify → tighten the diff  (code-simplification)
```

## Notes specific to this repo

- The wdm CLAUDE.md iron law (TDD, real implementations, no fakes/fallbacks, ≤150-line files, ≤30-line functions) takes precedence over anything in these skills. Skills override the default system prompt; user instructions override skills (per superpowers' priority rules).
- `/build` and `/test` already align with wdm's existing red→green→refactor and 100% e2e rules — they're a more disciplined wrapper around what's already required, not a replacement.
- Hooks from the source repo (`hooks/sdd-cache-*.sh`, `hooks/session-start.sh`, etc.) were **not** installed. They mutate `.claude/settings.local.json` and are not needed for the workflow itself.

## Project-local stop-verify hook

`hooks/stop-verify.sh` is a project-local Stop hook that fires aggressively (every 30 seconds) instead of "once per chain" like the global `~/.claude/hooks/stop-verify.sh`. The 30-second debounce uses `/tmp/wdm-stop-verify-last-fire` to prevent infinite block-respond-block spirals.

**To activate** (per-developer; `.claude/settings.local.json` is gitignored):

Add a Stop hook entry to `.claude/settings.local.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash /Users/arthurficial/dev/workshop-display-manager/.claude/hooks/stop-verify.sh"
          }
        ]
      }
    ]
  }
}
```

Reload via `/hooks` in Claude Code (or restart the session) so the settings watcher picks up the change.

## Removing the install

```sh
rm -rf .claude/skills .claude/agents
rm .claude/commands/{spec,plan,build,test,review,ship,code-simplify}.md
rm .claude/AGENT-SKILLS.md
```
