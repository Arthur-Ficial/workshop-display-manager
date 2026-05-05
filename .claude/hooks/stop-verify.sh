#!/bin/bash
# Project-local stop-verify hook for workshop-display-manager.
# Fires AGGRESSIVELY — ignores `stop_hook_active` (the once-per-chain
# gate the global hook uses) so it blocks every stop, with a 30-second
# debounce file to prevent tight infinite-loop spirals.
#
# Why this exists: the global ~/.claude/hooks/stop-verify.sh fires only
# the first time Claude tries to stop in a given chain. Once Claude has
# already responded to a verify-block, subsequent stops in the same
# chain exit silently. In long sessions on this repo, that means the
# verify discipline degrades after the first checkpoint. This local
# hook re-blocks every 30+ seconds, keeping the discipline up.
set -u

debounce_file="/tmp/wdm-stop-verify-last-fire"
now=$(date +%s)
last=0
if [ -f "$debounce_file" ]; then
    last=$(cat "$debounce_file" 2>/dev/null || echo 0)
fi
elapsed=$(( now - last ))

# 30-second debounce: don't re-fire if the previous block was less than
# that ago. Prevents back-to-back Claude turns from looping forever.
if [ "$elapsed" -lt 30 ]; then
    exit 0
fi

# Update debounce timestamp BEFORE emitting the block so two near-
# simultaneous fires only block once.
echo "$now" > "$debounce_file"

read -r -d '' reason <<'EOF' || true
STOP VERIFY (project-local, every 30s). Goal: finish the task. Don't stop early.

1. Prove it with tool output: GUI -> `tinyscreenshot main -w 800 -c grey` (or `app "<Name>"` / `region x,y,w,h`) then Read the path. Tests -> run, green. Build -> run, clean. Script -> run, show stdout. Docs -> re-read. No speculation.
2. Check the todo list (tasks/todo.md): make it honest (close done items, drop stale ones). Open items still doable -> do them. Follow-ups uncovered -> add them, then do them. Only stop when the list is current and empty of doable work.
3. Waiting on an event you're sure will fire (build, CI, async job)? Just wait. Take no action.
4. Gap found -> continue and fix. Don't stop to report or ask trivia; user isn't watching.
5. Blocked? Try one more concrete thing first. Only stop if truly stuck; state blocker + unblock.
EOF

jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
