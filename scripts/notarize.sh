#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG="${1:-}"
APP="${APP_PATH:-$ROOT/dist/Codex Habitat.app}"

[[ -n "$DMG" ]] || { echo "usage: scripts/notarize.sh <dmg>" >&2; exit 64; }
[[ -f "$DMG" ]] || { echo "notarize: DMG missing: $DMG" >&2; exit 1; }
[[ -d "$APP" ]] || { echo "notarize: app missing: $APP" >&2; exit 1; }

signature="$(codesign -d --verbose=4 "$APP" 2>&1)"
[[ "$signature" == *"Authority=Developer ID Application:"* ]] \
    || { echo "notarize: Developer ID application signature required" >&2; exit 1; }

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit \
        "$DMG" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait
else
    : "${APPLE_ID:?APPLE_ID or NOTARY_PROFILE is required}"
    : "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"
    : "${APPLE_APP_SPECIFIC_PASSWORD:?APPLE_APP_SPECIFIC_PASSWORD is required}"
    xcrun notarytool submit \
        "$DMG" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_SPECIFIC_PASSWORD" \
        --wait
fi

xcrun stapler staple "$APP"
xcrun stapler staple "$DMG"
xcrun stapler validate "$APP"
xcrun stapler validate "$DMG"
spctl --assess --type execute --verbose=2 "$APP"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

HABITAT_REQUIRE_UPDATES=1 \
HABITAT_REQUIRE_NOTARIZATION=1 \
    "$ROOT/scripts/verify-release.sh" "$APP"

echo "notarize: accepted and stapled $DMG"
