#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/dist/Codex Habitat.app}"
EXPECTED_APP_ID="com.codexhabitat.app"
EXPECTED_HELPER_ID="com.codexhabitat.app.theme-bridge"

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

app_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
[[ "$app_id" == "$EXPECTED_APP_ID" ]] || fail "unexpected app bundle ID: $app_id"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.+][A-Za-z0-9.]+)?$ ]] \
    || fail "invalid marketing version: $version"
[[ "$build" =~ ^[0-9]+$ ]] || fail "invalid bundle build: $build"
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
trap 'rm -f "$entitlements_file"' EXIT
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

if otool -l "$MAIN" "$HELPER" \
    | grep -Eq '/Applications/Xcode|/Users/|/home/runner|/private/tmp/'; then
    fail "development runpath embedded"
fi
if strings "$MAIN" "$HELPER" | grep -Eq '/Users/|/home/runner/'; then
    fail "developer home path embedded"
fi
if strings "$MAIN" | grep -Eq -- '--remote-debugging-(address|port)'; then
    fail "CDP launch flags leaked into the main application"
fi
strings "$HELPER" | grep -F -- '--remote-debugging-address=127.0.0.1' >/dev/null \
    || fail "helper loopback-only CDP address missing"
if strings "$HELPER" | grep -F -- '--remote-debugging-address=0.0.0.0' >/dev/null; then
    fail "helper contains a wildcard CDP address"
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
