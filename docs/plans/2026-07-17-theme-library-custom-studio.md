# Theme Library and Local Theme Studio Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expand Habitat to twenty-four rights-safe built-in themes and add a local, no-script Theme Studio that creates validated `.habitat-pack` files.

**Architecture:** Extend the shared catalog and manifest with allowlisted category and appearance metadata, then reuse `PackageInstaller` and `InstalledPackageLibrary` as the single validation and sharing path. Theme Studio writes a temporary package, validates and installs it through ResourceKit, and exposes only bounded host-owned controls. The CDP compiler consumes sanitized palette and appearance values while retaining complete ownership of CSS and selectors.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Core Graphics/ImageIO, ZIPFoundation, JSON Schema, Swift Testing, local CDP CSS injection, imagegen bitmap assets, macOS screenshot QA.

---

### Task 1: Expand the shared catalog and theme protocol

**Files:**
- Modify: `Sources/HabitatCore/Theme/BuiltInThemeCatalog.swift`
- Create: `Sources/HabitatCore/Theme/HabitatThemeAppearance.swift`
- Modify: `Sources/ResourceKit/Manifest/HabitatManifest.swift`
- Modify: `Sources/ResourceKit/Manifest/ManifestDecoder.swift`
- Modify: `Sources/ResourceKit/Validation/ManifestValidator.swift`
- Modify: `Schemas/habitat-pack-v1.schema.json`
- Modify: `Tests/HabitatCoreTests/BuiltInThemeCatalogTests.swift`
- Modify: `Tests/ResourceKitTests/ManifestValidatorTests.swift`

**Step 1: Write failing catalog and compatibility tests**

Require all twenty-four IDs from the approved design, localized category keys, and nine allowlisted style families. Add manifest fixtures proving that an omitted `theme` object still decodes, while unknown categories/families, non-finite values, out-of-range opacity/blur/focal coordinates, absolute background paths, and undeclared background files are rejected.

**Step 2: Run tests to verify RED**

Run:

```bash
swift test --filter 'BuiltInThemeCatalogTests|ManifestValidatorTests'
```

Expected: failures identify the twelve missing catalog entries and absent `theme` decoding/validation.

**Step 3: Implement minimal typed metadata**

Add `HabitatThemeCategory`, `HabitatThemeStyleFamily`, `HabitatThemeSafeSide`, `HabitatThemeDensity`, `HabitatThemeFocalPoint`, and `HabitatThemeAppearance`. Add optional `theme: HabitatThemeAppearance?` to `HabitatManifest`. Enforce these ranges in both Swift validation and JSON Schema:

- `artFocus.x/y`: `0...1`
- `backgroundStrength`: `0.10...0.70`
- `panelOpacity`: `0.65...1.0`
- `blurRadius`: `0...24`
- `background`: safe relative path to a declared image

Expand `BuiltInThemeCatalog.all` to exactly twenty-four stable definitions and map every entry to an allowlisted category and style family.

**Step 4: Run focused tests and commit**

```bash
swift test --filter 'BuiltInThemeCatalogTests|ManifestValidatorTests|PackageInstallerTests'
git add Sources/HabitatCore/Theme Sources/ResourceKit/Manifest Sources/ResourceKit/Validation Schemas Tests/HabitatCoreTests Tests/ResourceKitTests
git commit -m "feat: extend the safe theme resource protocol"
```

Expected: focused tests pass; legacy fixtures remain unchanged and valid.

### Task 2: Generate and package the additional twelve original themes

**Files:**
- Create: `Sources/CodexHabitatApp/Resources/Themes/{harvest-homestead,solar-ki-arena,moonlit-shinobi,grand-ocean-crew,elemental-companions,walled-vanguard,arcane-academy,hero-training-campus,nebula-vanguard,spirit-lantern-town,block-frontier,turbo-striker}/`
- Modify: `docs/qa/theme-asset-provenance.md`
- Modify: `Tests/CodexHabitatAppTests/BundledThemeModelTests.swift`
- Modify: `Tests/ResourceKitTests/BundledResourcesTests.swift`

**Step 1: Write failing asset tests**

Require twenty-four unique descriptors, a readable `background.jpg` at least `1600 x 1000`, an `800 x 500` preview, matching declared SHA-256 values, no duplicate asset hashes, and at least eight materially distinct palette hue families.

**Step 2: Run tests to verify RED**

```bash
swift test --filter 'BundledThemeModelTests|BundledResourcesTests'
```

Expected: the twelve new directories and descriptors are missing.

**Step 3: Generate original bitmap environments**

Use the `imagegen` skill. Generate text-free, logo-free, character-free environment art following the approved directions. Prompts must explicitly exclude recognizable franchise costumes, characters, creatures, emblems, typography, screenshots, and copied compositions. Normalize each background to `1600 x 1000`, each preview to `800 x 500`, and keep every packaged background at or below 1 MiB.

**Step 4: Add manifests, licenses, and provenance**

Declare the background as a hashed image asset and include the bounded `theme` object. Record prompt, source, date, dimensions, byte size, SHA-256, and manual IP review for every image. Include the project license notice in every directory.

**Step 5: Verify and commit**

```bash
swift test --filter 'BundledThemeModelTests|BundledResourcesTests|PackageSmokeTests'
git add Sources/CodexHabitatApp/Resources/Themes docs/qa/theme-asset-provenance.md Tests/CodexHabitatAppTests Tests/ResourceKitTests
git commit -m "feat: add twelve original popular-style themes"
```

Expected: all twenty-four packaged themes are unique, valid, and locally loadable.

### Task 3: Add Theme Studio package creation

**Files:**
- Create: `Sources/ResourceKit/Creation/ThemePackageBuilder.swift`
- Create: `Sources/CodexHabitatApp/Settings/ThemeStudioModel.swift`
- Create: `Sources/CodexHabitatApp/Settings/ThemeStudioView.swift`
- Modify: `Sources/CodexHabitatApp/Settings/ResourcePackPanels.swift`
- Modify: `Sources/CodexHabitatApp/App/HabitatAppModel.swift`
- Create: `Tests/ResourceKitTests/ThemePackageBuilderTests.swift`
- Create: `Tests/CodexHabitatAppTests/ThemeStudioModelTests.swift`

**Step 1: Write failing builder and model tests**

Cover source-image type and decoded-size rejection, deterministic image downsampling, palette suggestion, manual color overrides, safe ID generation, dirty-draft state, bounded appearance values, temporary-file cleanup, and successful creation of a package that installs through `PackageInstaller`.

**Step 2: Run tests to verify RED**

```bash
swift test --filter 'ThemePackageBuilderTests|ThemeStudioModelTests'
```

Expected: the builder and editor model do not exist.

**Step 3: Implement the ResourceKit builder**

Use ImageIO/Core Graphics to decode a user-selected local PNG/JPEG/WebP, reject animation and extreme dimensions, orient and downsample it, write bounded JPEG/PNG outputs, calculate hashes, generate a strict manifest and license notice, zip with ZIPFoundation, inspect with `ArchiveInspector`, then install with `PackageInstaller`. Never invoke a shell command or carry arbitrary files from the source directory.

**Step 4: Implement the editor model and native sheet**

Add local image selection, name/author fields, automatic palette suggestion, manual `ColorPicker` controls, segmented style/density controls, safe-side menu, focal-point control, bounded sliders, live static preview, save, export, cancel, and dirty-draft confirmation. Pairing an installed pet stores only the selected pet ID in Habitat settings unless the pet is already part of the same package.

**Step 5: Verify and commit**

```bash
swift test --filter 'ThemePackageBuilderTests|ThemeStudioModelTests|SettingsModelTests|PackageInstallerTests|ArchiveInspectorTests'
git add Sources/ResourceKit/Creation Sources/CodexHabitatApp/Settings Sources/CodexHabitatApp/App Tests/ResourceKitTests Tests/CodexHabitatAppTests
git commit -m "feat: add the local Habitat Theme Studio"
```

Expected: saved themes pass the same installer checks as imported third-party packs; invalid drafts leave no installed or temporary files.

### Task 4: Build the categorized theme gallery and custom-theme bridge path

**Files:**
- Modify: `Sources/CodexHabitatApp/Settings/ThemesSettingsView.swift`
- Modify: `Sources/CodexHabitatApp/App/HabitatAppModel.swift`
- Modify: `Sources/CodexHabitatApp/Integrations/ThemeBridgeIntegrationModel.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Themes/ThemeCompiler.swift`
- Modify: `Sources/CodexHabitatThemeBridge/Resources/codex-theme-template.css`
- Modify: `Tests/CodexHabitatAppTests/BundledThemeModelTests.swift`
- Modify: `Tests/CodexHabitatAppTests/ThemeBridgeIntegrationModelTests.swift`
- Modify: `Tests/CodexHabitatThemeBridgeTests/ThemeCompilerTests.swift`

**Step 1: Write failing gallery and security tests**

Test deterministic category/search filtering, All and Custom counts, selection persistence, installed-theme lookup, and custom-theme compilation from validated local image/tokens. Prove that raw CSS, script, selectors, URL values, undeclared files, invalid MIME data, and unknown style families cannot enter compiled output.

**Step 2: Run tests to verify RED**

```bash
swift test --filter 'BundledThemeModelTests|ThemeBridgeIntegrationModelTests|ThemeCompilerTests'
```

Expected: category filtering and installed custom bridge support are absent.

**Step 3: Implement gallery and bounded compiler input**

Add category segmentation, search, localized empty states, and a `Create Theme` command. Replace the built-in-only bridge gate with a resolver that accepts either a shared catalog entry or an installed package whose manifest and background were already validated. Convert typed appearance values into compiler tokens; keep all CSS templates, selectors, and style-family branches host-owned.

**Step 4: Verify and commit**

```bash
swift test --filter 'BundledThemeModelTests|ThemeBridgeIntegrationModelTests|ThemeCompilerTests|ThemeBridgeCoordinatorTests|CDPClientTests'
git add Sources/CodexHabitatApp Sources/CodexHabitatThemeBridge Tests/CodexHabitatAppTests Tests/CodexHabitatThemeBridgeTests
git commit -m "feat: browse and safely compile custom themes"
```

Expected: built-in and custom previews work; bridge security tests remain green. Do not invoke live apply.

### Task 5: Localize, visually verify, and package the expanded release

**Files:**
- Modify: `Sources/CodexHabitatApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/CodexHabitatApp/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `Tests/CodexHabitatAppTests/LocalizationTests.swift`
- Modify: `docs/qa/phase3-readiness.md`
- Modify: `progress.md` only if the repository convention requires it

**Step 1: Write failing localization coverage**

Require English and Simplified Chinese values for all theme names, category labels, Theme Studio controls, validation errors, rights notice, search, empty states, and accessibility labels.

**Step 2: Run tests to verify RED, then add translations**

```bash
swift test --filter 'LocalizationTests'
```

Expected before implementation: missing keys fail. Add concise translations and rerun until green.

**Step 3: Run full automated verification**

```bash
swift test
make build-adhoc
make verify-release
```

Expected: all tests pass; the signed application and release verification complete without changing Codex.

**Step 4: Perform native visual QA**

Use the `screenshot` skill to capture All, Nostalgia, Anime, and Custom filters plus Theme Studio at wide and narrow settings widths. Verify text fit, contrast, preview integrity, selected states, image focal points, and no incoherent overlap. Also repeat the compact/expanded pet screenshots and Token widget checks from the parent plan.

Do not click `Apply theme to Codex`, start live CDP application, restart Codex, or quit Codex during QA.

**Step 5: Verify the distributable and commit records**

Mount the generated DMG read-only, verify expected app/resources and launch metadata, update the QA record with exact commands and screenshot paths, then commit only intentional release/QA changes:

```bash
git add Sources/CodexHabitatApp/Resources Tests/CodexHabitatAppTests docs/qa progress.md
git commit -m "docs: verify the expanded Habitat theme library"
```

Expected: the release contains twenty-four built-ins, the local Theme Studio, Chinese localization, compact pet fixes, corrected Token labels, and no claim of live Codex CDP acceptance.

