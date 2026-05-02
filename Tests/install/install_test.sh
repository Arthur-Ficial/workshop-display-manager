#!/usr/bin/env bash
# Smoke-test for install.sh — runs the relevant shell-script pieces against a
# locally-built binary (substituting for the GitHub release fetch) so we can
# verify the install path works without needing a published release.
#
# Run from the repo root:
#   ./Tests/install/install_test.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN_PATH="$REPO_ROOT/.build/release/wdm"

if [ ! -x "$BIN_PATH" ]; then
    echo "install_test: building release first..."
    ( cd "$REPO_ROOT" && swift build -c release -Xswiftc -warnings-as-errors )
fi

PREFIX=$(mktemp -d -t wdm-install-test)
trap 'rm -rf "$PREFIX"' EXIT INT TERM

# Mimic the install.sh tail: place the binary under PREFIX/bin, verify it runs.
mkdir -p "$PREFIX/bin"
install -m 0755 "$BIN_PATH" "$PREFIX/bin/wdm"

# 1. Binary is executable
test -x "$PREFIX/bin/wdm" || { echo "FAIL: binary not executable"; exit 1; }

# 2. `version` works
"$PREFIX/bin/wdm" version >/dev/null || { echo "FAIL: version"; exit 1; }

# 3. `help` works
"$PREFIX/bin/wdm" help >/dev/null || { echo "FAIL: help"; exit 1; }

# 4. `completions zsh` produces a non-empty #compdef script
out=$("$PREFIX/bin/wdm" completions zsh)
case "$out" in
    "#compdef wdm"*) ;;
    *) echo "FAIL: completions zsh did not start with #compdef wdm"; exit 1 ;;
esac

# 5. `manpage` produces a non-empty .TH header
out=$("$PREFIX/bin/wdm" manpage)
case "$out" in
    ".TH WDM 1"*) ;;
    *) echo "FAIL: manpage did not start with .TH WDM 1"; exit 1 ;;
esac

# 6. `list --json` is valid JSON (uses real CG backend; allow non-zero only if
#    no displays — but on dev hardware there's always at least one).
"$PREFIX/bin/wdm" list --json | python3 -m json.tool >/dev/null \
    || { echo "FAIL: list --json is not valid JSON"; exit 1; }

# 7. install.sh syntax check
sh -n "$REPO_ROOT/install.sh" || { echo "FAIL: install.sh syntax"; exit 1; }

echo "install_test: all checks passed"
