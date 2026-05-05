#!/usr/bin/env bash
# wdm-update.sh
#
# Manual updater for WDMMac.app (per ADR 0002 — Sparkle deferred).
# Downloads the latest GitHub release zip, replaces /Applications/
# WDMMac.app, optionally re-launches.
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Arthur-Ficial/workshop-display-manager/main/scripts/wdm-update.sh)
#
# Or local:
#   bash scripts/wdm-update.sh
set -euo pipefail

REPO="Arthur-Ficial/workshop-display-manager"
APP_DIR="/Applications/WDMMac.app"

if ! command -v curl >/dev/null 2>&1; then
    echo "wdm-update: curl missing — install via xcode-select --install" >&2
    exit 2
fi

# Find latest release tag.
TAG=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | sed -nE 's/.*"tag_name": *"([^"]+)".*/\1/p' | head -1)

if [ -z "$TAG" ]; then
    echo "wdm-update: could not find latest release tag for $REPO" >&2
    exit 1
fi

# Find the asset zip.
ASSET=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | sed -nE 's/.*"browser_download_url": *"([^"]+\.zip)".*/\1/p' | head -1)

if [ -z "$ASSET" ]; then
    echo "wdm-update: no .zip asset attached to release $TAG" >&2
    exit 1
fi

echo "wdm-update: latest = $TAG"
echo "wdm-update: asset  = $ASSET"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
ZIP="$TMP/wdm-update.zip"
curl -fsSL -o "$ZIP" "$ASSET"

unzip -q "$ZIP" -d "$TMP"
NEW_APP=$(find "$TMP" -name 'WDMMac.app' -type d -maxdepth 3 | head -1)
[ -d "$NEW_APP" ] || { echo "wdm-update: zip didn't contain WDMMac.app" >&2; exit 1; }

# Verify signature before replacing.
if ! spctl -a -t exec -vv "$NEW_APP" 2>&1 | grep -q "Notarized Developer ID"; then
    echo "wdm-update: REFUSING — downloaded bundle is not notarized:" >&2
    spctl -a -t exec -vv "$NEW_APP" >&2 || true
    exit 1
fi

# Quit existing instance + replace.
osascript -e 'tell application "WDMMac" to quit' 2>/dev/null || true
sleep 1
rm -rf "$APP_DIR"
mv "$NEW_APP" "$APP_DIR"

echo "wdm-update: ✓ updated to $TAG at $APP_DIR"

if [ "${WDM_UPDATE_SKIP_LAUNCH:-}" != "1" ]; then
    open "$APP_DIR"
fi
