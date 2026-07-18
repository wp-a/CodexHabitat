# Dream Skin-Inspired Theme Prototypes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build four polished, route-aware prototype themes whose Habitat gallery treatments and compiled Codex window treatments are materially different.

**Architecture:** Extend the existing static theme protocol with optional bounded appearance fields, then resolve those fields into host-owned route and chrome recipes. Keep all Codex selectors in versioned compatibility profiles and all package input as static typed data. Rebuild four original bitmap assets and render gallery previews from the same resolved appearance used by the bridge.

**Tech Stack:** Swift 6.2, SwiftUI/AppKit, Foundation/ImageIO, HabitatCore, ResourceKit, loopback CDP, Swift Testing, JSON Schema, `gpt-image-2` through the approved imagegen workflow, macOS screenshot tooling.

---

### Task 1: Extend the typed appearance contract

**Files:**
- Modify: `Sources/HabitatCore/Theme/HabitatThemeAppearance.swift`
- Modify: `Sources/ResourceKit/Manifest/ManifestDecoder.swift`
- Modify: `Sources/ResourceKit/Validation/ManifestValidator.swift`
- Modify: `Schemas/habitat-pack-v1.schema.json`
- Modify: `Tests/ResourceKitTests/ManifestValidatorTests.swift`

**Step 1: Write the failing contract tests**

Add tests that decode a theme containing `homeMode`, `taskMode`, `safeSide: center`,
`homeStrength`, `taskStrength`, `sidebarOpacity`, `headerOpacity`,
`composerOpacity`, and `chromeMaterial`. Assert that a legacy theme without these
keys resolves from `backgroundStrength` and `panelOpacity`. Add rejection cases
for unknown enum values and values outside the documented numeric ranges.

```swift
#expect(theme.homeMode == .immersive)
#expect(theme.taskMode == .banner)
#expect(theme.safeSide == .center)
#expect(theme.resolvedHomeStrength == 0.62)
#expect(theme.resolvedTaskStrength == 0.28)
#expect(theme.resolvedSidebarOpacity == 0.74)
```

Update `committedJSONSchemaMatchesTheRuntimeContract()` to require the new enums
and bounds while keeping the new properties optional.

**Step 2: Run the tests to verify RED**

Run:

```bash
swift test --filter 'optionalThemeAppearanceIsTypedBoundedAndReferencesDeclaredImage|committedJSONSchemaMatchesTheRuntimeContract'
```

Expected: compilation or decoding failures because the new typed fields do not
exist and `center` is not a valid safe side.

**Step 3: Implement the minimal typed model**

Add these host-owned enums:

```swift
public enum HabitatThemeHomeMode: String, Codable, CaseIterable, Sendable {
    case immersive, framed, quiet
}

public enum HabitatThemeTaskMode: String, Codable, CaseIterable, Sendable {
    case ambient, banner, off
}

public enum HabitatThemeChromeMaterial: String, Codable, CaseIterable, Sendable {
    case solid, tinted, glass
}
```

Extend `HabitatThemeSafeSide` with `center` and `none`. Add optional stored
properties for the new fields and resolved accessors that derive from the old
required values. Use defaults in the public initializer so existing call sites
continue to compile. Validate strengths in `0.10...0.85`, opacities in
`0.40...1.0`, and preserve the existing blur and focal-point bounds.

Allow only the exact new keys in `ManifestShapeValidator` and mirror the
contract in the committed JSON schema.

**Step 4: Run the focused and ResourceKit tests**

Run:

```bash
swift test --filter 'ManifestValidatorTests|ThemePackageBuilderTests'
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/HabitatCore/Theme/HabitatThemeAppearance.swift \
  Sources/ResourceKit/Manifest/ManifestDecoder.swift \
  Sources/ResourceKit/Validation/ManifestValidator.swift \
  Schemas/habitat-pack-v1.schema.json \
  Tests/ResourceKitTests/ManifestValidatorTests.swift
git commit -m "feat: add route-aware theme appearance contract"
```

### Task 2: Configure four materially distinct built-in prototypes

**Files:**
- Modify: `Sources/HabitatCore/Theme/BuiltInThemeCatalog.swift`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/workbench/habitat.json`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/retro-messenger/habitat.json`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/arcade-signal/habitat.json`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/quiet-garden/habitat.json`
- Modify: `Tests/HabitatCoreTests/BuiltInThemeCatalogTests.swift`
- Modify: `Tests/CodexHabitatAppTests/BundledThemeModelTests.swift`

**Step 1: Write failing prototype-identity tests**

Assert the four stable IDs expose four distinct combinations of home mode, task
mode, safe area, chrome material, strengths, and chrome opacities. Assert the
other twenty built-ins still resolve through backward-compatible defaults.

```swift
let prototypes = ["workbench", "retro-messenger", "arcade-signal", "quiet-garden"]
let signatures = try prototypes.map { id in
    let value = try #require(BuiltInThemeCatalog.definition(id: id))
    return value.appearance(background: "background.jpg").treatmentSignature
}
#expect(Set(signatures).count == 4)
```

**Step 2: Run the tests to verify RED**

Run:

```bash
swift test --filter 'BuiltInThemeCatalogTests|BundledThemeModelTests'
```

Expected: failures because all current manifests use the same appearance
numbers and have no route or material modes.

**Step 3: Add the four configurations**

Use these intended profiles:

| ID | Home | Task | Material | Density | Safe area |
| --- | --- | --- | --- | --- | --- |
| `workbench` | immersive | ambient | tinted | comfortable | leading |
| `retro-messenger` | framed | banner | glass | compact | leading |
| `arcade-signal` | immersive | banner | solid | compact | leading |
| `quiet-garden` | quiet | off | glass | comfortable | leading |

Give each prototype independent home/task strengths and sidebar/header/composer
opacities. Update the four manifests to match the catalog. Do not change IDs or
asset hashes in this task.

**Step 4: Run the focused tests**

Run:

```bash
swift test --filter 'BuiltInThemeCatalogTests|BundledThemeModelTests'
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/HabitatCore/Theme/BuiltInThemeCatalog.swift \
  Sources/CodexHabitatApp/Resources/Themes/{workbench,retro-messenger,arcade-signal,quiet-garden}/habitat.json \
  Tests/HabitatCoreTests/BuiltInThemeCatalogTests.swift \
  Tests/CodexHabitatAppTests/BundledThemeModelTests.swift
git commit -m "feat: define four distinct theme prototypes"
```

### Task 3: Compile route-aware Codex treatments

**Files:**
- Modify: `Sources/CodexHabitatThemeBridge/Themes/CompatibilityProfile.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Resources/compatibility.json`
- Modify: `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Resources/codex-theme-template.css`
- Modify: `Sources/CodexHabitatThemeBridge/CDP/CDPClient.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Session/ThemeBridgeCoordinator.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Health/LayoutHealthCheck.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/CompatibilityProfileTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/CDPClientTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeBridgeCoordinatorTests.swift`

**Step 1: Write failing compiler and lifecycle tests**

Add `homeMarker` to the versioned selector profile and assert it passes the same
selector validator. Compile each prototype and require route-specific markers,
independent chrome opacity variables, directional scrims, and distinct complete
style-family treatments.

Add CDP tests proving the installer receives only the host profile's home marker,
sets `data-codex-habitat-route` to `home` or `task`, updates it through one
bounded observer, and removes both the marker and observer on restore.

```swift
#expect(source.contains("data-codex-habitat-route"))
#expect(source.contains(profile.selectors.homeMarker))
#expect(!source.contains("textContent"))
```

**Step 2: Run the tests to verify RED**

Run:

```bash
swift test --filter 'CompatibilityProfileTests|ThemeCompilerTests|CDPClientTests|ThemeBridgeCoordinatorTests'
```

Expected: failures because the profile has no home marker, the compiler has one
route treatment, and the installer does not classify routes.

**Step 3: Implement the host-owned route classifier**

Add one verified `homeMarker` selector per supported Codex profile. Pass the
selector separately from compiled theme data into `installStyle`. The installer
may call `document.querySelector` only with that selector and may only set the
fixed root attribute. It must not read node text, attributes containing user
data, URLs, prompts, responses, projects, or threads.

Disconnect the previous observer before installing another one. Extend removal
to remove `data-codex-habitat-route` and the observer.

**Step 4: Implement the route and material CSS**

Compile variables for resolved home/task strength, sidebar/header/composer
opacity, safe-area scrims, material, and density. The static template must:

- use full-window art for immersive home;
- use a framed hero for framed home;
- keep quiet home art subordinate;
- support ambient, banner, and off task modes;
- preserve readable sidebar, header, composer, thread, popovers, and controls;
- set `pointer-events: none` on decorative layers;
- never hide or reorder native Codex controls.

Expand `styleTreatment` so each family returns a complete sidebar/composer/
popover recipe, while all selectors remain profile-owned.

**Step 5: Run bridge tests**

Run:

```bash
swift test --filter 'CodexHabitatThemeBridgeTests'
```

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/CodexHabitatThemeBridge Tests/CodexHabitatThemeBridgeTests
git commit -m "feat: render route-aware Codex theme treatments"
```

### Task 4: Build the Habitat treatment preview and Studio controls

**Files:**
- Modify: `Sources/CodexHabitatApp/Settings/ThemesSettingsView.swift`
- Create: `Sources/CodexHabitatApp/Settings/ThemeTreatmentPreview.swift`
- Modify: `Sources/CodexHabitatApp/Settings/ThemeStudioModel.swift`
- Modify: `Sources/CodexHabitatApp/Settings/ThemeStudioView.swift`
- Modify: `Sources/ResourceKit/Creation/ThemePackageBuilder.swift`
- Modify: `Sources/CodexHabitatApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/CodexHabitatApp/Resources/zh-Hans.lproj/Localizable.strings`
- Create: `Tests/CodexHabitatAppTests/ThemeTreatmentPreviewTests.swift`
- Modify: `Tests/CodexHabitatAppTests/ThemeStudioModelTests.swift`
- Modify: `Tests/ResourceKitTests/ThemePackageBuilderTests.swift`
- Modify: `Tests/CodexHabitatAppTests/LocalizationTests.swift`

**Step 1: Write failing preview and Studio tests**

Define a pure `ThemeTreatmentPreviewModel` that resolves safe-area direction,
chrome material, opacities, density, and route treatment from a descriptor.
Assert the four prototypes yield four different preview signatures.

Extend Studio tests to set every new enum and bounded value, save a package,
reload its manifest, and compare the complete appearance.

**Step 2: Run the tests to verify RED**

Run:

```bash
swift test --filter 'ThemeTreatmentPreviewTests|ThemeStudioModelTests|ThemePackageBuilderTests|LocalizationTests'
```

Expected: compilation failures because the preview model and Studio fields do
not exist.

**Step 3: Implement the composed gallery preview**

Replace the raw image-only `ThemePreview` with `ThemeTreatmentPreview`. Keep the
existing actor-backed downsample cache, then compose:

- the pure background with focal positioning;
- the directional readability scrim;
- a small host-owned sidebar rail;
- content hierarchy bars and one composer surface;
- family-specific border, radius, density, and material treatment.

The preview is decorative, stable at 100 points high, clipped, and inaccessible
as duplicate content. It must not reproduce Codex text, icons, or screenshots.

**Step 4: Extend Theme Studio and package creation**

Add segmented pickers for home mode, task mode, chrome material, and safe area,
plus bounded controls for independent strengths and chrome opacity. Keep controls
compact enough for the existing 640-point sheet and use localized labels.

Pass the values through `ThemePackageRequest` and emit only the typed manifest
keys. Existing imports remain valid through resolved defaults.

**Step 5: Run the focused app and package tests**

Run:

```bash
swift test --filter 'ThemeTreatmentPreviewTests|ThemeStudioModelTests|ThemePackageBuilderTests|LocalizationTests'
```

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/CodexHabitatApp/Settings Sources/CodexHabitatApp/Resources \
  Sources/ResourceKit/Creation/ThemePackageBuilder.swift \
  Tests/CodexHabitatAppTests Tests/ResourceKitTests/ThemePackageBuilderTests.swift
git commit -m "feat: preview and edit complete theme treatments"
```

### Task 5: Generate and package four original prototype backgrounds

**Required skills:** `imagegen`

**Files:**
- Modify: `Sources/CodexHabitatApp/Resources/Themes/workbench/background.jpg`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/workbench/preview.png`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/retro-messenger/background.jpg`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/retro-messenger/preview.png`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/arcade-signal/background.jpg`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/arcade-signal/preview.png`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/quiet-garden/background.jpg`
- Modify: `Sources/CodexHabitatApp/Resources/Themes/quiet-garden/preview.png`
- Modify: the same four `habitat.json` files for SHA-256 hashes
- Modify: `docs/qa/theme-asset-provenance.md`
- Modify: `Tests/CodexHabitatAppTests/BundledThemeModelTests.swift`

**Step 1: Tighten the asset tests before generation**

For the four prototype IDs, require exact 2560 x 1440 JPEG backgrounds, exact
800 x 500 PNG previews, unique hashes, decoded readability, package size bounds,
and matching manifest hashes.

**Step 2: Run the asset test to verify RED**

Run:

```bash
swift test --filter bundledThemeDescriptorsExposeValidatedTokensAndPreviews
```

Expected: failures because current prototype backgrounds are 1600 x 1000.

**Step 3: Generate four original backgrounds**

Read and follow the `imagegen` skill. Generate each background separately with
the approved endpoint and a rights-safe prompt derived only from the design
document. Do not upload or use Dream Skin images, the QQ reference screenshot,
or any third-party art as image input.

Normalize to 2560 x 1440 without stretching. Reject any output containing text,
logos, people, characters, UI, watermarks, protected symbols, or obvious copied
composition. Derive 800 x 500 previews from the normalized background.

**Step 4: Update hashes and provenance**

Update the four manifests with exact SHA-256 hashes. Record endpoint class,
model, prompt, generation date, temporary raw path, normalized dimensions, byte
size, and hashes in `docs/qa/theme-asset-provenance.md`. Do not package raw
generation artifacts or prompts.

**Step 5: Run resource and release-bound tests**

Run:

```bash
swift test --filter 'BundledThemeModelTests|BundledResourcesTests|ThemeCompilerTests'
```

Expected: PASS.

**Step 6: Commit**

```bash
git add Sources/CodexHabitatApp/Resources/Themes/{workbench,retro-messenger,arcade-signal,quiet-garden} \
  Tests/CodexHabitatAppTests/BundledThemeModelTests.swift \
  docs/qa/theme-asset-provenance.md
git commit -m "feat: add four polished theme prototype assets"
```

### Task 6: Verify, package, and capture native prototype QA

**Required skills:** `verification-before-completion`, `screenshot`,
`requesting-code-review`

**Files:**
- Modify: `Config/Info.plist`
- Modify: `scripts/build-app.sh`
- Modify: `Tests/CodexHabitatAppTests/SettingsWindowControllerTests.swift`
- Create: `docs/qa/screenshots/2026-07-18/gallery-prototypes.png`
- Create: `docs/qa/screenshots/2026-07-18/theme-studio-route-controls.png`
- Create: `docs/qa/screenshots/2026-07-18/README.md`
- Modify: `docs/qa/macos-v1-checklist.md`
- Modify: `README.md`

**Step 1: Add the build-number RED test**

Change the bundle-contract test to require build 7, run it, and confirm it fails
while `Config/Info.plist` still contains build 6.

**Step 2: Bump build 7 and run the full suite**

Update the plist and build script, then run:

```bash
swift test
```

Expected: the complete suite passes with no failures.

**Step 3: Build and verify the release artifacts**

Run:

```bash
scripts/build-app.sh --adhoc
scripts/verify-release.sh "dist/Codex Habitat.app"
scripts/package-dmg.sh
```

Mount the DMG read-only, verify the mounted app, confirm build 7 and the
`/Applications` link, then detach it. Record the SHA-256.

**Step 4: Install and capture Habitat-only screenshots**

Install and restart Codex Habitat only. Confirm the Codex PID and start time are
unchanged. Use the screenshot skill to capture the prototype gallery and Theme
Studio at narrow and wide widths. Inspect every image at original resolution for
blank assets, clipping, overlap, unreadable text, repeated treatment, and poor
crop framing.

Do not click live apply, start the helper, restart Codex, quit Codex, or claim a
real CDP visual pass. Any compiled-treatment fixture must be labeled as a
fixture.

**Step 5: Update QA records and perform read-only review**

Record exact test count, build, DMG hash, screenshots, and the deferred manual
Codex visual step. Run a read-only review over all changes since the design
commit and resolve any concrete findings with new RED to GREEN commits.

**Step 6: Commit**

```bash
git add Config/Info.plist scripts/build-app.sh \
  Tests/CodexHabitatAppTests/SettingsWindowControllerTests.swift \
  docs/qa/screenshots/2026-07-18 docs/qa/macos-v1-checklist.md README.md
git commit -m "docs: record Dream Skin-inspired prototype QA"
```

### Task 7: Final verification

**Step 1: Re-run completion checks from a clean tree**

Run:

```bash
swift test
scripts/verify-release.sh "/Applications/Codex Habitat.app"
git diff --check
git status --short
```

Expected: all tests pass, release verification passes, no whitespace errors,
and the working tree is clean.

**Step 2: Confirm safety boundaries**

Verify Codex retains the same PID and start time, the bridge is inactive, and no
Codex files, preferences, signatures, or app bundle contents changed. State
explicitly that real CDP visual acceptance remains manual.
