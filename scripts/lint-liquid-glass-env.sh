#!/usr/bin/env bash
# Liquid Glass environment linter — verifies the toolchain has every
# requirement to render real Tahoe Liquid Glass.
#
# Required:
#   - macOS 26.0+ (Tahoe) — runtime requirement for NSGlassEffectView
#   - Xcode 26.0+ — provides the macOS 26 SDK
#   - Swift 6.0+ (we use 6.3) — language support
#   - macOS 26+ SDK present at /Applications/Xcode.app/.../MacOSX*.sdk
#   - NSGlassEffectView.h present in that SDK
#   - SwiftUI Glass struct in SwiftUICore.swiftinterface
#   - NSBezelStyleGlass present in NSButtonCell.h
#
# Run: make lint-glass-env
set -euo pipefail

fail=0
ok()   { printf "  ✓ %s\n" "$*"; }
miss() { printf "  ✘ %s\n" "$*" >&2; fail=$((fail + 1)); }

echo "Liquid Glass environment check"

# 1. macOS version
osv=$(sw_vers -productVersion)
osmajor=${osv%%.*}
if [[ "$osmajor" -ge 26 ]]; then
  ok "macOS $osv (Tahoe) — runtime supports NSGlassEffectView"
else
  miss "macOS $osv — Liquid Glass requires macOS 26 (Tahoe)+"
fi

# 2. Xcode version
if xv=$(xcodebuild -version 2>/dev/null | head -1); then
  xmajor=$(echo "$xv" | awk '{print $2}' | cut -d. -f1)
  if [[ "$xmajor" -ge 26 ]]; then
    ok "$xv — has the macOS 26 SDK"
  else
    miss "$xv — need Xcode 26+ for the macOS 26 SDK"
  fi
else
  miss "xcodebuild not on PATH — Xcode command-line tools required"
fi

# 3. Swift version
swv=$(xcrun swift --version 2>/dev/null | head -1 | grep -oE 'version [0-9.]+' | awk '{print $2}')
if [[ -n "$swv" ]]; then
  swmajor=${swv%%.*}
  if [[ "$swmajor" -ge 6 ]]; then
    ok "Swift $swv"
  else
    miss "Swift $swv — need Swift 6+"
  fi
else
  miss "Swift compiler not detected"
fi

# 4. macOS 26+ SDK present
sdk_path=$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)
if [[ -d "$sdk_path" ]]; then
  sdk_ver=$(xcrun --sdk macosx --show-sdk-version 2>/dev/null || echo "?")
  sdk_major=${sdk_ver%%.*}
  if [[ "$sdk_major" -ge 26 ]]; then
    ok "macOS SDK $sdk_ver at $sdk_path"
  else
    miss "macOS SDK $sdk_ver — need 26+"
  fi
else
  miss "macOS SDK not found via xcrun"
fi

# 5. NSGlassEffectView header
hdr="$sdk_path/System/Library/Frameworks/AppKit.framework/Headers/NSGlassEffectView.h"
if [[ -f "$hdr" ]]; then
  ok "NSGlassEffectView header present (AppKit)"
else
  miss "NSGlassEffectView.h missing — SDK doesn't have AppKit Liquid Glass primitive"
fi

# 6. NSBezelStyleGlass for button bezels
bezel=$(grep -E "NSBezelStyleGlass" \
  "$sdk_path/System/Library/Frameworks/AppKit.framework/Headers/NSButtonCell.h" 2>/dev/null || true)
if [[ -n "$bezel" ]]; then
  ok "NSBezelStyleGlass present (Tahoe button bezel)"
else
  miss "NSBezelStyleGlass missing — Tahoe button styles unavailable"
fi

# 7. SwiftUI Glass struct
ifc=$(find "$sdk_path/System/Library/Frameworks/SwiftUICore.framework" \
  -name "arm64e-apple-macos.swiftinterface" 2>/dev/null | head -1)
if [[ -f "$ifc" ]] && grep -qE "public struct Glass " "$ifc"; then
  ok "SwiftUI Glass struct present (SwiftUICore.swiftinterface)"
else
  miss "SwiftUI Glass struct missing — .glassEffect() unavailable"
fi

# 8. swift-argument-parser presence (we don't use it, but document)
# (skip — not required)

# 9. Architecture sanity
arch_now=$(uname -m)
if [[ "$arch_now" == "arm64" ]]; then
  ok "Apple Silicon ($arch_now) — Liquid Glass is GPU-accelerated"
else
  printf "  ⚠ %s\n" "Running on $arch_now — Liquid Glass works but is heavier on Intel"
fi

# 10. Verify the wdm-mac binary, if built, was compiled against arm64-macosx26
bin="$(cd "$(dirname "$0")/.." && pwd)/.build/debug/wdm-mac"
if [[ -x "$bin" ]]; then
  if otool -l "$bin" 2>/dev/null | grep -A2 LC_BUILD_VERSION | grep -q "minos 26"; then
    ok "wdm-mac binary built with macOS 26 deployment target"
  else
    miso=$(otool -l "$bin" | grep -A2 LC_BUILD_VERSION | grep -E "minos" | head -1 | awk '{print $2}')
    printf "  ⚠ %s\n" "wdm-mac built with deployment target ${miso:-unknown} — runtime opt-in only"
  fi
fi

echo
if [[ "$fail" -gt 0 ]]; then
  echo "lint-glass-env: $fail blocker(s) — fix before expecting Liquid Glass" >&2
  exit 1
fi
echo "lint-glass-env: ✓ all requirements satisfied"
