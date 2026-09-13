#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$PROJECT_DIR/Sources/UnfoldMyMacKit/Resources/Brand/UnfoldMyMacLogo.png"
ICONSET="$PROJECT_DIR/.build/UnfoldMyMac.iconset"
OUTPUT="$PROJECT_DIR/.build/UnfoldMyMac.icns"
MARK="$PROJECT_DIR/Sources/UnfoldMyMacKit/Resources/Brand/UnfoldMyMacMark.png"
if [ ! -f "$SOURCE" ]; then
  echo "Missing app logo: $SOURCE" >&2
  exit 1
fi
# The 256-pixel mark the app draws in its sidebar, so the full logo is never decoded for a 32-point glyph.
if [ ! -f "$MARK" ] || [ "$SOURCE" -nt "$MARK" ]; then
  /usr/bin/sips -z 256 256 "$SOURCE" --out "$MARK" >/dev/null
fi
if [ ! -f "$OUTPUT" ] || [ "$SOURCE" -nt "$OUTPUT" ]; then
  mkdir -p "$ICONSET"
  for SIZE in 16 32 128 256 512; do
    /usr/bin/sips -z "$SIZE" "$SIZE" "$SOURCE" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    /usr/bin/sips -z "$DOUBLE" "$DOUBLE" "$SOURCE" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
  done
  /usr/bin/iconutil --convert icns "$ICONSET" --output "$OUTPUT"
fi
