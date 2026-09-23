#!/usr/bin/env bash
# Build and run the host UI preview, then assemble a contact sheet.
#
#   ./build.sh [output-dir]      default: note/renders/ui
#
# Uses the Adafruit GFX sources PlatformIO already downloaded, so there is
# nothing extra to install beyond g++ and Pillow.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FW="$(cd "$HERE/../.." && pwd)"
GFX="$FW/.pio/libdeps/waveshare-esp32s3-epaper/Adafruit GFX Library"
# --check runs the regression checks instead of rendering: the invisible rules
# (live regions actually containing what moves, recording only ever ADDING ink)
# that a contact sheet cannot show you.
CHECK=""
if [ "${1:-}" = "--check" ]; then CHECK=1; shift; fi
OUT="${1:-$FW/../renders/ui}"

if [ ! -d "$GFX" ]; then
  echo "Adafruit GFX sources not found at:" >&2
  echo "  $GFX" >&2
  echo "Run 'pio run' in $FW once to fetch dependencies." >&2
  exit 1
fi

mkdir -p "$OUT" "$HERE/build"

g++ -std=c++17 -O1 -Wall -Wextra -Wno-unused-parameter \
    -DARDUINO=100 \
    -I"$HERE/shim" -I"$GFX" -I"$FW/src" \
    "$HERE/main.cpp" \
    "$FW/src/ui/widgets.cpp" \
    "$FW/src/ui/screens.cpp" \
    "$FW/src/app/tags.cpp" \
    "$GFX/Adafruit_GFX.cpp" \
    -o "$HERE/build/ui_preview"

if [ -n "$CHECK" ]; then
  exec "$HERE/build/ui_preview" --check
fi

"$HERE/build/ui_preview" "$OUT"
python3 "$HERE/contact_sheet.py" "$OUT"
