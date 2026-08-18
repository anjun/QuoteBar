#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-$(tr -d '[:space:]' < "$ROOT/VERSION")}"
BUILD="$(tr -d '[:space:]' < "$ROOT/BUILD")"
DIST="$ROOT/dist"
APP="$DIST/QuoteBar.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

cd "$ROOT"
mkdir -p "$DIST"

rm -rf "$APP"
mkdir -p "$BIN_DIR" "$RES_DIR"

if [[ "${NATIVE:-0}" == "1" ]]; then
  echo "Building native QuoteBar $VERSION ($BUILD)"
  swift build -c release --product QuoteBar
  cp "$ROOT/.build/release/QuoteBar" "$BIN_DIR/QuoteBar"
else
  echo "Building universal QuoteBar $VERSION ($BUILD)"
  swift build -c release --arch arm64 --product QuoteBar
  swift build -c release --arch x86_64 --product QuoteBar
  lipo -create \
    "$ROOT/.build/arm64-apple-macosx/release/QuoteBar" \
    "$ROOT/.build/x86_64-apple-macosx/release/QuoteBar" \
    -output "$BIN_DIR/QuoteBar"
fi
chmod +x "$BIN_DIR/QuoteBar"

plutil -replace CFBundleShortVersionString -string "$VERSION" "$ROOT/Resources/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD" "$ROOT/Resources/Info.plist"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$RES_DIR/AppIcon.icns"
fi
echo -n 'APPL????' > "$APP/Contents/PkgInfo"

echo "App: $APP"
file "$BIN_DIR/QuoteBar"
