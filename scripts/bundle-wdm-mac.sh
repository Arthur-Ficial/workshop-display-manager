#!/usr/bin/env bash
# Wraps the wdm-mac SwiftPM executable in a real .app bundle so macOS 26
# grants it Liquid Glass treatment. The Info.plist is the trigger:
#   - LSMinimumSystemVersion = 26.0     (deployment target → opt in)
#   - DTPlatformName / DTSDKName        (built against macOS 26 SDK)
#   - LSApplicationCategoryType         (proper app categorisation)
#   - NO UIDesignRequiresCompatibility  (= NOT opted out of Liquid Glass)
#
# Usage:
#   ./scripts/bundle-wdm-mac.sh [debug|release]
#
# Prints the absolute .app path on stdout so callers can `open "$(./scripts/...)"`.
set -euo pipefail

CFG="${1:-debug}"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN="$ROOT/.build/$CFG/wdm-mac"
APP="$ROOT/.build/$CFG/WDMMac.app"

if [[ ! -x "$BIN" ]]; then
  echo "bundle-wdm-mac: $BIN missing — build first (swift build -c $CFG)" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/wdm-mac"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>wdm-mac</string>
    <key>CFBundleIdentifier</key>
    <string>com.fullstackoptimization.wdm.mac</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Workshop Display Manager</string>
    <key>CFBundleDisplayName</key>
    <string>Workshop Display Manager</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>DTPlatformName</key>
    <string>macosx</string>
    <key>DTSDKName</key>
    <string>macosx26.4</string>
    <key>DTPlatformVersion</key>
    <string>26.4</string>
</dict>
</plist>
PLIST

# Quick sanity: there must NOT be an opt-out key.
if /usr/libexec/PlistBuddy -c 'Print :UIDesignRequiresCompatibility' \
   "$APP/Contents/Info.plist" 2>/dev/null | grep -q true; then
  echo "bundle-wdm-mac: Info.plist must NOT contain UIDesignRequiresCompatibility=YES" >&2
  exit 1
fi

# Validate the plist
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "$APP"
