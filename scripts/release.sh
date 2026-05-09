#!/usr/bin/env bash
# release.sh <version>
#
# Reproducible CLI release pipeline:
#   1. Refuse dirty working trees.
#   2. Rewrite Sources/WDMCore/Version.swift.
#   3. Build the release wdm binary with warnings as errors.
#   4. Regenerate man/wdm.1 from the binary.
#   5. Create .build/release/wdm-<version>-macos-arm64.tar.gz.
#   6. Optionally tag and push when WDM_RELEASE_TAG=1.
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "usage: release.sh <version>   (e.g. release.sh 2.1.0)" >&2
    exit 2
fi

VERSION="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$'; then
    echo "release: '$VERSION' is not a semver token" >&2
    exit 2
fi

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "release: working tree has uncommitted changes — commit/stash first." >&2
    git status --short >&2
    exit 1
fi

VERSION_FILE="$ROOT/Sources/WDMCore/Version.swift"
if ! grep -q 'public static let current:' "$VERSION_FILE"; then
    echo "release: $VERSION_FILE missing 'public static let current'" >&2
    exit 1
fi

sed -i.bak -E \
    "s|public static let current: String = \"[^\"]+\"|public static let current: String = \"$VERSION\"|" \
    "$VERSION_FILE"
rm -f "${VERSION_FILE}.bak"

echo "release: building wdm..."
make release

echo "release: regenerating man/wdm.1..."
mkdir -p man
.build/release/wdm manpage > man/wdm.1

if ! git diff --quiet "$VERSION_FILE" man/wdm.1; then
    git add "$VERSION_FILE" man/wdm.1
    git commit -m "release: bump Version.current to $VERSION" >/dev/null
fi

DIST_DIR="$ROOT/.build/release/dist"
ARCHIVE="$ROOT/.build/release/wdm-${VERSION}-macos-arm64.tar.gz"
rm -rf "$DIST_DIR" "$ARCHIVE"
mkdir -p "$DIST_DIR"
cp "$ROOT/.build/release/wdm" "$DIST_DIR/wdm"
cp "$ROOT/README.md" "$DIST_DIR/README.md"
cp "$ROOT/LICENSE" "$DIST_DIR/LICENSE"
(cd "$DIST_DIR" && tar -czf "$ARCHIVE" wdm README.md LICENSE)

if [ "${WDM_RELEASE_TAG:-}" = "1" ]; then
    git tag -a "v$VERSION" -m "Release v$VERSION"
    git push origin main
    git push origin "v$VERSION"
    echo "release: tagged v$VERSION and pushed"
fi

echo "release: ✓ v$VERSION ready"
echo "  Binary:  $ROOT/.build/release/wdm"
echo "  Archive: $ARCHIVE"
