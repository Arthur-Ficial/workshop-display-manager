#!/usr/bin/env bash
# Lint: every interactive element in Sources/WDMMac/ MUST be covered by an
# e2e test. Two checks:
#
#   1. Every Button / Picker / Toggle / segmented Picker / etc. in WDMMac
#      view files declares an `.accessibilityIdentifier(...)` (or its alias
#      `.remoteID(...)` once that ships).
#   2. Every accessibilityIdentifier value declared in WDMMac is referenced
#      from at least one file under Tests/WDMMacE2ETests/ (or named in a
#      smoke script under scripts/).
#
# Either check failing means a UI element exists that an AI / e2e harness
# cannot find or click — which is a CLAUDE.md violation (the
# "TDD + visibly-demonstrable e2e" non-negotiable).
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

# --- Check 1: every interactive element declares an .accessibilityIdentifier.
# Heuristic: in a single .swift file, find every line where a Button or
# Picker is constructed; then assert that the SAME file mentions
# accessibilityIdentifier (or remoteID) at least once.
INTERACTIVE_PATTERN='\<(Button|Picker|Toggle|TextField|SecureField|Stepper|Menu)\>'
while IFS= read -r -d '' f; do
  rel=${f#$ROOT/}
  if grep -qE "$INTERACTIVE_PATTERN" "$f"; then
    if ! grep -qE 'accessibilityIdentifier|remoteID' "$f"; then
      echo "✘ $rel constructs interactive elements but declares no .accessibilityIdentifier" >&2
      grep -nE "$INTERACTIVE_PATTERN" "$f" | head -3 | sed 's/^/    /' >&2
      violations=$((violations + 1))
    fi
  fi
done < <(find "$TARGET" -name "*.swift" -print0)

# --- Check 2: every accessibilityIdentifier value used in WDMMac is
# referenced from a test or smoke script.
mkdir -p /tmp/lint-remote-coverage
ids_file=/tmp/lint-remote-coverage/ids.txt
covered_file=/tmp/lint-remote-coverage/covered.txt
: > "$ids_file"; : > "$covered_file"

# Extract every literal string passed to accessibilityIdentifier(...).
while IFS= read -r -d '' f; do
  grep -oE 'accessibilityIdentifier\("[^"]+"\)' "$f" 2>/dev/null \
    | sed -E 's/accessibilityIdentifier\("([^"]+)"\)/\1/' \
    >> "$ids_file" || true
  grep -oE '\.remoteID\("[^"]+"\)' "$f" 2>/dev/null \
    | sed -E 's/\.remoteID\("([^"]+)"\)/\1/' \
    >> "$ids_file" || true
done < <(find "$TARGET" -name "*.swift" -print0)

# Drop interpolated identifiers (they have \( in them) — those can't be
# string-matched against tests, so we treat them as covered by their prefix.
sort -u "$ids_file" -o "$ids_file"

# Build coverage set: any identifier mentioned in a test file or smoke
# script is "covered". For interpolated forms (e.g. displays.tile.\(d.id))
# we accept the literal prefix as covering anything with that prefix.
search_corpus=$(find "$TESTS" -name "*.swift" 2>/dev/null; \
                find "$SMOKES" -name "*.sh" 2>/dev/null; \
                find "$TESTS"/.. -name "*.swift" 2>/dev/null \
                  | xargs grep -l "accessibilityIdentifier\|remoteID" 2>/dev/null || true)

while IFS= read -r id; do
  [[ -z "$id" ]] && continue
  # Interpolated identifiers (have \( in them): the LITERAL PREFIX before
  # the \( is what we test for. e.g. `displays.tile.\(d.id)` is covered by
  # any test mention of `displays.tile.`.
  if [[ "$id" == *"\\("* ]]; then
    prefix="${id%%\\(*}"
    if echo "$search_corpus" | xargs grep -lF "$prefix" 2>/dev/null | grep -q .; then
      echo "$id" >> "$covered_file"
    fi
    continue
  fi
  if echo "$search_corpus" | xargs grep -lF "$id" 2>/dev/null | grep -q .; then
    echo "$id" >> "$covered_file"
  fi
done < "$ids_file"

# Anything in ids_file but not covered_file is uncovered. (Use `comm` for
# clean set-difference rather than the sort/uniq dance.)
sort -u "$ids_file" -o "$ids_file"
sort -u "$covered_file" -o "$covered_file"
uncovered=$(comm -23 "$ids_file" "$covered_file")
if [[ -n "$uncovered" ]]; then
  echo "✘ accessibilityIdentifier values with NO covering e2e test or smoke:" >&2
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    echo "    $id" >&2
    violations=$((violations + 1))
  done <<< "$uncovered"
fi

# --- Check 3: every window the app creates must have an open AND close
# test. We find every NSWindow/.title = "X" assignment in the codebase,
# then confirm that some test or smoke references both the window name
# AND a close-button click (`wdm_close_window` or `click button 1 of window`).
# Use mapfile to capture multi-word window names cleanly. Skip empties.
mapfile -t window_names < <(
  grep -rhoE 'win\.title\s*=\s*"[^"]+"|w\.title\s*=\s*"[^"]+"' \
    "$ROOT/Sources/WDMMacRemote" "$ROOT/Sources/WDMMac" 2>/dev/null \
    | sed -E 's/.*"([^"]+)".*/\1/' | sort -u
)
for name in "${window_names[@]}"; do
  [[ -z "$name" ]] && continue
  if echo "$search_corpus" | xargs grep -lF "wdm_close_window \"$name\"" 2>/dev/null | grep -q .; then
    continue
  fi
  if echo "$search_corpus" | xargs grep -lE "click button 1 of window \"$name\"" 2>/dev/null | grep -q .; then
    continue
  fi
  echo "✘ window \"$name\" has no close-button test (wdm_close_window or 'click button 1 of window')" >&2
  violations=$((violations + 1))
done

if [[ "$violations" -gt 0 ]]; then
  echo
  echo "lint-remote-coverage: $violations violation(s)" >&2
  echo "  Add a remote-driven e2e test under Tests/WDMMacE2ETests/, or a smoke" >&2
  echo "  script under scripts/, that references each accessibilityIdentifier" >&2
  echo "  AND uses wdm_close_window for every window the app creates." >&2
  exit 1
fi
echo "lint-remote-coverage: ✓ every interactive element + every window's close button is covered"
