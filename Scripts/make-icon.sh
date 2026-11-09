#!/bin/bash
# make-icon.sh: rebuild the app icon from design/icon/ and copy it into the
# phone's and the watch's asset catalogues.
#
#   1. design/icon/generate.py writes AppIcon.svg, AppIcon-dark.svg and
#      AppIcon-tinted.svg (skipped with --keep-svg, for hand-made SVGs);
#   2. rsvg-convert renders each at 1024 x 1024 (brew install librsvg);
#   3. the PNGs go into App/Assets.xcassets/AppIcon.appiconset (all three) and
#      WatchApp/Assets.xcassets/AppIcon.appiconset (the default).
#
# The repository ships with placeholder artwork. Replace generate.py's
# drawing, or the SVGs with --keep-svg, then run this and commit the SVGs and
# PNGs together.
set -euo pipefail
cd "$(dirname "$0")/.."

ICON=design/icon
if [ "${1:-}" != "--keep-svg" ]; then
    python3 -I "$ICON/generate.py" "$ICON"
fi
command -v rsvg-convert >/dev/null || { echo "!!  rsvg-convert not found: brew install librsvg" >&2; exit 1; }
for variant in AppIcon AppIcon-dark AppIcon-tinted; do
    rsvg-convert -w 1024 -h 1024 "$ICON/$variant.svg" -o "$ICON/$variant.png"
    cp "$ICON/$variant.png" App/Assets.xcassets/AppIcon.appiconset/
done
cp "$ICON/AppIcon.png" WatchApp/Assets.xcassets/AppIcon.appiconset/
echo "==> icon rebuilt and copied into both asset catalogues"
