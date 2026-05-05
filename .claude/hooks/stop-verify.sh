#!/bin/bash
# Project-local stop-verify hook for workshop-display-manager.
# Fires ONCE PER CHAIN — same semantics as the global hook
# (~/.claude/hooks/stop-verify.sh). The Claude Code runtime sets
# `stop_hook_active=true` on the JSON input after a hook has already
# blocked once in the current chain; we honour that flag and exit
# silently so subsequent stops in the same chain go through.
#
# Earlier this hook fired every 30 seconds via a debounce file —
# that turned out to be too noisy in long sessions. Reverted to the
# standard once-per-chain gate after user feedback 2026-05-05.
set -u
input=$(cat)
already_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
if [ "$already_active" = "true" ]; then
  exit 0
fi

read -r -d '' reason <<'EOF' || true
STOP VERIFY (once per chain). Goal: finish the task. Don't stop early.

1. Prove it with tool output: GUI -> `tinyscreenshot main -w 800 -c grey` (or `app "<Name>"` / `region x,y,w,h`) then Read the path. Tests -> run, green. Build -> run, clean. Script -> run, show stdout. Docs -> re-read. No speculation.
2. Check the todo list (tasks/todo.md): make it honest (close done items, drop stale ones). Open items still doable -> do them. Follow-ups uncovered -> add them, then do them. Only stop when the list is current and empty of doable work.
3. Waiting on an event you're sure will fire (build, CI, async job)? Just wait. Take no action.
4. Gap found -> continue and fix. Don't stop to report or ask trivia; user isn't watching.
5. Blocked? Try one more concrete thing first. Only stop if truly stuck; state blocker + unblock.
EOF

jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
