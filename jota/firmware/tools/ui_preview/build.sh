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
    "$GFX/Adafruit_GFX.cpp" \
    -o "$HERE/build/ui_preview"

"$HERE/build/ui_preview" "$OUT"
python3 "$HERE/contact_sheet.py" "$OUT"
