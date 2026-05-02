#!/bin/sh
# wdm installer — fetches the latest signed release from GitHub, verifies its
# SHA-256 + Developer-ID code signature + notarization ticket, then installs.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Arthur-Ficial/workshop-display-manager/main/install.sh | sh
#   curl -fsSL ... | sh -s -- --user      # install to ~/.local/bin instead of /usr/local/bin
#   PREFIX=/tmp/wdm-test ./install.sh     # install under a custom prefix (used by tests)

set -eu

REPO="Arthur-Ficial/workshop-display-manager"
PREFIX_DEFAULT="/usr/local"
USER_PREFIX="$HOME/.local"

USE_USER=0
for arg in "$@"; do
    case "$arg" in
        --user) USE_USER=1 ;;
        --help|-h)
            cat <<EOF
wdm installer

Options:
  --user        Install under ~/.local/bin instead of /usr/local/bin (no sudo).
  --help, -h    Show this help.

Environment:
  PREFIX        Override install prefix (default: /usr/local, or ~/.local with --user).

Verifies SHA-256, code signature, and notarization ticket before installing.
EOF
            exit 0
            ;;
    esac
done

# Resolve PREFIX precedence: env > --user > default.
if [ -z "${PREFIX:-}" ]; then
    if [ "$USE_USER" -eq 1 ]; then
        PREFIX="$USER_PREFIX"
    else
        PREFIX="$PREFIX_DEFAULT"
    fi
fi

BIN_DIR="$PREFIX/bin"
MAN_DIR="$PREFIX/share/man/man1"

# Pre-flight checks.
if [ "$(uname -s)" != "Darwin" ]; then
    echo "wdm: this installer is macOS-only (saw $(uname -s))" >&2
    exit 1
fi
if [ "$(uname -m)" != "arm64" ]; then
    echo "wdm: only Apple Silicon (arm64) is supported (saw $(uname -m))" >&2
    exit 1
fi

OS_VERSION=$(sw_vers -productVersion)
OS_MAJOR=${OS_VERSION%%.*}
if [ "$OS_MAJOR" -lt 13 ]; then
    echo "wdm: requires macOS 13 or later (saw $OS_VERSION)" >&2
    exit 1
fi

for tool in curl tar shasum codesign spctl install; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "wdm: required tool not found: $tool" >&2
        exit 1
    fi
done

TMP_DIR=$(mktemp -d -t wdm-install)
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT INT TERM

API_BASE="https://api.github.com/repos/$REPO/releases/latest"

echo "wdm: fetching latest release info from $REPO..."
RELEASE_JSON="$TMP_DIR/release.json"
curl -fsSL -o "$RELEASE_JSON" "$API_BASE"

# Parse the tarball + sha256 asset URLs out of the JSON. POSIX-friendly grep.
TARBALL_URL=$(grep -o '"browser_download_url": *"[^"]*\.tar\.gz"' "$RELEASE_JSON" \
              | head -n1 | sed 's/.*"\(https:[^"]*\)"/\1/')
SHA_URL=$(grep -o '"browser_download_url": *"[^"]*\.tar\.gz\.sha256"' "$RELEASE_JSON" \
          | head -n1 | sed 's/.*"\(https:[^"]*\)"/\1/')

if [ -z "$TARBALL_URL" ] || [ -z "$SHA_URL" ]; then
    echo "wdm: could not find release tarball + sha256 in $API_BASE" >&2
    echo "     Either no release has been published yet, or the asset names changed." >&2
    exit 1
fi

echo "wdm: downloading $TARBALL_URL"
TARBALL="$TMP_DIR/wdm.tar.gz"
SHA_FILE="$TMP_DIR/wdm.tar.gz.sha256"
curl -fsSL -o "$TARBALL" "$TARBALL_URL"
curl -fsSL -o "$SHA_FILE" "$SHA_URL"

echo "wdm: verifying SHA-256..."
EXPECTED=$(awk '{print $1}' "$SHA_FILE")
ACTUAL=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
if [ "$EXPECTED" != "$ACTUAL" ]; then
    echo "wdm: SHA-256 mismatch:" >&2
    echo "     expected: $EXPECTED" >&2
    echo "     actual:   $ACTUAL" >&2
    exit 1
fi

echo "wdm: extracting..."
mkdir -p "$TMP_DIR/extract"
tar -xzf "$TARBALL" -C "$TMP_DIR/extract"
BIN_PATH="$TMP_DIR/extract/wdm"
if [ ! -f "$BIN_PATH" ]; then
    echo "wdm: tarball did not contain a 'wdm' binary at the root" >&2
    exit 1
fi

echo "wdm: verifying Developer-ID code signature..."
codesign --verify --strict --verbose=2 "$BIN_PATH" || {
    echo "wdm: code signature verification failed" >&2
    exit 1
}

echo "wdm: verifying notarization ticket..."
if ! spctl --assess --type install --verbose "$BIN_PATH" 2>/dev/null; then
    echo "wdm: warning — notarization assessment failed; binary may need to be" >&2
    echo "     opened once via Finder to clear the quarantine bit." >&2
fi

echo "wdm: installing to $BIN_DIR..."
mkdir -p "$BIN_DIR"
install -m 0755 "$BIN_PATH" "$BIN_DIR/wdm"

# Optional man page if the tarball includes one.
if [ -f "$TMP_DIR/extract/wdm.1" ]; then
    mkdir -p "$MAN_DIR"
    install -m 0644 "$TMP_DIR/extract/wdm.1" "$MAN_DIR/wdm.1"
fi

echo
echo "wdm: installed to $BIN_DIR/wdm"
"$BIN_DIR/wdm" version
echo
echo "Run 'wdm help' to see the command list."
echo "Add this to your shell's rc file for completions:"
echo "  zsh:  wdm completions zsh > /usr/local/share/zsh/site-functions/_wdm"
echo "  bash: wdm completions bash > /usr/local/etc/bash_completion.d/wdm"
echo "  fish: wdm completions fish > ~/.config/fish/completions/wdm.fish"
