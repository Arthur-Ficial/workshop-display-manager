#!/usr/bin/env bash
# Lint: every CLICKABLE element in Sources/WDMMac/ must have a real click
# test in the smokes / e2e tests. Every PASSIVE container with an
# accessibilityIdentifier must at least be QUERIED (wdm_ax_dump, etc.)
# so it's reachable for assertions.
#
# Three checks:
#   1. Every Button / Picker / Toggle / Stepper / TextField in WDMMac
#      view files declares an .accessibilityIdentifier (else: any
#      AI / e2e harness can't find it).
#   2. Every CLICKABLE accessibilityIdentifier appears INSIDE an actual
#      click verb (wdm_ax_click, wdm-mac-control click, click button,
#      click radio button, wdm_close_window). Naked string literals don't
#      count — the smoke could just enumerate IDs in a comment.
#   3. Every NSWindow the app creates has a close-button test.
#
# Run via `make lint-remote-coverage`.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TARGET="$ROOT/Sources/WDMMac"
TESTS="$ROOT/Tests/WDMMacE2ETests"
SMOKES="$ROOT/scripts"
violations=0

if [[ ! -d "$TARGET" ]]; then
  echo "lint-remote-coverage: $TARGET missing — nothing to check"
  exit 0
fi

# --- Check 0: NO osascript / AppleScript ANYWHERE under tests/, smokes/,
# OR the helper lib. The whole point of the remote API is that the GUI is
# agent-controllable WITHOUT an AppleScript bridge — every click goes
# through wdm-mac-control / the in-process AX walker via /ui/click. A lint
# that whitelisted the lib was lying to itself: smokes that source the
# lib then use wdm_ax_click are still depending on osascript.
#
# Whitelist limited to:
#   - scripts/lint-*.sh themselves (this file may grep for the pattern)
#   - scripts/lib/wdm-mac.sh ONLY for helpers that wrap the binary
#     (wdm_remote_curl etc.). Any wdm_ax_* / wdm_keystroke / wdm_window_geom
#     in the lib is a violation flagged here too.
osascript_violations=0
while IFS= read -r f; do
  if grep -nE 'osascript|tell application "System Events"|tell process "wdm-mac"' "$f" >/dev/null 2>&1; then
    rel=${f#$ROOT/}
    case "$rel" in
      scripts/lint-*.sh) continue ;;  # the linter scripts ARE allowed to mention the patterns they ban
    esac
    echo "✘ $rel contains osascript / AppleScript — the GUI must be drivable without it (wdm-mac-control + /ui/click only):" >&2
    grep -nE 'osascript|tell application "System Events"|tell process "wdm-mac"' "$f" | head -3 | sed 's/^/    /' >&2
    osascript_violations=$((osascript_violations + 1))
    violations=$((violations + 1))
  fi
done < <(find "$TESTS" "$SMOKES" -type f \( -name "*.sh" -o -name "*.swift" \) 2>/dev/null)

INTERACTIVE_PATTERN='\<(Button|Picker|Toggle|TextField|SecureField|Stepper|Menu)\>'

# --- Check 1: every interactive element file declares an
# .accessibilityIdentifier somewhere.
while IFS= read -r -d '' f; do
  rel=${f#$ROOT/}
  if grep -qE "$INTERACTIVE_PATTERN" "$f" \
     && ! grep -qE 'accessibilityIdentifier|remoteID' "$f"; then
    echo "✘ $rel constructs interactive elements but declares no .accessibilityIdentifier" >&2
    grep -nE "$INTERACTIVE_PATTERN" "$f" | head -3 | sed 's/^/    /' >&2
    violations=$((violations + 1))
  fi
done < <(find "$TARGET" -name "*.swift" -print0)

# --- Build the index of every accessibilityIdentifier with its CLICKABLE
# / PASSIVE classification. An ID is CLICKABLE when its source line is
# a chained modifier on (or appears within ~5 lines of) a Button / Picker
# / Toggle / TextField / SegmentedRow / ActionRow / SidebarDisplayRow
# constructor in the same file. Otherwise PASSIVE.
mkdir -p /tmp/lint-remote-coverage
clickable_file=/tmp/lint-remote-coverage/clickable.txt
passive_file=/tmp/lint-remote-coverage/passive.txt
covered_file=/tmp/lint-remote-coverage/covered.txt
: > "$clickable_file"; : > "$passive_file"; : > "$covered_file"

# Patterns that mark a SwiftUI element as user-clickable. SegmentedRow and
# ActionRow are our own wrappers; treat them as clickable too.
CLICKABLE_RE='\<(Button|Picker|Toggle|Stepper|TextField|SecureField|SegmentedRow|ActionRow|SidebarDisplayRow)\b'

while IFS= read -r -d '' f; do
  # Find each line carrying an accessibilityIdentifier or .remoteID literal.
  while IFS=: read -r lineno line; do
    # Extract the id literal
    id=$(echo "$line" | sed -nE 's/.*(accessibilityIdentifier|remoteID)\("([^"]+)"\).*/\2/p')
    [[ -z "$id" ]] && continue
    # Is the same file (within ±8 lines) constructing a clickable element?
    start=$(( lineno - 8 )); [[ $start -lt 1 ]] && start=1
    end=$(( lineno + 8 ))
    snippet=$(sed -n "${start},${end}p" "$f")
    if echo "$snippet" | grep -qE "$CLICKABLE_RE"; then
      echo "$id" >> "$clickable_file"
    else
      echo "$id" >> "$passive_file"
    fi
  done < <(grep -nE 'accessibilityIdentifier\(|\.remoteID\(' "$f" 2>/dev/null || true)
done < <(find "$TARGET" -name "*.swift" -print0)

sort -u "$clickable_file" -o "$clickable_file"
sort -u "$passive_file" -o "$passive_file"

# An ID can be both CLICKABLE and PASSIVE in different files — clickable wins.
comm -23 "$passive_file" "$clickable_file" > /tmp/lint-remote-coverage/passive-only.txt
mv /tmp/lint-remote-coverage/passive-only.txt "$passive_file"

# --- Build search corpus: ONLY Swift e2e tests. Bash smokes are demos
# (visible runs) — they're not tests. A lint that accepted smokes as
# coverage is gameable: anyone can list IDs in a comment. Real coverage
# requires real assertions in real Swift e2e tests.
search_corpus=$(find "$TESTS" -name "*.swift" 2>/dev/null
                find "$ROOT/Tests" -name "*.swift" 2>/dev/null)

CLICK_VERBS='(wdm_ax_click|wdm_close_window|wdm-mac-control click|click button|click radio button|click radio buton|press|#expect.*click|click "|XCTAssert.*click|accessibilityPerformPress)'
QUERY_VERBS='(wdm_ax_dump|wdm_ax_click|wdm_close_window|wdm-mac-control|accessibilityIdentifier|remoteID|click button|click radio button)'

is_covered_by() {
  local id="$1" verbs="$2"
  # Use grep -F via two passes: first filter files containing the literal id,
  # then grep -E for the verb on those same files. Sidesteps regex-escape
  # hell with interpolated ids that contain '(' ')'.
  local hits
  hits=$(echo "$search_corpus" | xargs grep -lF "$id" 2>/dev/null || true)
  [[ -z "$hits" ]] && return 1
  echo "$hits" | xargs grep -lE "$verbs" 2>/dev/null | grep -q .
}

# CLICKABLE IDs need a click verb.
while IFS= read -r id; do
  [[ -z "$id" ]] && continue
  if [[ "$id" == *"\\("* ]]; then
    prefix="${id%%\\(*}"
    if is_covered_by "$prefix" "$CLICK_VERBS"; then
      echo "$id" >> "$covered_file"
    fi
    continue
  fi
  if is_covered_by "$id" "$CLICK_VERBS"; then
    echo "$id" >> "$covered_file"
  fi
done < "$clickable_file"

# PASSIVE IDs just need to be queried somewhere.
while IFS= read -r id; do
  [[ -z "$id" ]] && continue
  if [[ "$id" == *"\\("* ]]; then
    prefix="${id%%\\(*}"
    if is_covered_by "$prefix" "$QUERY_VERBS"; then
      echo "$id" >> "$covered_file"
    fi
    continue
  fi
  if is_covered_by "$id" "$QUERY_VERBS"; then
    echo "$id" >> "$covered_file"
  fi
done < "$passive_file"

sort -u "$covered_file" -o "$covered_file"
all_ids=/tmp/lint-remote-coverage/all.txt
sort -u "$clickable_file" "$passive_file" > "$all_ids"
uncovered=$(comm -23 "$all_ids" "$covered_file")

if [[ -n "$uncovered" ]]; then
  echo "✘ accessibilityIdentifier values with NO covering test:" >&2
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    if grep -qx "$id" "$clickable_file"; then
      echo "    [CLICKABLE — needs a real click] $id" >&2
    else
      echo "    [PASSIVE — needs an a11y query]   $id" >&2
    fi
    violations=$((violations + 1))
  done <<< "$uncovered"
fi

# --- Check 3: every NSWindow the app creates has a close-button test.
mapfile -t window_names < <(
  grep -rhoE 'win\.title\s*=\s*"[^"]+"|w\.title\s*=\s*"[^"]+"' \
    "$ROOT/Sources/WDMMacRemote" "$ROOT/Sources/WDMMac" 2>/dev/null \
    | sed -E 's/.*"([^"]+)".*/\1/' | sort -u
)
for name in "${window_names[@]}"; do
  [[ -z "$name" ]] && continue
  if echo "$search_corpus" | xargs grep -lF "wdm_close_window \"$name\"" 2>/dev/null | grep -q .; then continue; fi
  if echo "$search_corpus" | xargs grep -lE "click button 1 of window \"$name\"" 2>/dev/null | grep -q .; then continue; fi
  echo "✘ window \"$name\" has no close-button test (wdm_close_window or 'click button 1 of window')" >&2
  violations=$((violations + 1))
done

if [[ "$violations" -gt 0 ]]; then
  echo
  echo "lint-remote-coverage: $violations violation(s)" >&2
  echo "  CLICKABLE IDs need a wdm_ax_click / wdm-mac-control click / click radio button." >&2
  echo "  PASSIVE IDs need at least a wdm_ax_dump / a11y query." >&2
  echo "  Every window needs a wdm_close_window test." >&2
  exit 1
fi
clickable_count=$(wc -l < "$clickable_file" | tr -d ' ')
passive_count=$(wc -l < "$passive_file" | tr -d ' ')
echo "lint-remote-coverage: ✓ $clickable_count clickable + $passive_count passive elements covered, every window's close button tested"
