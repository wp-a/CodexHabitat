# Codex Main-Window Impact Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make all twenty-four themes compile to visually forceful, route-aware whole-window Codex scenes and prove the result with a deterministic offline main-window fixture.

**Architecture:** Deepen the existing typed home/task scene model, make `BuiltInThemeCatalog` the canonical built-in appearance source, expand narrow compatibility profiles with statically verified host surfaces, and compile one continuous art canvas plus route-specific material layers. A debug-only offline fixture path feeds the real resolver/compiler/installer output to pinned Chromium; it never constructs a live Codex session and is excluded from release builds.

**Tech Stack:** Swift 6.2, Swift Testing, SwiftUI/AppKit, Foundation/ImageIO, loopback CDP, JSON Schema, Node.js with pinned Playwright Chromium for offline-only QA, macOS screenshot and release tooling.

---

### Task 1: Lock the built-in catalog as the appearance authority

**Files:**
- Modify: `Tests/HabitatCoreTests/BuiltInThemeCatalogTests.swift`
- Modify: `Tests/CodexHabitatAppTests/BundledThemeModelTests.swift`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/*/habitat.json`

**Step 1: Write a failing canonical-manifest comparison test**

Add a test helper that compares every palette and resolved appearance field to
`BuiltInThemeCatalog` rather than only checking IDs and hashes. Add one test for
all packaged manifests and one deliberately changed in-memory appearance that
proves the helper reports the exact changed field.

```swift
@Test
func allBuiltInManifestsMatchTheCanonicalCatalog() throws {
    #expect(BuiltInThemeCatalog.all.count == 24)
    for definition in BuiltInThemeCatalog.all {
        let manifest = try packagedManifest(id: definition.id)
        #expect(catalogMismatches(definition, manifest).isEmpty)
    }
}

@Test
func canonicalComparisonReportsAppearanceDrift() throws {
    let definition = try #require(BuiltInThemeCatalog.definition(id: "workbench"))
    let changed = manifestCopy(id: "workbench", taskStrength: 0.11)
    #expect(catalogMismatches(definition, changed) == ["theme.taskStrength"])
}
```

**Step 2: Run the test and verify RED**

Run:

```bash
swift test --filter 'allBuiltInManifestsMatchTheCanonicalCatalog|canonicalComparisonReportsAppearanceDrift'
```

Expected: compile failure because the exhaustive comparison helper does not exist.

**Step 3: Implement the exhaustive comparison helper**

Decode manifests through the public `ManifestDecoder`. Compare the complete
palette and every stored and resolved appearance field. Return stable field
paths so a mismatch identifies exactly what must change. The helper must not
normalize away missing optional values that change resolved behavior.

**Step 4: Synchronize the current catalog and verify GREEN**

Update current manifests only if the exhaustive test reports a real mismatch,
using structured JSON editing and preserving identity, assets, hashes, license,
pets, and widgets. Then rerun the focused tests.

```bash
swift test --filter 'allBuiltInManifestsMatchTheCanonicalCatalog|canonicalComparisonReportsAppearanceDrift'
```

Expected: PASS. Do not add placeholder treatments in this task; Task 3 adds the
separate failing requirement that all built-ins declare explicit scenes.

**Step 5: Commit**

```bash
git add Tests/HabitatCoreTests/BuiltInThemeCatalogTests.swift \
  Tests/CodexHabitatAppTests/BundledThemeModelTests.swift \
  Sources/CodexHabitatApp/Resources/Themes
git commit -m "test: lock canonical built-in manifests"
```

### Task 2: Extend the typed route-composition contract

**Files:**
- Modify: `Sources/HabitatCore/Theme/HabitatThemeAppearance.swift`
- Modify: `Sources/ResourceKit/Manifest/ManifestDecoder.swift`
- Modify: `Sources/ResourceKit/Validation/ManifestValidator.swift`
- Modify: `Sources/ResourceKit/Creation/ThemePackageBuilder.swift`
- Modify: `Schemas/habitat-pack-v1.schema.json`
- Modify: `Tests/ResourceKitTests/ManifestValidatorTests.swift`
- Modify: `Tests/ResourceKitTests/ThemePackageBuilderTests.swift`

**Step 1: Write failing decoding, bounds, and fallback tests**

Add optional fields:

```swift
homeArtFocus: HabitatThemeFocalPoint?
taskArtFocus: HabitatThemeFocalPoint?
homeArtScale: Double?
taskArtScale: Double?
taskSidebarOpacity: Double?
taskHeaderOpacity: Double?
homeContentOpacity: Double?
taskContentOpacity: Double?
homeContentWidth: Double?
vignetteStrength: Double?
```

Test these accepted bounds:

- focal points: each coordinate `0...1`;
- art scale: `1.00...1.35`;
- task sidebar/header opacity: `0.54...0.90`;
- home content opacity: `0.40...0.78`;
- task content opacity: `0.60...0.84`;
- home content width: `0.46...0.68`;
- vignette strength: `0.00...0.70`.

Require legacy values to resolve deterministically from the existing focal
point, strengths, panel/sidebar/header opacity, mode, and safe side.

**Step 2: Run focused tests and verify RED**

```bash
swift test --filter 'optionalThemeAppearanceIsTypedBoundedAndReferencesDeclaredImage|committedJSONSchemaMatchesTheRuntimeContract|themePackageBuilder'
```

Expected: compile or schema failures because the fields and bounds do not exist.

**Step 3: Implement the minimal typed model and schema**

Add optional stored properties, initializer defaults, and resolved accessors.
Keep old manifests decodable. Reject unknown nested fields and all non-finite
numbers. Mirror exact optional keys, enums, and bounds in the committed schema.

Use these fallback rules as a starting point:

```swift
resolvedHomeArtFocus = homeArtFocus ?? artFocus
resolvedTaskArtFocus = taskArtFocus ?? artFocus
resolvedHomeArtScale = homeArtScale ?? (resolvedHomeMode == .immersive ? 1.08 : 1.0)
resolvedTaskArtScale = taskArtScale ?? 1.0
resolvedTaskSidebarOpacity = taskSidebarOpacity ?? max(resolvedSidebarOpacity, 0.68)
resolvedTaskHeaderOpacity = taskHeaderOpacity ?? max(resolvedHeaderOpacity, 0.60)
resolvedHomeContentOpacity = homeContentOpacity ?? min(panelOpacity, 0.66)
resolvedTaskContentOpacity = taskContentOpacity ?? min(max(panelOpacity, 0.68), 0.84)
resolvedHomeContentWidth = homeContentWidth ?? 0.56
resolvedVignetteStrength = vignetteStrength ?? 0.34
```

**Step 4: Run ResourceKit tests and verify GREEN**

```bash
swift test --filter 'ManifestValidatorTests|ThemePackageBuilderTests'
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/HabitatCore/Theme/HabitatThemeAppearance.swift \
  Sources/ResourceKit/Manifest/ManifestDecoder.swift \
  Sources/ResourceKit/Validation/ManifestValidator.swift \
  Sources/ResourceKit/Creation/ThemePackageBuilder.swift \
  Schemas/habitat-pack-v1.schema.json \
  Tests/ResourceKitTests/ManifestValidatorTests.swift \
  Tests/ResourceKitTests/ThemePackageBuilderTests.swift
git commit -m "feat: add full-window route composition tokens"
```

### Task 3: Curate explicit scenes for all twenty-four themes

**Files:**
- Modify: `Sources/HabitatCore/Theme/BuiltInThemeCatalog.swift`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/*/habitat.json`
- Modify: `Tests/HabitatCoreTests/BuiltInThemeCatalogTests.swift`
- Modify: `Tests/CodexHabitatAppTests/BundledThemeModelTests.swift`

**Step 1: Add failing scene-diversity tests**

Require:

- all 24 definitions have an explicit treatment;
- at least 12 distinct normalized route-composition signatures;
- every style family has at least one immersive or framed home scene;
- no more than 6 themes share an exact complete signature;
- home strengths span at least `0.28` and task strengths span at least `0.30`;
- both leading and trailing safe sides exist, with center/none used only where
  the image crop remains readable;
- every theme has explicit route focus, scale, route chrome, content opacity,
  content width, and vignette values.

**Step 2: Run tests and verify RED**

```bash
swift test --filter 'allBuiltInThemesDeclareExplicitScenes|builtInScenesCoverMateriallyDifferentWholeWindowCompositions'
```

Expected: FAIL because twenty definitions still use fallback treatment.

**Step 3: Curate the complete catalog**

Use the actual background crop, luminance, and safe area for each theme. The
four primary themes retain their identity but receive stronger route values.
Group the other twenty by art and working context, not only by palette.

Target bands:

| Scene | Home art | Task art | Home sidebar | Task content | Composer |
| --- | ---: | ---: | ---: | ---: | ---: |
| cinematic immersive | 0.80-0.88 | 0.46-0.58 | 0.48-0.60 | 0.64-0.74 | 0.92-0.98 |
| energetic immersive | 0.78-0.86 | 0.42-0.54 | 0.50-0.62 | 0.66-0.76 | 0.92-0.98 |
| retro framed/desktop | 0.68-0.82 | 0.36-0.48 | 0.54-0.70 | 0.68-0.80 | 0.90-0.96 |
| light quiet/framed | 0.52-0.72 | 0.10-0.38 | 0.60-0.76 | 0.72-0.84 | 0.92-0.98 |

**Step 4: Update manifest appearance from the canonical catalog**

Update only each manifest's `colors` and `theme` objects through structured JSON
editing. Preserve identity, assets, hashes, license, pets, and widgets. The
exhaustive Task 1 test is the drift gate; do not introduce a second catalog in
a standalone script.

**Step 5: Run focused tests and verify GREEN**

```bash
swift test --filter 'BuiltInThemeCatalogTests|BundledThemeModelTests|BundledResourcesTests|allBuiltInManifestsMatchTheCanonicalCatalog'
```

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/HabitatCore/Theme/BuiltInThemeCatalog.swift \
  Sources/CodexHabitatApp/Resources/Themes \
  Tests/HabitatCoreTests/BuiltInThemeCatalogTests.swift \
  Tests/CodexHabitatAppTests/BundledThemeModelTests.swift
git commit -m "feat: curate twenty-four full-window scenes"
```

### Task 4: Expand the versioned host-surface profile

**Files:**
- Modify: `Sources/CodexHabitatThemeBridge/Themes/CompatibilityProfile.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Resources/compatibility.json`
- Modify: `Tests/CodexHabitatThemeBridgeTests/CompatibilityProfileTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/CodexBundleVerifierTests.swift`
- Modify: `docs/qa/cdp-compatibility-matrix.md`

**Step 1: Reconfirm the official bundle without changing it**

Record the current Codex PID/start time and run only the read-only verifier.
Extract the signed `app.asar` to a unique temporary directory and inspect stable
class/test-id strings. Do not run `start`, `apply`, `restore`, or `watch`.

Only add selectors confirmed in both supported version lines when possible:

```swift
appShell
homeContent
homeSuggestions
selectedNavigation
taskTranscript
messageSurface
codeSurface
toolSurface
sidebarResizeChrome
topFade
bottomFade
stickyBand
composerContext
```

If a surface has no narrow stable selector, omit it and document the gap rather
than introducing positional `div` selectors.

**Step 2: Write failing profile safety tests**

Use unique sentinel selectors and require every new selector to pass the same
allowlist validator. Assert no selector contains wildcard roots, text matching,
remote URLs, script, braces, semicolons, or content-bearing attributes.

**Step 3: Run tests and verify RED**

```bash
swift test --filter 'CompatibilityProfileTests|CodexBundleVerifierTests'
```

Expected: decoding or compile failures because the new profile fields do not exist.

**Step 4: Implement the narrow profiles**

Add only selectors proven by the read-only extraction. Update the matrix with
exact bundle version/hash evidence and explicitly retain live visual acceptance
as pending.

**Step 5: Run focused tests and verify GREEN**

```bash
swift test --filter 'CompatibilityProfileTests|CodexBundleVerifierTests|CDPTargetValidatorTests'
```

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/CodexHabitatThemeBridge/Themes/CompatibilityProfile.swift \
  Sources/CodexHabitatThemeBridge/Resources/compatibility.json \
  Tests/CodexHabitatThemeBridgeTests/CompatibilityProfileTests.swift \
  Tests/CodexHabitatThemeBridgeTests/CodexBundleVerifierTests.swift \
  docs/qa/cdp-compatibility-matrix.md
git commit -m "feat: profile complete Codex theme surfaces"
```

### Task 5: Compile one continuous scene and complete skin recipes

**Files:**
- Modify: `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Resources/codex-theme-template.css`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift`

**Step 1: Write failing structural compiler tests**

Add tests that normalize comments, literal colors, data URLs, and numeric values
before comparing output. Require:

```swift
#expect(css.contains("habitat-scene-canvas"))
#expect(css.contains("position: fixed"))
#expect(css.contains("inset: 0"))
#expect(css.contains("pointer-events: none"))
#expect(css.contains(profile.selectors.appShell))
#expect(css.contains("--habitat-home-art-scale"))
#expect(css.contains("--habitat-task-art-scale"))
#expect(css.contains("--habitat-task-content-opacity"))
#expect(!css.contains("--habitat-route-veil"))
```

For every style family, require the normalized recipe to mention sidebar,
header, main, thread/transcript, composer, popover, selected navigation, and all
available message/code/tool surfaces. Require all nine normalized recipes to be
distinct.

Add a task-art test proving transcript opacity stays in the typed range instead
of deriving the current 80.68% route veil.

**Step 2: Run tests and verify RED**

```bash
swift test --filter 'compiledSceneSpansTheWholeWindow|taskSceneKeepsArtVisibleAcrossTheTranscript|everyStyleRecipeCoversRequiredHostSurfaces'
```

Expected: FAIL because the current template paints main/body separately, uses
`--habitat-route-veil`, and style recipes cover only three surfaces.

**Step 3: Implement the full-window template**

Paint one scene layer on the verified shell. Use route-specific art position,
scale, strength, and vignette. Make sidebar/header/main/thread material layers
over that canvas. Remove unused variables and ensure every compiled variable is
consumed.

Use safe-side variables to align and constrain home content. Decorative layers
must never receive pointer events. Do not hide or reorder native controls.

**Step 4: Expand all nine skin recipes**

Each recipe must define the complete host surface hierarchy and semantic
states. Keep large surfaces free of expensive blur. Use at most one short
`180ms` transform/opacity transition for hover/focus and disable it for reduced
motion.

**Step 5: Run bridge compiler tests and verify GREEN**

```bash
swift test --filter 'ThemeCompilerTests'
```

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift \
  Sources/CodexHabitatThemeBridge/Resources/codex-theme-template.css \
  Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift
git commit -m "feat: compile full-window Codex scenes"
```

### Task 6: Annotate, update, and clean up host surfaces safely

**Files:**
- Modify: `Sources/CodexHabitatThemeBridge/CDP/CDPClient.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Session/ThemeBridgeCoordinator.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Health/LayoutHealthCheck.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/CDPClientTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeBridgeCoordinatorTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/LayoutHealthCheckTests.swift`

**Step 1: Write failing annotation lifecycle tests**

Require the installer to receive a fixed dictionary of profile-owned selectors
to fixed surface names. Assert it:

- calls `querySelectorAll` only with profile values;
- applies only fixed `data-codex-habitat-surface` values;
- never reads `textContent`, prompt, response, project, thread, file, user, href,
  or arbitrary attributes;
- remains idempotent across route updates and DOM replacement;
- removes every annotation, observer, style, root marker, and bootstrap on restore.

**Step 2: Run tests and verify RED**

```bash
swift test --filter 'CDPClientTests|ThemeBridgeCoordinatorTests|LayoutHealthCheckTests'
```

Expected: FAIL because only the route marker is maintained today.

**Step 3: Implement fixed surface annotation**

Extend the existing bounded leading update and 120 ms trailing refresh. Do not
add a second observer or timer. The annotation adapter must be a fixed generated
script from typed profile data, not theme data.

**Step 4: Extend health checks**

Require shell/sidebar/main/header/thread/composer geometry, composer hit testing,
task scrolling, no horizontal overflow, and bounded visible popovers. Missing
optional surfaces may skip their visual rule, but required base surfaces fail closed.

**Step 5: Run focused tests and verify GREEN**

```bash
swift test --filter 'CodexHabitatThemeBridgeTests'
```

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/CodexHabitatThemeBridge/CDP/CDPClient.swift \
  Sources/CodexHabitatThemeBridge/Session/ThemeBridgeCoordinator.swift \
  Sources/CodexHabitatThemeBridge/Health/LayoutHealthCheck.swift \
  Tests/CodexHabitatThemeBridgeTests
git commit -m "feat: maintain safe Codex surface annotations"
```

### Task 7: Make Habitat preview and Studio represent the real scene

**Files:**
- Modify: `Sources/CodexHabitatApp/Settings/ThemeTreatmentPreview.swift`
- Modify: `Sources/CodexHabitatApp/Settings/ThemeStudioModel.swift`
- Modify: `Sources/CodexHabitatApp/Settings/ThemeStudioView.swift`
- Modify: `Sources/CodexHabitatApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/CodexHabitatApp/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `Tests/CodexHabitatAppTests/ThemeTreatmentPreviewTests.swift`
- Modify: `Tests/CodexHabitatAppTests/ThemeStudioModelTests.swift`
- Modify: `Tests/CodexHabitatAppTests/LocalizationTests.swift`

**Step 1: Write failing preview and Studio tests**

Require the preview model to expose all resolved route fields and produce a
signature that changes for route crop, scale, content plate, task chrome, width,
and vignette. Require Studio to clamp each new numeric value, preserve complete
drafts, and keep the same CSS/JS/selector/URL rejection boundary.

**Step 2: Run tests and verify RED**

```bash
swift test --filter 'ThemeTreatmentPreviewTests|ThemeStudioModelTests|LocalizationTests'
```

Expected: compile failures because the new scene fields are not represented.

**Step 3: Implement the scene preview**

Use one artwork layer across the complete miniature window. Move and constrain
home content according to safe side and width. Render independent task transcript
and chrome opacity. Keep image decoding cached and off the main actor.

**Step 4: Add advanced route controls**

Add grouped home/task controls with dynamic Simplified Chinese labels. Do not
add free-form CSS, selector, command, script, or URL inputs. Keep export/import
fully typed and preserve replacement confirmation.

**Step 5: Run focused tests and verify GREEN**

```bash
swift test --filter 'CodexHabitatAppTests'
```

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/CodexHabitatApp/Settings \
  Sources/CodexHabitatApp/Resources/en.lproj/Localizable.strings \
  Sources/CodexHabitatApp/Resources/zh-Hans.lproj/Localizable.strings \
  Tests/CodexHabitatAppTests
git commit -m "feat: preview and edit full-window scenes"
```

### Task 8: Build the offline Codex main-window fixture

**Files:**
- Modify: `Package.swift`
- Modify: `Sources/CodexHabitatThemeBridge/CodexHabitatThemeBridge.swift`
- Create: `Sources/CodexHabitatThemeBridge/Fixtures/OfflineThemeFixturePayload.swift`
- Create: `Tests/VisualFixtures/CodexWindow/index.html`
- Create: `Tests/VisualFixtures/CodexWindow/styles.css`
- Create: `Tests/VisualFixtures/CodexWindow/render.mjs`
- Create: `Tests/VisualFixtures/CodexWindow/package.json`
- Create: `Tests/VisualFixtures/CodexWindow/package-lock.json`
- Create: `Tests/VisualFixtures/CodexWindow/README.md`
- Create: `Tests/CodexHabitatThemeBridgeTests/OfflineThemeFixtureTests.swift`
- Create: `scripts/render-codex-theme-fixtures.sh`

**Step 1: Write failing offline-export tests**

Define a debug-only `offline-fixture` command. Require it to:

- accept only a profile version and local output path;
- reject `--app`, `--authorized`, `start`, `apply`, `watch`, and live-session flags;
- resolve all built-ins through `BridgeThemeResolver` and compile through the
  bundled `ThemeCompiler`;
- include the real installer expression, profile ID/selectors, theme/route, and
  source fingerprints;
- avoid constructing `ThemeSession`, coordinator, listener, restarter, or process signaler.

**Step 2: Run tests and verify RED**

```bash
swift test --filter OfflineThemeFixtureTests
```

Expected: compile failure because the payload and command do not exist.

**Step 3: Implement the debug-only exporter**

Add a SwiftPM debug define such as `HABITAT_OFFLINE_FIXTURE`. The release build
must not include the command string or payload writer; add a release verifier
assertion for that absence. The exporter writes private temporary files and
never reads Codex state.

**Step 4: Add the fixed representative DOM and pinned renderer**

The HTML uses exact compatibility selectors with fixed synthetic content and an
`OFFLINE THEME FIXTURE` label. The renderer blocks network requests, uses pinned
Playwright Chromium, route home/task, 1512 x 982 and a narrower viewport,
reduced motion, fixed locale, and device scale factor 1.

Assert selector cardinality, one style, route within 120 ms, no console/page
error, no external request, no overflow, composer hit testing, task scroll,
decodable art, nonblank pixels, and minimum pHash distance.

**Step 5: Verify RED then GREEN for visual metrics**

First run the renderer against the pre-Task-5 compiler commit or a saved old
payload and confirm the continuity/task-visibility assertions fail. Then run
against HEAD and confirm they pass.

```bash
scripts/render-codex-theme-fixtures.sh --check
```

Expected on HEAD: PASS for 24 themes x 2 routes x 2 viewports.

**Step 6: Commit**

```bash
git add Package.swift Sources/CodexHabitatThemeBridge \
  Tests/VisualFixtures Tests/CodexHabitatThemeBridgeTests \
  scripts/render-codex-theme-fixtures.sh scripts/verify-release.sh
git commit -m "test: render offline Codex window scenes"
```

### Task 9: Capture full-window visual QA and correct weak crops

**Files:**
- Modify if required: `Sources/HabitatCore/Theme/BuiltInThemeCatalog.swift`
- Modify if required: `Sources/CodexHabitatApp/Resources/Themes/*/habitat.json`
- Modify if required: `Sources/CodexHabitatApp/Resources/Themes/*/background.jpg`
- Modify if required: `Sources/CodexHabitatApp/Resources/Themes/*/preview.png`
- Modify if required: `docs/qa/theme-asset-provenance.md`
- Create: `docs/qa/screenshots/2026-07-18/offline-codex-window/README.md`
- Create: `docs/qa/screenshots/2026-07-18/offline-codex-window/metrics.json`
- Create: `docs/qa/screenshots/2026-07-18/offline-codex-window/*.png`

**Step 1: Render all fixtures**

```bash
scripts/render-codex-theme-fixtures.sh --write \
  docs/qa/screenshots/2026-07-18/offline-codex-window
```

Expected: 24 home and 24 task captures per viewport, contact sheets, metrics,
and fingerprints with no network access.

**Step 2: Review original-resolution images**

Use `view_image` on the four primary home/task images and every contact sheet.
Check continuous canvas, focal crop, safe-side content, sidebar, selected nav,
header, suggestions, transcript, code/tool surfaces, composer, popover, contrast,
clipping, overlap, blank pixels, and repeated-looking families.

**Step 3: Correct typed composition first**

Adjust focal point, scale, safe side, strength, content opacity/width, or mode
before regenerating art. Re-run the exact theme's tests and screenshots after
each change.

Only if a background cannot support both viewports may imagegen generate a new
original, text-free, IP-free bitmap. Record endpoint class, prompt, date,
dimensions, bytes, SHA-256, raw source, and normalization in provenance. Do not
send Dream Skin or QQ images to the model.

**Step 4: Run fixture checks and commit**

```bash
scripts/render-codex-theme-fixtures.sh --check
git diff --check
```

Expected: PASS and no malformed docs.

```bash
git add Sources/HabitatCore/Theme/BuiltInThemeCatalog.swift \
  Sources/CodexHabitatApp/Resources/Themes \
  docs/qa/theme-asset-provenance.md \
  docs/qa/screenshots/2026-07-18/offline-codex-window
git commit -m "docs: record offline Codex window visual QA"
```

### Task 10: Final tests, Build 8, install, screenshot, and package

**Files:**
- Modify: `Config/Info.plist`
- Modify: `scripts/build-app.sh`
- Modify: `Tests/CodexHabitatAppTests/HabitatUpdaterControllerTests.swift`
- Modify: `docs/qa/macos-v1-checklist.md`
- Modify: `docs/qa/screenshots/2026-07-18/README.md`
- Modify: `docs/releasing.md` if the fixture adds a release prerequisite

**Step 1: Write the failing Build 8 contract**

Update the bundle-contract test to expect `CFBundleVersion == 8` and ensure
release verification rejects the debug-only offline fixture command.

**Step 2: Run the contract test and verify RED**

```bash
swift test --filter mainBundleConfigurationDeclaresAStandardVisibleBuildEightApp
```

Expected: FAIL while plist/build script still report 7.

**Step 3: Bump only the build number**

Keep marketing version `0.1.0`; set `BUILD_NUMBER=8` in the build script and
`CFBundleVersion=8` in the plist. Do not re-enable Sparkle updates.

**Step 4: Run complete automated verification**

```bash
swift test
scripts/render-codex-theme-fixtures.sh --check
scripts/build-app.sh --adhoc
scripts/verify-release.sh "dist/Codex Habitat.app"
codesign --verify --deep --strict --verbose=2 "dist/Codex Habitat.app"
```

Record the exact test count. Expected: every command exits 0.

**Step 5: Reconfirm the hard boundary before installing**

Record Codex PID/start time, settings schema, `themeBridgeEnabled=false`, empty
session directory, and absence of the helper. Kill only the exact Habitat PID.
Atomically install the verified app into `/Applications/Codex Habitat.app`.

**Step 6: Capture native Habitat QA**

Launch only Habitat with gated visual-QA arguments. Capture the gallery, the
selected high-impact treatment preview, and advanced Studio route controls with
the screenshot skill. Inspect original pixels and scan Habitat logs for SwiftUI,
AttributeGraph, and layout recursion warnings.

Do not click `Apply to Codex` and do not run the helper.

**Step 7: Package and mount the final DMG read-only**

```bash
scripts/package-dmg.sh
hdiutil attach "dist/Codex-Habitat-0.1.0.dmg" -readonly -nobrowse -mountpoint "$MOUNT"
scripts/verify-release.sh "$MOUNT/Codex Habitat.app"
codesign --verify --deep --strict --verbose=2 "$MOUNT/Codex Habitat.app"
```

Verify both media and volume are read-only, app/link exist, mounted build is 8,
the version command is `Codex Habitat 0.1.0`, then detach and calculate SHA-256.

**Step 8: Request a final read-only review**

Require no Critical/Important findings in theme safety, compatibility selectors,
fixture isolation, route cleanup, performance, packaging, and IP provenance.
Resolve findings with new RED/GREEN commits before proceeding.

**Step 9: Update QA and commit**

Record exact tests, Build 8, screenshots, fixture fingerprints, DMG hash, Codex
PID/start-time preservation, bridge-disabled state, and the still-pending live
CDP acceptance step.

```bash
git add Config/Info.plist scripts/build-app.sh \
  Tests/CodexHabitatAppTests/HabitatUpdaterControllerTests.swift \
  docs/qa docs/releasing.md
git commit -m "release: verify full-window theme build eight"
```

**Step 10: Final clean-tree verification**

```bash
swift test
scripts/render-codex-theme-fixtures.sh --check
scripts/verify-release.sh "dist/Codex Habitat.app"
scripts/verify-release.sh "/Applications/Codex Habitat.app"
git diff --check
git status --short
```

Expected: full suite and fixture pass, both apps verify, no diff-check output,
and clean status. Reconfirm Codex PID/start time are unchanged, bridge remains
disabled, no helper/session exists, and no Habitat DMG remains mounted.

Real live CDP apply, live Codex screenshot review, restore, and listener closure
must remain unchecked and user-run. Never report the offline fixture as live
Codex acceptance.
