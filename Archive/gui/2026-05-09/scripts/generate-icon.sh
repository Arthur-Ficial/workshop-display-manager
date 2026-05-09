#!/usr/bin/env bash
# generate-icon.sh
#
# Renders a placeholder app icon for WDMMac.app at 1024x1024 (master)
# and slices it into every Apple icon slot (16/32/64/128/256/512/1024
# at @1x and @2x). Output: Sources/WDMMac/Resources/Assets.xcassets/
# AppIcon.appiconset/.
#
# Real-icon swap-in: replace `iconset/icon_1024x1024.png` with a
# pre-rendered 1024×1024 PNG and re-run this script.
#
# Dependencies: ImageMagick (`magick`) for the master render, `sips`
# for the slot resamples (built into macOS).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/Sources/WDMMac/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ASSETS"

MASTER="$ASSETS/icon_1024x1024.png"

if ! command -v magick >/dev/null 2>&1; then
    echo "generate-icon: magick (ImageMagick) missing — brew install imagemagick" >&2
    exit 2
fi

# Master 1024×1024: a soft green→teal gradient with the wdm wordmark.
# Use a fixed seed-y look so re-running produces the same image.
echo "generate-icon: rendering master 1024x1024..."
# macOS doesn't ship the literal "Helvetica-Bold" name to ImageMagick;
# point at the actual font file instead.
FONT="/System/Library/Fonts/Helvetica.ttc"
[ -e "$FONT" ] || FONT="/System/Library/Fonts/HelveticaNeue.ttc"
[ -e "$FONT" ] || FONT="/System/Library/Fonts/Avenir Next.ttc"
[ -e "$FONT" ] || FONT="/System/Library/Fonts/SFNS.ttf"

magick -size 1024x1024 \
    gradient:'#0a3d2e-#0d5a47' \
    -fill 'rgba(255,255,255,0.92)' \
    -font "$FONT" -pointsize 360 \
    -gravity center -annotate +0-30 'wdm' \
    -fill 'rgba(255,255,255,0.55)' \
    -pointsize 70 -gravity center -annotate +0+170 'workshop displays' \
    -density 300 \
    "$MASTER"

# Apple icon slot sizes (logical pixels × scale factors).
# (size, scale) -> filename
declare -a SLOTS=(
    "16  1x"
    "16  2x"
    "32  1x"
    "32  2x"
    "64  1x"
    "64  2x"
    "128 1x"
    "128 2x"
    "256 1x"
    "256 2x"
    "512 1x"
    "512 2x"
    "1024 1x"
)

echo "generate-icon: slicing slots..."
for slot in "${SLOTS[@]}"; do
    base=$(echo "$slot" | awk '{print $1}')
    sf=$(echo "$slot"   | awk '{print $2}')
    scale=${sf%x}
    px=$((base * scale))
    out="$ASSETS/icon_${base}x${base}@${sf}.png"
    sips -s format png -Z "$px" "$MASTER" --out "$out" >/dev/null
done

# Contents.json — manifest expected by actool.
cat > "$ASSETS/Contents.json" <<JSON
{
  "images" : [
    { "size" : "16x16", "idiom" : "mac", "filename" : "icon_16x16@1x.png", "scale" : "1x" },
    { "size" : "16x16", "idiom" : "mac", "filename" : "icon_16x16@2x.png", "scale" : "2x" },
    { "size" : "32x32", "idiom" : "mac", "filename" : "icon_32x32@1x.png", "scale" : "1x" },
    { "size" : "32x32", "idiom" : "mac", "filename" : "icon_32x32@2x.png", "scale" : "2x" },
    { "size" : "64x64", "idiom" : "mac", "filename" : "icon_64x64@1x.png", "scale" : "1x" },
    { "size" : "64x64", "idiom" : "mac", "filename" : "icon_64x64@2x.png", "scale" : "2x" },
    { "size" : "128x128", "idiom" : "mac", "filename" : "icon_128x128@1x.png", "scale" : "1x" },
    { "size" : "128x128", "idiom" : "mac", "filename" : "icon_128x128@2x.png", "scale" : "2x" },
    { "size" : "256x256", "idiom" : "mac", "filename" : "icon_256x256@1x.png", "scale" : "1x" },
    { "size" : "256x256", "idiom" : "mac", "filename" : "icon_256x256@2x.png", "scale" : "2x" },
    { "size" : "512x512", "idiom" : "mac", "filename" : "icon_512x512@1x.png", "scale" : "1x" },
    { "size" : "512x512", "idiom" : "mac", "filename" : "icon_512x512@2x.png", "scale" : "2x" },
    { "size" : "1024x1024", "idiom" : "mac", "filename" : "icon_1024x1024@1x.png", "scale" : "1x" }
  ],
  "info" : { "version" : 1, "author" : "wdm" }
}
JSON

echo "generate-icon: ✓ wrote $ASSETS"
ls -1 "$ASSETS" | head -20
