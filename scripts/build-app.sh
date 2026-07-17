#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"
SCRATCH_PATH="${HABITAT_SCRATCH_PATH:-/tmp/codex-habitat-release-build}"
APP="$OUTPUT_DIR/Codex Habitat.app"
APP_ID="com.codexhabitat.app"
HELPER_ID="com.codexhabitat.app.theme-bridge"

case "$MODE" in
    --adhoc)
        SIGN_IDENTITY="-"
        TIMESTAMP_ARGUMENT="--timestamp=none"
        APP_ENTITLEMENTS="$ROOT/Config/CodexHabitat.adhoc.entitlements"
        ;;
    --release)
        : "${CODE_SIGN_IDENTITY:?CODE_SIGN_IDENTITY is required for --release}"
        : "${SPARKLE_FEED_URL:?SPARKLE_FEED_URL is required for --release}"
        : "${SPARKLE_PUBLIC_ED_KEY:?SPARKLE_PUBLIC_ED_KEY is required for --release}"
        SIGN_IDENTITY="$CODE_SIGN_IDENTITY"
        TIMESTAMP_ARGUMENT="--timestamp"
        APP_ENTITLEMENTS="$ROOT/Config/CodexHabitat.entitlements"
        ;;
    *)
        echo "usage: scripts/build-app.sh --adhoc|--release" >&2
        exit 64
        ;;
esac

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.+][A-Za-z0-9.]+)?$ ]] \
    || { echo "build-app: invalid VERSION: $VERSION" >&2; exit 64; }
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] \
    || { echo "build-app: invalid BUILD_NUMBER: $BUILD_NUMBER" >&2; exit 64; }

mkdir -p "$OUTPUT_DIR" "$SCRATCH_PATH"
swift build \
    --package-path "$ROOT" \
    --scratch-path "$SCRATCH_PATH" \
    --configuration release
BIN_DIR="$(swift build \
    --package-path "$ROOT" \
    --scratch-path "$SCRATCH_PATH" \
    --configuration release \
    --show-bin-path)"

[[ -x "$BIN_DIR/CodexHabitatApp" ]] \
    || { echo "build-app: main executable missing" >&2; exit 1; }
[[ -x "$BIN_DIR/CodexHabitatThemeBridge" ]] \
    || { echo "build-app: theme bridge executable missing" >&2; exit 1; }
[[ -d "$BIN_DIR/Sparkle.framework" ]] \
    || { echo "build-app: Sparkle framework missing" >&2; exit 1; }

if [[ -e "$APP" ]]; then
    rm -r "$APP"
fi
mkdir -p \
    "$APP/Contents/MacOS" \
    "$APP/Contents/Helpers" \
    "$APP/Contents/Frameworks" \
    "$APP/Contents/Resources/Licenses"

install -m 755 "$BIN_DIR/CodexHabitatApp" "$APP/Contents/MacOS/CodexHabitatApp"
install -m 755 \
    "$BIN_DIR/CodexHabitatThemeBridge" \
    "$APP/Contents/Helpers/CodexHabitatThemeBridge"
install -m 644 "$ROOT/Config/Info.plist" "$APP/Contents/Info.plist"
install -m 644 \
    "$ROOT/THIRD_PARTY_NOTICES.md" \
    "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
install -m 644 "$ROOT/Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' >"$APP/Contents/PkgInfo"

mkdir -p "$APP/Contents/Resources/Resources" "$APP/Contents/Resources/SwiftPM"
ditto \
    "$ROOT/Sources/CodexHabitatApp/Resources" \
    "$APP/Contents/Resources/Resources"
ditto \
    "$ROOT/Sources/CodexHabitatThemeBridge/Resources" \
    "$APP/Contents/Resources/Resources"
for localization in "$ROOT/Sources/CodexHabitatApp/Resources"/*.lproj; do
    [[ -d "$localization" ]] || continue
    ditto "$localization" "$APP/Contents/Resources/$(basename "$localization")"
done
if [[ -d "$BIN_DIR/ZIPFoundation_ZIPFoundation.bundle" ]]; then
    ditto \
        "$BIN_DIR/ZIPFoundation_ZIPFoundation.bundle" \
        "$APP/Contents/Resources/SwiftPM/ZIPFoundation_ZIPFoundation.bundle"
fi
ditto "$BIN_DIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"

sparkle_license="$(find "$SCRATCH_PATH/checkouts" \
    -maxdepth 3 -path '*/Sparkle/LICENSE' -type f -print -quit)"
[[ -n "$sparkle_license" ]] \
    || { echo "build-app: Sparkle license missing" >&2; exit 1; }
install -m 644 \
    "$sparkle_license" \
    "$APP/Contents/Resources/Licenses/Sparkle-LICENSE.txt"

PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"
if [[ "$MODE" == "--release" ]]; then
    [[ "$SPARKLE_FEED_URL" == https://* ]] \
        || { echo "build-app: Sparkle feed must use HTTPS" >&2; exit 64; }
    [[ "$SPARKLE_FEED_URL" != *\?* \
        && "$SPARKLE_FEED_URL" != *\#* \
        && "$SPARKLE_FEED_URL" != *@* ]] \
        || { echo "build-app: Sparkle feed cannot contain credentials, query, or fragment" >&2; exit 64; }
    key_size="$(printf '%s' "$SPARKLE_PUBLIC_ED_KEY" | base64 -D 2>/dev/null | wc -c | tr -d ' ')"
    [[ "$key_size" == "32" ]] \
        || { echo "build-app: Sparkle EdDSA public key must decode to 32 bytes" >&2; exit 64; }
    /usr/libexec/PlistBuddy -c 'Set :HabitatUpdatesEnabled true' "$PLIST"
    /usr/libexec/PlistBuddy -c "Set :SUFeedURL $SPARKLE_FEED_URL" "$PLIST"
    /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $SPARKLE_PUBLIC_ED_KEY" "$PLIST"
else
    /usr/libexec/PlistBuddy -c 'Set :HabitatUpdatesEnabled false' "$PLIST"
    /usr/libexec/PlistBuddy -c 'Set :SUFeedURL ' "$PLIST"
    /usr/libexec/PlistBuddy -c 'Set :SUPublicEDKey ' "$PLIST"
fi
plutil -lint "$PLIST" >/dev/null

remove_development_rpaths() {
    local binary="$1"
    while IFS= read -r rpath; do
        case "$rpath" in
            /Applications/Xcode*|/Users/*|/home/runner/*|/private/tmp/*)
                install_name_tool -delete_rpath "$rpath" "$binary"
                ;;
        esac
    done < <(otool -l "$binary" | awk '
        $1 == "cmd" && $2 == "LC_RPATH" { getline; getline; print $2 }
    ')
}

MAIN="$APP/Contents/MacOS/CodexHabitatApp"
HELPER="$APP/Contents/Helpers/CodexHabitatThemeBridge"
remove_development_rpaths "$MAIN"
remove_development_rpaths "$HELPER"
if ! otool -l "$MAIN" | grep -F '@executable_path/../Frameworks' >/dev/null; then
    install_name_tool -add_rpath '@executable_path/../Frameworks' "$MAIN"
fi
strip -S "$MAIN" "$HELPER"

SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
CODESIGN=(codesign --force --sign "$SIGN_IDENTITY" --options runtime "$TIMESTAMP_ARGUMENT")
"${CODESIGN[@]}" "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
"${CODESIGN[@]}" \
    --preserve-metadata=entitlements \
    "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
"${CODESIGN[@]}" "$SPARKLE/Versions/B/Autoupdate"
"${CODESIGN[@]}" "$SPARKLE/Versions/B/Updater.app"
"${CODESIGN[@]}" "$SPARKLE"
"${CODESIGN[@]}" \
    --identifier "$HELPER_ID" \
    --entitlements "$ROOT/Config/ThemeBridge.entitlements" \
    "$HELPER"
"${CODESIGN[@]}" \
    --identifier "$APP_ID" \
    --entitlements "$APP_ENTITLEMENTS" \
    "$APP"

if [[ "$MODE" == "--release" ]]; then
    HABITAT_REQUIRE_UPDATES=1 "$ROOT/scripts/verify-release.sh" "$APP"
else
    "$ROOT/scripts/verify-release.sh" "$APP"
fi

echo "build-app: created $APP"
