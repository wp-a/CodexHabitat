#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${APP_PATH:-$ROOT/dist/Codex Habitat.app}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"

[[ -d "$APP" ]] || { echo "package-dmg: app bundle missing: $APP" >&2; exit 1; }
"$ROOT/scripts/verify-release.sh" "$APP"

VERSION="$(/usr/libexec/PlistBuddy \
    -c 'Print :CFBundleShortVersionString' \
    "$APP/Contents/Info.plist")"
DMG="$OUTPUT_DIR/Codex-Habitat-$VERSION.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

ditto "$APP" "$STAGING/Codex Habitat.app"
ln -s /Applications "$STAGING/Applications"
if [[ -e "$DMG" ]]; then
    rm "$DMG"
fi
hdiutil create \
    -volname "Codex Habitat" \
    -srcfolder "$STAGING" \
    -format UDZO \
    -ov \
    "$DMG" >/dev/null

if [[ -n "${CODE_SIGN_IDENTITY:-}" && "$CODE_SIGN_IDENTITY" != "-" ]]; then
    codesign \
        --force \
        --sign "$CODE_SIGN_IDENTITY" \
        --timestamp \
        "$DMG"
    codesign --verify --verbose=2 "$DMG"
fi

echo "package-dmg: created $DMG"
