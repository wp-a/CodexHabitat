# Releasing Codex Habitat

Codex Habitat ships outside the Mac App Store as a hardened, Developer ID
signed, notarized DMG. Sparkle updates remain disabled unless a release build
contains an HTTPS feed URL and a valid EdDSA public key.

## One-time setup

1. Create a Developer ID Application certificate in the Apple Developer
   account and install it in the signing Keychain.
2. Resolve dependencies, then generate the Sparkle EdDSA key in the local
   Keychain:

   ```bash
   swift package resolve
   .build/artifacts/sparkle/Sparkle/bin/generate_keys
   ```

3. Record only the printed public key as `SPARKLE_PUBLIC_ED_KEY`. Never commit
   or log the private key.
4. Store notarization credentials in the Keychain:

   ```bash
   xcrun notarytool store-credentials codex-habitat-notary \
     --apple-id "$APPLE_ID" \
     --team-id "$APPLE_TEAM_ID" \
     --password "$APPLE_APP_SPECIFIC_PASSWORD"
   ```

## Local release

Use a monotonically increasing numeric `BUILD_NUMBER` for Sparkle version
comparison. The feed and all update download URLs must use HTTPS.

```bash
export VERSION=0.1.0
export BUILD_NUMBER=8
export CODE_SIGN_IDENTITY='Developer ID Application: Example (TEAMID)'
export SPARKLE_FEED_URL='https://example.com/codex-habitat/appcast.xml'
export SPARKLE_PUBLIC_ED_KEY='base64-public-key'

scripts/build-app.sh --release
scripts/package-dmg.sh
scripts/notarize.sh "dist/Codex-Habitat-$VERSION.dmg"
```

The build script signs Sparkle's nested services in the order required by its
official documentation, then signs the theme helper and main app. It never uses
`codesign --deep` for signing. `verify-release.sh` may use deep verification as
a diagnostic check.

## Signed appcast

Generate the appcast after notarization. Prefer a Keychain-held key. In CI,
pass a protected key file or standard input rather than a command-line secret:

```bash
SPARKLE_BIN=.build/artifacts/sparkle/Sparkle/bin
printf '%s' "$SPARKLE_PRIVATE_KEY" | \
  "$SPARKLE_BIN/generate_appcast" \
    --ed-key-file - \
    --download-url-prefix 'https://example.com/codex-habitat/' \
    -o dist/appcast.xml \
    dist
```

Because the app enables `SURequireSignedFeed` and
`SUVerifyUpdateBeforeExtraction`, edits to the appcast or release notes require
re-signing. Publish the DMG and signed appcast atomically.

## Verification

For an unsigned local smoke build:

```bash
scripts/render-codex-theme-fixtures.sh --check
scripts/build-app.sh --adhoc
scripts/package-dmg.sh
scripts/verify-release.sh "dist/Codex Habitat.app"
```

The fixture check is offline-only and uses the debug build. Release verification
must reject any helper containing the fixture command or its private payload
marker; neither may ship in the application bundle.

For a public build, require the update configuration and notarization ticket:

```bash
HABITAT_REQUIRE_UPDATES=1 \
HABITAT_REQUIRE_NOTARIZATION=1 \
scripts/verify-release.sh "dist/Codex Habitat.app"
```

Do not publish when any signature, architecture, entitlement, Sparkle key,
Gatekeeper, or stapling check fails.
