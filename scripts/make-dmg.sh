#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-$(tr -d '[:space:]' < "$ROOT/VERSION")}"
DIST="$ROOT/dist"
APP="$DIST/QuoteBar.app"
STAGE="$DIST/dmg-stage"
DMG="$DIST/QuoteBar-$VERSION.dmg"

if [[ ! -d "$APP" ]]; then
  echo "missing $APP; run scripts/package-app.sh first" >&2
  exit 1
fi

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/QuoteBar.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "QuoteBar $VERSION" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

rm -rf "$STAGE"
echo "DMG: $DMG"
ls -lh "$DMG"
