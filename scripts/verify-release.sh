#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/dist/Codex Habitat.app}"
EXPECTED_APP_ID="com.codexhabitat.app"
EXPECTED_HELPER_ID="com.codexhabitat.app.theme-bridge"
EXPECTED_BUILD_NUMBER="${HABITAT_EXPECTED_BUILD_NUMBER:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/Config/Info.plist")}"

fail() {
    echo "verify-release: FAIL: $*" >&2
    exit 1
}

pass() {
    echo "verify-release: PASS: $*"
}

[[ -d "$APP" ]] || fail "app bundle not found: $APP"

PLIST="$APP/Contents/Info.plist"
MAIN="$APP/Contents/MacOS/CodexHabitatApp"
HELPER="$APP/Contents/Helpers/CodexHabitatThemeBridge"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"

[[ -f "$PLIST" ]] || fail "Info.plist missing"
[[ -x "$MAIN" ]] || fail "main executable missing"
[[ -x "$HELPER" ]] || fail "theme bridge helper missing"
[[ -d "$SPARKLE" ]] || fail "Sparkle framework missing"
[[ -f "$APP/Contents/Resources/Resources/Themes/workbench/habitat.json" ]] \
    || fail "app resources missing"
[[ -f "$APP/Contents/Resources/Resources/compatibility.json" ]] \
    || fail "theme bridge resources missing"
[[ -f "$APP/Contents/Resources/AppIcon.icns" ]] || fail "app icon missing"

THEME_ROOT="$APP/Contents/Resources/Resources/Themes"
EXPECTED_THEMES=(
    workbench night-shift arcade-signal quiet-garden
    retro-messenger green-chat-desk cyber-cafe win95-workbench
    crimson-mecha aqua-pulse candy-combo gold-rush
    harvest-homestead solar-ki-arena moonlit-shinobi grand-ocean-crew
    elemental-companions walled-vanguard arcane-academy hero-training-campus
    nebula-vanguard spirit-lantern-town block-frontier turbo-striker
)
[[ -d "$THEME_ROOT" ]] || fail "theme library missing"
for theme_id in "${EXPECTED_THEMES[@]}"; do
    theme_directory="$THEME_ROOT/$theme_id"
    [[ -d "$theme_directory" ]] || fail "theme directory missing: $theme_id"
    for filename in habitat.json background.jpg preview.png LICENSE; do
        [[ -f "$theme_directory/$filename" ]] \
            || fail "theme resource missing: $theme_id/$filename"
    done
done
theme_count="$(find "$THEME_ROOT" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
[[ "$theme_count" == "${#EXPECTED_THEMES[@]}" ]] \
    || fail "unexpected theme directory count: $theme_count"
for theme_directory in "$THEME_ROOT"/*; do
    [[ -d "$theme_directory" ]] || continue
    theme_id="$(basename "$theme_directory")"
    [[ " ${EXPECTED_THEMES[*]} " == *" $theme_id "* ]] \
        || fail "unexpected theme directory: $theme_id"
done
if find "$THEME_ROOT" -type f \( \
    -iname '*source*' -o -iname '*raw*' -o -iname '*reference*' \
    -o -iname '*prompt*' -o -iname '*provenance*' -o -iname '*.psd' -o -iname '*.xcf' \
\) -print -quit | grep -q .; then
    fail "development theme artifact packaged"
fi
pass "twenty-four bounded theme resource sets"

app_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
[[ "$app_id" == "$EXPECTED_APP_ID" ]] || fail "unexpected app bundle ID: $app_id"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.+][A-Za-z0-9.]+)?$ ]] \
    || fail "invalid marketing version: $version"
[[ "$build" =~ ^[0-9]+$ ]] || fail "invalid bundle build: $build"
[[ "$EXPECTED_BUILD_NUMBER" =~ ^[0-9]+$ ]] \
    || fail "invalid expected bundle build: $EXPECTED_BUILD_NUMBER"
[[ "$build" == "$EXPECTED_BUILD_NUMBER" ]] \
    || fail "bundle build does not match expected build: $build != $EXPECTED_BUILD_NUMBER"
pass "bundle identity and versions"

required_archs="${HABITAT_REQUIRED_ARCHS:-$(uname -m)}"
for binary in "$MAIN" "$HELPER"; do
    archs="$(lipo -archs "$binary")"
    for required in $required_archs; do
        [[ " $archs " == *" $required "* ]] \
            || fail "$(basename "$binary") is missing architecture $required"
    done
done
pass "required architectures: $required_archs"

codesign --verify --deep --strict --verbose=2 "$APP" >/dev/null 2>&1 \
    || fail "app signature verification failed"
codesign --verify --strict --verbose=2 "$HELPER" >/dev/null 2>&1 \
    || fail "helper signature verification failed"
codesign --verify --deep --strict --verbose=2 "$SPARKLE" >/dev/null 2>&1 \
    || fail "Sparkle signature verification failed"

app_signature="$(codesign -d --verbose=4 "$APP" 2>&1)"
helper_signature="$(codesign -d --verbose=4 "$HELPER" 2>&1)"
[[ "$app_signature" == *"Identifier=$EXPECTED_APP_ID"* ]] \
    || fail "app signature identifier mismatch"
[[ "$helper_signature" == *"Identifier=$EXPECTED_HELPER_ID"* ]] \
    || fail "helper signature identifier mismatch"
[[ "$app_signature" == *"runtime"* ]] || fail "app hardened runtime missing"
[[ "$helper_signature" == *"runtime"* ]] || fail "helper hardened runtime missing"
pass "strict signatures and hardened runtime"

entitlements_file="$(mktemp)"
otool_output="$(mktemp)"
all_strings="$(mktemp)"
main_strings="$(mktemp)"
helper_strings="$(mktemp)"
key_file=""
trap 'rm -f "$entitlements_file" "$otool_output" "$all_strings" "$main_strings" "$helper_strings"; [[ -z "$key_file" ]] || rm -f "$key_file"' EXIT
codesign -d --entitlements :- "$APP" >"$entitlements_file" 2>/dev/null \
    || fail "could not inspect app entitlements"
if grep -Eq 'get-task-allow|allow-unsigned-executable-memory' "$entitlements_file"; then
    fail "dangerous release entitlement present"
fi
if grep -F 'disable-library-validation' "$entitlements_file" >/dev/null \
    && [[ "$app_signature" != *"Signature=adhoc"* ]]; then
    fail "library validation is disabled in a non-ad-hoc build"
fi
pass "release entitlements"

otool -l "$MAIN" "$HELPER" >"$otool_output"
strings "$MAIN" "$HELPER" >"$all_strings"
strings "$MAIN" >"$main_strings"
strings "$HELPER" >"$helper_strings"
if grep -Eq '^[[:space:]]+path (/Applications/Xcode|/Users/|/home/runner|/private/tmp/)' "$otool_output"; then
    fail "development runpath embedded"
fi
if grep -Eq '/Users/|/home/runner/' "$all_strings"; then
    fail "developer home path embedded"
fi
if grep -Eq -- '--remote-debugging-(address|port)' "$main_strings"; then
    fail "CDP launch flags leaked into the main application"
fi
grep -F -- '--remote-debugging-address=127.0.0.1' "$helper_strings" >/dev/null \
    || fail "helper loopback-only CDP address missing"
if grep -F -- '--remote-debugging-address=0.0.0.0' "$helper_strings" >/dev/null; then
    fail "helper contains a wildcard CDP address"
fi
if grep -F -- 'offline-fixture' "$helper_strings" >/dev/null \
    || grep -F -- 'offline-theme-fixture-payload-v1' "$helper_strings" >/dev/null; then
    fail "debug-only offline fixture command leaked into release helper"
fi
pass "release paths and CDP isolation"

updates_enabled="$(/usr/libexec/PlistBuddy -c 'Print :HabitatUpdatesEnabled' "$PLIST")"
if [[ "$updates_enabled" == "true" ]]; then
    feed_url="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$PLIST")"
    public_key="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$PLIST")"
    signed_feed="$(/usr/libexec/PlistBuddy -c 'Print :SURequireSignedFeed' "$PLIST")"
    verify_before_extract="$(/usr/libexec/PlistBuddy -c 'Print :SUVerifyUpdateBeforeExtraction' "$PLIST")"
    [[ "$feed_url" == https://* ]] || fail "update feed is not HTTPS"
    [[ "$feed_url" != *\?* && "$feed_url" != *\#* && "$feed_url" != *@* ]] \
        || fail "update feed contains credentials, query, or fragment"
    [[ "$signed_feed" == "true" && "$verify_before_extract" == "true" ]] \
        || fail "signed feed verification is not enforced"
    key_file="$(mktemp)"
    printf '%s' "$public_key" | base64 -D >"$key_file" 2>/dev/null \
        || fail "Sparkle EdDSA public key is not base64"
    [[ "$(wc -c <"$key_file" | tr -d ' ')" == "32" ]] \
        || fail "Sparkle EdDSA public key is not 32 bytes"
    rm -f "$key_file"
    pass "signed Sparkle update configuration"
else
    [[ "${HABITAT_REQUIRE_UPDATES:-0}" != "1" ]] \
        || fail "release requires updates but they are disabled"
    pass "updates intentionally disabled"
fi

if [[ "${HABITAT_REQUIRE_NOTARIZATION:-0}" == "1" ]]; then
    xcrun stapler validate "$APP" >/dev/null 2>&1 \
        || fail "notarization ticket is missing or invalid"
    spctl --assess --type execute --verbose=2 "$APP" >/dev/null 2>&1 \
        || fail "Gatekeeper assessment failed"
    pass "notarization and Gatekeeper"
fi

pass "Codex Habitat release bundle"
