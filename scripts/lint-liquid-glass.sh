#!/usr/bin/env bash
# Liquid Glass linter for WDMMac.
#
# Forbids cheap-looking chrome surfaces in `Sources/WDMMac/`. Every chrome
# surface in this lib must use Liquid Glass (`.glassEffect(...)` /
# `Glass.regular|clear` / `.buttonStyle(.glass|.glassProminent)` /
# `GlassEffectContainer`) when running on macOS 26+. The `regularMaterial`
# fallback is allowed only inside `if #available` branches that explicitly
# choose it as the macOS-13 fallback path, AND only inside files in
# `Sources/WDMMac/Theme/`.
#
# Run via `make lint-glass`.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TARGET="$ROOT/Sources/WDMMac"
violations=0

if [[ ! -d "$TARGET" ]]; then
  echo "lint-glass: $TARGET missing — nothing to check"
  exit 0
fi

# Forbidden tokens. These materials look like Material chrome from the macOS
# 11 era. They're banned everywhere in WDMMac.
FORBIDDEN_MATERIALS='Material\.(thinMaterial|thickMaterial|ultraThinMaterial|ultraThickMaterial|barMaterial)|\.thinMaterial|\.thickMaterial|\.ultraThinMaterial|\.ultraThickMaterial|\.barMaterial'

# Forbidden chrome shortcuts: don't use Color.gray/black/white as a chrome
# background — chrome should be glass.
FORBIDDEN_CHROME='\.background\(Color\.(white|black|gray|secondary|primary)\)'

found_in_files=()
while IFS= read -r -d '' f; do
  rel=${f#$ROOT/}
  if grep -nE "$FORBIDDEN_MATERIALS" "$f" >/tmp/lint-glass-hits.tmp; then
    echo "✘ forbidden material in $rel:" >&2
    cat /tmp/lint-glass-hits.tmp >&2
    violations=$((violations + 1))
    found_in_files+=("$rel")
  fi
  if grep -nE "$FORBIDDEN_CHROME" "$f" >/tmp/lint-glass-hits.tmp; then
    echo "✘ chrome shortcut in $rel (use glass, not solid Color):" >&2
    cat /tmp/lint-glass-hits.tmp >&2
    violations=$((violations + 1))
    found_in_files+=("$rel")
  fi
done < <(find "$TARGET" -name "*.swift" -print0)

# regularMaterial is allowed in two specific places:
#   - Sources/WDMMac/Theme/   — the macOS-13 fallback inside GlassPanel
#   - .containerBackground(.regularMaterial, for: .window)   — Apple's canonical
#     window-level glass surface; on macOS 26 the system promotes this to
#     real Tahoe Liquid Glass, on older macOS it's the legacy material
while IFS= read -r -d '' f; do
  rel=${f#$ROOT/}
  if grep -nE 'regularMaterial' "$f" >/tmp/lint-glass-hits.tmp; then
    # Strip the legitimate containerBackground line, then check if anything
    # naked-regularMaterial remains.
    if grep -nE 'regularMaterial' "$f" \
        | grep -vE 'containerBackground\(.*regularMaterial.*\.window' >/tmp/lint-glass-hits.tmp; then
      [[ -s /tmp/lint-glass-hits.tmp ]] || continue
      case "$rel" in
        Sources/WDMMac/Theme/*) ;;  # OK in Theme — that's where the fallback lives
        *)
          echo "✘ regularMaterial outside Theme/ in $rel — must be inside GlassPanel" >&2
          echo "  (or .containerBackground(.regularMaterial, for: .window) for window glass):" >&2
          cat /tmp/lint-glass-hits.tmp >&2
          violations=$((violations + 1))
          ;;
      esac
    fi
  fi
done < <(find "$TARGET" -name "*.swift" -print0)

# Positive check: every file under Sources/WDMMac/Views/ should reference at
# least one of the Liquid Glass primitives, OR delegate via GlassPanel /
# liquidGlassButton (the WDMMac wrappers).
GLASS_TOKENS='glassEffect|GlassEffectContainer|GlassPanel|liquidGlassButton|\.buttonStyle\(\.glass|Glass\.(regular|clear|identity)'
while IFS= read -r -d '' f; do
  rel=${f#$ROOT/}
  if ! grep -qE "$GLASS_TOKENS" "$f"; then
    echo "✘ no Liquid Glass primitive used in $rel — chrome surfaces must use glass:" >&2
    echo "  (allowed: glassEffect, GlassEffectContainer, GlassPanel, liquidGlassButton, .buttonStyle(.glass), Glass.regular)" >&2
    violations=$((violations + 1))
  fi
done < <(find "$TARGET/Views" -name "*.swift" -print0)

rm -f /tmp/lint-glass-hits.tmp

if [[ "$violations" -gt 0 ]]; then
  echo
  echo "lint-glass: $violations violation(s)" >&2
  exit 1
fi
echo "lint-glass: ✓ all WDMMac chrome uses Liquid Glass"
