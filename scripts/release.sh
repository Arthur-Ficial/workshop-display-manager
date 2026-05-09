#!/usr/bin/env bash
# release.sh <version>
#
# One-shot reproducible release pipeline for v0.x.0+. Replaces hand
# steps with a single command:
#
#   bash scripts/release.sh 0.2.0
#
# Pipeline:
#   1. Validate working tree clean (refuse to release with uncommitted edits).
#   2. Rewrite Sources/WDMCore/Version.swift with the requested version.
#   3. swift build -c release -Xswiftc -warnings-as-errors
#   4. scripts/bundle-wdm-mac.sh release  → WDMMac.app, signed Developer ID
#      with hardened runtime + entitlements (already wired in the bundler)
#   5. xcrun notarytool submit ... --keychain-profile notarytool --wait
#   6. xcrun stapler staple ... ; xcrun stapler validate
#   7. spctl -a -t exec -vv  → must say "accepted source=Notarized Developer ID"
#   8. zip the bundle for distribution
#   9. (optional) git tag + push  — only when WDM_RELEASE_TAG=1
#
# Notarization needs the keychain profile "notarytool" already stored
# (see ~/dev/apple-dev-id/README.md). Profile is created once via
# `xcrun notarytool store-credentials notarytool` and persisted in
# the macOS keychain.
#
# Exit non-zero on any step. The user can re-run from a known state.
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "usage: release.sh <version>   (e.g. release.sh 0.2.0)" >&2
    exit 2
fi

VERSION="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Semver shape check.
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$'; then
    echo "release: '$VERSION' is not a semver token" >&2
    exit 2
fi

# Step 1 — refuse to release with uncommitted edits.
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "release: working tree has uncommitted changes — commit/stash first." >&2
    git status --short >&2
    exit 1
fi

# Step 2 — rewrite Version.swift.
VERSION_FILE="$ROOT/Sources/WDMCore/Version.swift"
if ! grep -q 'public static let current:' "$VERSION_FILE"; then
    echo "release: $VERSION_FILE missing 'public static let current'" >&2
    exit 1
fi
sed -i.bak -E "s|public static let current: String = \"[^\"]+\"|public static let current: String = \"$VERSION\"|" "$VERSION_FILE"
rm -f "${VERSION_FILE}.bak"
git diff --quiet "$VERSION_FILE" || {
    git add "$VERSION_FILE"
    git commit -m "release: bump Version.current to $VERSION" >/dev/null
}

# Step 3 — release build, warnings-as-errors.
echo "release: swift build -c release -Xswiftc -warnings-as-errors..."
swift build -c release -Xswiftc -warnings-as-errors

# Step 4 — bundle + sign.
echo "release: bundle + Developer ID sign..."
make app-mac-release >/dev/null
APP="$ROOT/.build/release/WDMMac.app"
[ -d "$APP" ] || { echo "release: $APP not produced" >&2; exit 1; }

# Verify the bundle reports the expected version BEFORE notarization.
ACT_VER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null)
if [ "$ACT_VER" != "$VERSION" ]; then
    echo "release: Info.plist CFBundleShortVersionString = '$ACT_VER' ≠ '$VERSION'" >&2
    exit 1
fi

# Step 5 — notarize. Skip when WDM_RELEASE_SKIP_NOTARIZE=1 (CI only).
if [ "${WDM_RELEASE_SKIP_NOTARIZE:-}" = "1" ]; then
    echo "release: WDM_RELEASE_SKIP_NOTARIZE=1 — skipping notarytool"
else
    echo "release: zipping for notarytool..."
    ZIP="$ROOT/.build/release/WDMMac-${VERSION}.zip"
    rm -f "$ZIP"
    (cd "$ROOT/.build/release" && /usr/bin/ditto -c -k --sequesterRsrc --keepParent WDMMac.app "$ZIP")
    echo "release: xcrun notarytool submit (this can take 5-10 min)..."
    xcrun notarytool submit "$ZIP" --keychain-profile notarytool --wait
    echo "release: xcrun stapler staple..."
    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"
fi

# Step 6/7 — gatekeeper assessment.
echo "release: spctl assess..."
if ! spctl -a -t exec -vv "$APP" 2>&1 | grep -q "Notarized Developer ID"; then
    if [ "${WDM_RELEASE_SKIP_NOTARIZE:-}" = "1" ]; then
        echo "release: spctl assessment expected to fail in skip-notarize mode (continuing)"
    else
        echo "release: spctl did not say 'Notarized Developer ID'" >&2
        exit 1
    fi
fi

# Step 8 — distribution zip. Always rebuild AFTER stapling so the
# distributed bundle ships with the offline-launch ticket. The earlier
# zip in step 5 was for notarytool submission only and predates the
# staple; ditto below replaces it with the stapled artifact.
DIST_ZIP="$ROOT/.build/release/WDMMac-${VERSION}.zip"
rm -f "$DIST_ZIP"
(cd "$ROOT/.build/release" && /usr/bin/ditto -c -k --sequesterRsrc --keepParent WDMMac.app "$DIST_ZIP")

# Step 9 — tag + push.
if [ "${WDM_RELEASE_TAG:-}" = "1" ]; then
    git tag -a "v$VERSION" -m "Release v$VERSION"
    git push origin main
    git push origin "v$VERSION"
    echo "release: tagged v$VERSION and pushed"
fi

echo "release: ✓ v$VERSION ready at $DIST_ZIP"
echo "  Bundle:   $APP"
echo "  CFShort:  $VERSION"
echo "  CFBuild:  $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
echo "  spctl:    $(spctl -a -t exec -vv "$APP" 2>&1 | head -1)"
